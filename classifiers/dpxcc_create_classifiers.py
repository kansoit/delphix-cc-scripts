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
DEFAULT_CLASSIFIER_FILE = "crt_classifiers.csv"
CONFIG_FILE = "CONFIG"

class ClassifierCreator:
    def __init__(self, args):
        self.args = args
        self.masking_engine = ""
        self.api_base_url = ""
        self.auth_header = {}
        self.session = requests.Session()
        self.framework_map = {}
        self.file_ref_map = {}
        
        self.setup_logging()

    def setup_logging(self):
        log_date = datetime.now().strftime('%d%m%Y_%H%M%S')
        log_file_name = self.args.log_file if self.args.log_file else f"dpxcc_create_classifiers_{log_date}.log"
        
        file_handler = logging.FileHandler(log_file_name)
        console_handler = logging.StreamHandler(sys.stderr)

        formatter = logging.Formatter('[%(asctime)s] %(message)s', datefmt='%d%m%Y %H:%M:%S')
        file_handler.setFormatter(formatter)
        console_handler.setFormatter(formatter)

        self.logger = logging.getLogger()
        self.logger.setLevel(logging.INFO)
        self.logger.addHandler(file_handler)
        self.logger.addHandler(console_handler)

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
            
            self.protocol = "https" if self.args.https_insecure else "http"
            self.api_base_url = f"{self.protocol}://{self.masking_engine}/masking/api/{DEFAULT_API_VER}"
            return username, password

        except Exception as e:
            self.log(f"Error reading CONFIG: {e}")
            sys.exit(1)

    def check_connection(self):
        url = f"{self.protocol}://{self.masking_engine}"
        self.log(f"Checking connection to {url}...")
        try:
            verify = False if self.protocol == "https" else True
            response = requests.get(url, timeout=5, verify=verify)
            response.raise_for_status()
            self.log(f"Connection to {url} successful.")
        except requests.exceptions.RequestException as e:
            self.log(f"Error connecting to {url}: {e}")
            sys.exit(1)

    def login(self, username, password):
        api_endpoint = f"{self.api_base_url}/login"
        payload = {"username": username, "password": password}
        self.log(f"Logging in with {username} ...")
        
        try:
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

    def get_framework_map(self):
        self.log("Fetching classifier frameworks from API...")
        api_endpoint = f"{self.api_base_url}/classifiers/frameworks"
        params = {"include_schema": "false"}
        
        try:
            verify = False if self.args.https_insecure else True
            response = self.session.get(api_endpoint, params=params, verify=verify)
            
            if response.status_code != 200:
                self.check_response_error("get_framework_map", "classifiers/frameworks", response)
                
            data = response.json()
            response_list = data.get('responseList', [])
            
            # Create map {frameworkName: frameworkId}
            self.framework_map = {fw['frameworkName']: fw['frameworkId'] for fw in response_list}
            self.log("Framework map populated successfully.")
            
        except Exception as e:
            self.log(f"Get frameworks exception: {e}")
            sys.exit(1)

    def load_file_references(self):
        if not self.args.file_reference_id:
            return
            
        if not os.path.exists(self.args.file_reference_id):
            self.log(f"Warning: Reference file {self.args.file_reference_id} not found.")
            return

        self.log(f"Loading file references from {self.args.file_reference_id}...")
        try:
            with open(self.args.file_reference_id, 'r') as f:
                for line in f:
                    uri = line.replace('"', '').strip()
                    if uri:
                        filename = os.path.basename(uri)
                        self.file_ref_map[filename] = uri
        except Exception as e:
            self.log(f"Error loading file references: {e}")

    def sync_file_references(self, clf_json):
        # Search for "file" in valueLists to sync references
        # JSON structure: "properties": { "valueLists": [ { "file": "..." } ] }
        
        modified = False
        
        # Iterate top level list
        for item in clf_json:
            props = item.get('properties', {})
            value_lists = props.get('valueLists', [])
            for vl in value_lists:
                file_val = vl.get('file')
                if file_val:
                    # Check if filename is in our map
                    current_filename = os.path.basename(file_val)
                    if current_filename in self.file_ref_map:
                        new_uri = self.file_ref_map[current_filename]
                        if file_val != new_uri:
                            self.log(f"Updating reference for {current_filename} to {new_uri}")
                            vl['file'] = new_uri
                            modified = True
                            
        return clf_json, modified

    def sync_framework_id(self, clf_json):
        modified = False
        
        for item in clf_json:
            obj_type = item.get('type') # Key used for framework lookup
            current_fw_id = item.get('frameworkId')
            
            if obj_type in self.framework_map:
                correct_fw_id = self.framework_map[obj_type]
                
                # Check mismatch (accounting for int/str differences)
                if str(current_fw_id) != str(correct_fw_id):
                    item['frameworkId'] = correct_fw_id
                    modified = True
        
        return clf_json, modified

    def add_classifier(self, clf_payload):
        clf_name = clf_payload.get('classifierName')
        self.log(f"Adding Classifier {clf_name} ...")
        
        api_endpoint = f"{self.api_base_url}/classifiers"
        
        try:
            verify = False if self.args.https_insecure else True
            response = self.session.post(api_endpoint, json=clf_payload, verify=verify)
            
            # Check for "Classifier already exists"
            if response.status_code != 200:
                error_msg = response.text
                if self.args.ignore_errors and "Classifier already exists" in error_msg:
                    self.log(f"Classifier: {clf_name} already exists. Ignoring.")
                    return
                
                self.check_response_error("add_classifier", "classifiers", response)
            
            data = response.json()
            if data.get('classifierName'):
                self.log(f"Classifier: {clf_name} submitted for creation.")
            else:
                self.log(f"Classifier: {clf_name} NOT submitted for creation.")
                
        except Exception as e:
            self.log(f"Add classifier exception: {e}")
            if not self.args.ignore_errors:
                 self.logout()
                 sys.exit(1)

    def run(self):
        username, password = self.read_config()
        self.check_connection()
        self.login(username, password)
        
        # Pre-load data
        self.get_framework_map()
        self.load_file_references()
        
        if not os.path.exists(self.args.classifiers_file) and not self.args.ignore_errors:
             self.log(f"Input CSV file {self.args.classifiers_file} missing")
             sys.exit(1)

        try:
            with open(self.args.classifiers_file, 'r') as csvfile:
                for line in csvfile:
                    clean_line = line.replace('"', '').strip()
                    if not clean_line or clean_line.startswith('#'):
                        continue
                        
                    parts = clean_line.split(';')
                    if len(parts) < 1:
                        continue
                        
                    json_name = parts[0]
                    
                    if not os.path.exists(json_name):
                         self.log(f"Input json file {json_name} is missing")
                         if not self.args.ignore_errors:
                             self.logout()
                             sys.exit(1)
                         continue

                    # Validation implicitly handled by json.load
                    try:
                        with open(json_name, 'r') as jf:
                            clf_json = json.load(jf)
                    except json.JSONDecodeError:
                        self.log(f"ERROR: {json_name}\njson file format is NOT valid!")
                        if not self.args.ignore_errors:
                            sys.exit(1)
                        continue
                    
                    self.log(f"Processing file: {json_name}")
                    
                    # Sync Logic
                    is_modified = False
                    
                    # 1. Sync File Refs
                    clf_json, mod_files = self.sync_file_references(clf_json)
                    if mod_files: is_modified = True
                    
                    # 2. Sync Framework IDs
                    clf_json, mod_fw = self.sync_framework_id(clf_json)
                    if mod_fw:
                        self.log(f"Framework IDs updated for {json_name}")
                        is_modified = True
                    
                    if is_modified:
                        self.log(f"Persisting changes to {json_name}")
                        with open(json_name, 'w') as jf:
                            json.dump(clf_json, jf, indent=2)

                    # Create Classifiers
                    # Iterate array of objects in JSON
                    for item in clf_json:
                        # Construct payload (map fields)
                        # Construct payload (map fields)
                        payload = {
                            "classifierName": item.get('name'),
                            "description": item.get('description'),
                            "frameworkId": item.get('frameworkId'),
                            "domainName": item.get('domain'),
                            "classifierConfiguration": item.get('properties')
                        }
                        self.add_classifier(payload)

        finally:
            self.logout()

    def check_response_error(self, func_name, api_name, response):
        self.log(f"{func_name}() -> Function: {func_name}() - Api: {api_name} - Response Code: {response.status_code} - Response Body: {response.text}")
        if not self.args.ignore_errors:
            self.logout()
            sys.exit(1)

def main():
    parser = argparse.ArgumentParser(description="Create Classifiers from CSV list")
    parser.add_argument('-c', '--classifiers-file', default=DEFAULT_CLASSIFIER_FILE, help="File containing Classifiers")
    parser.add_argument('-f', '--file-reference-id', help="File Reference Id CSV")
    parser.add_argument('-i', '--ignore-errors', action='store_true', help="Ignore errors")
    parser.add_argument('-o', '--log-file', help="Log file name")
    parser.add_argument('-x', '--proxy-bypass', default="true", help="Proxy ByPass (ignored)")
    parser.add_argument('-k', '--https-insecure', action='store_true', help="Make Https Insecure")
    
    args = parser.parse_args()
    
    creator = ClassifierCreator(args)
    creator.run()

if __name__ == "__main__":
    main()
