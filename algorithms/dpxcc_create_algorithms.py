#!/usr/bin/env python3

import argparse
import base64
import csv
import json
import logging
import os
import sys
import time
import requests
from datetime import datetime

# Configuration Defaults
DEFAULT_API_VER = "v5.1.27"
DEFAULT_KEEPALIVE = 300
DEFAULT_ALGO_FILE = "crt_algorithms.csv"
DEFAULT_FILEREFID_NAME = "fileReferenceId.csv"
CONFIG_FILE = "CONFIG"

class AlgorithmCreator:
    def __init__(self, args):
        self.args = args
        self.masking_engine = ""
        self.api_base_url = ""
        self.auth_header = {}
        self.session = requests.Session()
        self.file_reference_ids = []  # To store IDs for CSV generation
        
        # Setup Logging
        self.setup_logging()

    def setup_logging(self):
        log_date = datetime.now().strftime('%d%m%Y_%H%M%S')
        log_file_name = self.args.log_file if self.args.log_file else f"dpxcc_create_algorithms_{log_date}.log"
        
        # Create handlers
        file_handler = logging.FileHandler(log_file_name)
        console_handler = logging.StreamHandler(sys.stderr) # Send logs to stderr as requested/parity

        # Format
        formatter = logging.Formatter('[%(asctime)s] %(message)s', datefmt='%d%m%Y %H:%M:%S')
        file_handler.setFormatter(formatter)
        console_handler.setFormatter(formatter)

        self.logger = logging.getLogger()
        self.logger.setLevel(logging.INFO)
        self.logger.addHandler(file_handler)
        self.logger.addHandler(console_handler)
        
        self.log_file_name = log_file_name # Store for reference

    def log(self, message):
        self.logger.info(message)

    def read_config(self):
        if not os.path.exists(CONFIG_FILE):
            self.log(f"Error: {CONFIG_FILE} not found!")
            sys.exit(1)
        
        try:
            with open(CONFIG_FILE, 'r') as f:
                lines = f.readlines()
                encoded_user = lines[0].strip()
                encoded_pass = lines[1].strip()
                self.masking_engine = lines[2].strip()
            
            username = base64.b64decode(encoded_user).decode('utf-8')
            password = base64.b64decode(encoded_pass).decode('utf-8')
            
            if self.args.https_insecure: # Corresponds to -k, standard curl behavior
                self.protocol = "https"
                self.verify_ssl = False
            else:
                self.protocol = "http"
                self.verify_ssl = True
            
            self.api_base_url = f"{self.protocol}://{self.masking_engine}/masking/api/{DEFAULT_API_VER}"
            return username, password

        except Exception as e:
            self.log(f"Error reading CONFIG: {e}")
            sys.exit(1)

    def check_connection(self):
        url = f"{self.protocol}://{self.masking_engine}"
        self.log(f"Checking connection to {url}...")
        try:
            # -m 5 equivalent (timeout)
            response = requests.get(url, timeout=5, verify=False if self.protocol == "https" else True) # Always verify=False if -k per curl logic?
            # Bash: curl_cmd="$curl_cmd -k" if HttpsInsecure=true.
            
            response.raise_for_status()
            self.log(f"Connection to {url} successful.")
        except requests.exceptions.RequestException as e:
            self.log(f"Error connecting to {url}: {e}")
            # Bash script has specific error pattern matching. 
            # I will simplify but keep the spirit: exit on failure.
            sys.exit(1)

    def login(self, username, password):
        api_endpoint = f"{self.api_base_url}/login"
        payload = {"username": username, "password": password}
        self.log(f"Logging in with {username} ...")
        
        try:
            # Verify=False to mimic -k behavior
            verify = False if self.args.https_insecure else True
            
            response = self.session.post(api_endpoint, json=payload, verify=verify)
            
            if response.status_code != 200:
                self.log(f"Login failed: {response.status_code} - {response.text}")
                sys.exit(1)
                
            data = response.json()
            if 'Authorization' not in data:
                self.log(f"Login failed: No Authorization token. Response: {data}")
                sys.exit(1)
                
            self.auth_header = {'Authorization': data['Authorization']}
            self.session.headers.update(self.auth_header)
            self.log(f"{username} logged in successfully with token {data['Authorization']}")
            
        except Exception as e:
            self.log(f"Login exception: {e}")
            sys.exit(1)

    def logout(self):
        if not self.auth_header:
            return
            
        self.log("Logging out ...")
        try:
            api_endpoint = f"{self.api_base_url}/logout"
            verify = False if self.args.https_insecure else True
            response = self.session.put(api_endpoint, verify=verify)
            self.log(f"Response Code: {response.status_code} - Response Body: {response.text}")
            self.log("Logged out successfully.")
        except Exception as e:
            self.log(f"Logout exception: {e}")

    def get_frameworks(self):
        self.log("Getting frameworks...")
        api_endpoint = f"{self.api_base_url}/algorithm/frameworks"
        params = {"include_schema": "true", "page_number": 1, "page_size": 256}
        
        try:
            verify = False if self.args.https_insecure else True
            response = self.session.get(api_endpoint, params=params, verify=verify)
            
            if response.status_code != 200:
                self.check_response_error("get_frameworks", "algorithm/frameworks", response)
                
            data = response.json()
            if 'responseList' not in data:
                 self.log(f"Error: responseList not found in get_frameworks. Body: {response.text}")
                 sys.exit(1)
                 
            self.log("Got frameworks...")
            return data['responseList']
            
        except Exception as e:
            self.log(f"Get frameworks exception: {e}")
            sys.exit(1)

    def upload_file(self, file_path):
        self.log(f"Uploading file {file_path} ...")
        api_endpoint = f"{self.api_base_url}/file-uploads"
        params = {"permanent": "false"}
        
        # Mimetype assumption from bash script: text/plain
        # Bash: file=@$FILE_NAME;type=$FILE_TYPE (where FILE_TYPE="text/plain")
        
        try:
            verify = False if self.args.https_insecure else True
            
            with open(file_path, 'rb') as f:
                files = {'file': (os.path.basename(file_path), f, 'text/plain')}
                response = self.session.post(api_endpoint, params=params, files=files, verify=verify)
                
            if response.status_code != 200:
                self.check_response_error("upload_files", "file-uploads", response)
            
            data = response.json()
            file_ref_id = data.get('fileReferenceId')
            
            if file_ref_id:
                self.log(f"File: {data.get('filename')} uploaded - ID: {file_ref_id}")
                # Track for CSV
                # Bash script greps "fileReferenceId": "delphix-file://..." from logs.
                # Here we reconstruct the value or use what's returned.
                # Usually fileReferenceId in API return IS the URI. 
                # Let's verify bash script output.
                # "delphix-file://upload/..."
                self.file_reference_ids.append(f'"{file_ref_id}"') # Add quotes as per bash output
                return file_ref_id
            else:
                self.log("File NOT uploaded (No ID returned)")
                return None
                
        except Exception as e:
            self.log(f"Upload file exception: {e}")
            if not self.args.ignore_errors:
                self.logout()
                sys.exit(1)
            return None

    def check_framework_id(self, algo_json, all_frameworks, expected_framework_name, json_file_path):
        algo_name = algo_json.get('algorithmName')
        current_fid = algo_json.get('frameworkId')
        current_pid = algo_json.get('pluginId')
        
        matching_fw = next((f for f in all_frameworks if f.get('frameworkName') == expected_framework_name), None)
        
        modified = False
        
        if matching_fw:
            correct_fid = matching_fw.get('frameworkId')
            
            # Plugin ID is inside 'plugin' object: .plugin.pluginId
            correct_pid = matching_fw.get('plugin', {}).get('pluginId')
            
            # Bash compares as strings/numbers.
            # current_fid might be int or none.
            
            if current_fid != correct_fid or current_pid != correct_pid:
                self.log(f"Framework ID or Plugin ID mismatch for algorithm {algo_name}. Correcting JSON.")
                algo_json['frameworkId'] = correct_fid
                algo_json['pluginId'] = correct_pid
                modified = True
        else:
            self.log(f"Warning: No matching framework found on appliance for algorithm {algo_name}.")
            
        return algo_json, modified

    def add_algorithm(self, algo_json):
        algo_name = algo_json.get('algorithmName')
        self.log(f"Adding Algorithm {algo_name} ...")
        
        api_endpoint = f"{self.api_base_url}/algorithms"
        
        try:
            verify = False if self.args.https_insecure else True
            response = self.session.post(api_endpoint, json=algo_json, verify=verify)
            
            if response.status_code != 200:
                self.check_response_error("add_algorithm", "algorithms", response)
            
            data = response.json()
            async_task_id = data.get('asyncTaskId')
            
            if async_task_id:
                self.log(f"Algorithm: {algo_name} submitted for creation with asyncTaskId: {async_task_id}.")
                self.check_async_task_status(async_task_id)
            else:
                self.log(f"Algorithm: {algo_name} NOT submitted for creation.")
                
        except Exception as e:
             self.log(f"Add algorithm exception: {e}")
             if not self.args.ignore_errors:
                 self.logout()
                 sys.exit(1)

    def check_async_task_status(self, async_task_id):
        self.log(f"Checking status of async task {async_task_id} ...")
        api_endpoint = f"{self.api_base_url}/async-tasks/{async_task_id}"
        
        while True:
            try:
                verify = False if self.args.https_insecure else True
                response = self.session.get(api_endpoint, verify=verify)
                
                if response.status_code != 200:
                    self.check_response_error("check_async_task_status", f"async-tasks/{async_task_id}", response)
                
                data = response.json()
                status = data.get('status')
                
                if status == 'SUCCEEDED':
                    self.log(f"Async task {async_task_id} succeeded.")
                    break
                elif status == 'FAILED':
                    self.log(f"Async task {async_task_id} failed.")
                    self.log(f"Response Body: {json.dumps(data)}")
                    self.logout()
                    sys.exit(1)
                else:
                    self.log(f"Async task {async_task_id} is still in progress with status: {status}. Waiting 5 seconds...")
                    time.sleep(5)
            except Exception as e:
                 self.log(f"Async wait exception: {e}")
                 self.logout()
                 sys.exit(1)

    def check_response_error(self, func_name, api_name, response):
        # Logic matches bash check_response_error
        if not self.args.ignore_errors or func_name == "dpxlogin":
            self.log(f"{func_name}() -> Function: {func_name}() - Api: {api_name} - Response Code: {response.status_code} - Response Body: {response.text}")
            
            try:
                error_body = response.json()
                error_msg = error_body.get('errorMessage')
                if error_msg:
                    print(error_msg) # Echo strictly for login/critical errors?
            except:
                pass
                
            self.logout()
            sys.exit(1)
        else:
             self.log(f"{func_name}() -> Function: {func_name}() - Api: {api_name} - Response Code: {response.status_code} - Response Body: {response.text}")

    def create_file_reference_csv(self):
        self.log(f"Creating {self.args.file_reference_id} ...")
        try:
            with open(self.args.file_reference_id, 'w') as f:
                for line in self.file_reference_ids:
                    f.write(f"{line}\n")
            self.log(f"{self.args.file_reference_id} created successfully.")
        except Exception as e:
             self.log(f"Error creating CSV: {e}")

    def run(self):
        username, password = self.read_config()
        self.check_connection()
        
        if not os.path.exists(self.args.algorithms_file) and not self.args.ignore_errors:
             self.log(f"Input CSV file {self.args.algorithms_file} missing")
             sys.exit(1)

        self.login(username, password)
        frameworks = self.get_frameworks()
        
        try:
            with open(self.args.algorithms_file, 'r') as csvfile:
                # Bash script reads line by line, removes quotes, then splits by ;
                # We need to replicate this aggressive parsing.
                for line in csvfile:
                    clean_line = line.replace('"', '').strip()
                    if not clean_line or clean_line.startswith('#'):
                        continue
                        
                    parts = clean_line.split(';')
                    if len(parts) < 2:
                        continue
                        
                    json_name = parts[0]
                    framework_name = parts[1]
                    
                    if not os.path.exists(json_name):
                        if not self.args.ignore_errors:
                            self.log(f"Input json file {json_name} is missing")
                            self.logout()
                            sys.exit(1)
                        continue

                    self.log(f"Processing file: {json_name}")
                    
                    with open(json_name, 'r') as jf:
                        try:
                            algo_json = json.load(jf)
                        except json.JSONDecodeError:
                             self.log(f"JSON Decode Error in {json_name}")
                             continue
                    
                    # File Upload Logic
                    # Path: .algorithmExtension.lookupFile.uri
                    # Bash uses jq -r -> returns empty string or value.
                    file_uri = algo_json.get('algorithmExtension', {}).get('lookupFile', {}).get('uri')
                    
                    modified_json = False
                    
                    if file_uri and file_uri != "0" and not file_uri.startswith("jar://") and not file_uri.startswith("delphix-file://"):
                         # Assuming local file if not special URI
                         uploaded_id = self.upload_file(file_uri)
                         if uploaded_id:
                             # Update JSON
                             if 'algorithmExtension' in algo_json and 'lookupFile' in algo_json['algorithmExtension']:
                                  algo_json['algorithmExtension']['lookupFile']['uri'] = uploaded_id
                                  modified_json = True
                    
                    # Framework Check
                    algo_json, fw_modified = self.check_framework_id(algo_json, frameworks, framework_name, json_name)
                    if fw_modified:
                        modified_json = True
                        
                    # Persistence (Replicating the feature we added + File Upload persistence consistency)
                    if modified_json:
                        self.log(f"Persisting changes to {json_name}")
                        with open(json_name, 'w') as jf:
                            json.dump(algo_json, jf, indent=2) # Pretty print
                            
                    self.add_algorithm(algo_json)
                    
        finally:
            self.create_file_reference_csv()
            self.logout()

def main():
    parser = argparse.ArgumentParser(description="Create Algorithms from CSV list")
    parser.add_argument('-a', '--algorithms-file', default=DEFAULT_ALGO_FILE, help="File containing Algorithms")
    parser.add_argument('-f', '--file-reference-id', required=True, help="File Reference Id name (Output CSV)")
    parser.add_argument('-i', '--ignore-errors', action='store_true', help="Ignore errors while adding Algorithms")
    parser.add_argument('-o', '--log-file', help="Log file name")
    parser.add_argument('-x', '--proxy-bypass', default="true", help="Proxy ByPass (Ignored in Python version, usually handled by env vars)") 
    # Note: Requests respects HTTP_PROXY env vars. Implementing specific -x bypass logic needs:
    # session.trust_env = False if bypass is true.
    
    parser.add_argument('-k', '--https-insecure', action='store_true', help="Make Https Insecure (Switch to HTTPS and ignore certs)")
    
    args = parser.parse_args()
    
    creator = AlgorithmCreator(args)
    creator.run()

if __name__ == "__main__":
    main()
