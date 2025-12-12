#!/usr/bin/env python3

import argparse
import base64
import json
import logging
import os
import sys
import requests
from datetime import datetime

# Configuration Defaults
DEFAULT_API_VER = "v5.1.27"
DEFAULT_ALGO_FILE = "crt_algorithms.csv"
CONFIG_FILE = "CONFIG"

class AlgorithmDeleter:
    def __init__(self, args):
        self.args = args
        self.masking_engine = ""
        self.api_base_url = ""
        self.auth_header = {}
        self.session = requests.Session()
        self.setup_logging()

    def setup_logging(self):
        log_date = datetime.now().strftime('%d%m%Y_%H%M%S')
        log_file_name = self.args.log_file if self.args.log_file else f"dpxcc_delete_algorithms_{log_date}.log"
        
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
            
            if self.args.https_insecure:
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
            response = requests.get(url, timeout=5, verify=self.verify_ssl)
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
            response = self.session.post(api_endpoint, json=payload, verify=self.verify_ssl)
            
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
            response = self.session.put(api_endpoint, verify=self.verify_ssl)
            self.log(f"Response Code: {response.status_code} - Response Body: {response.text}")
            self.log("Logged out successfully.")
        except Exception as e:
            self.log(f"Logout exception: {e}")

    def delete_algorithm(self, algo_name):
        self.log(f"Deleting Algorithm {algo_name} ...")
        
        # Try deleting by name directly as requested
        api_endpoint = f"{self.api_base_url}/algorithms/{algo_name}"
        
        try:
            response = self.session.delete(api_endpoint, verify=self.verify_ssl)
            
            if response.status_code == 204: # No Content = Success in many APIs
                 self.log(f"Algorithm: {algo_name} deleted (204 No Content).")
                 return

            if response.status_code == 200: # Some APIs return 200 OK
                 self.log(f"Algorithm: {algo_name} deleted (200 OK).")
                 return

            if response.status_code == 404:
                 self.log(f"Algorithm: {algo_name} not found.")
                 return

            # If failed, check response error
            self.check_response_error("delete_algorithm", f"algorithms/{algo_name}", response)

        except Exception as e:
             self.log(f"Delete algorithm exception: {e}")
             if not self.args.ignore_errors:
                 self.logout()
                 sys.exit(1)

    def check_response_error(self, func_name, api_name, response):
        self.log(f"{func_name}() -> Function: {func_name}() - Api: {api_name} - Response Code: {response.status_code} - Response Body: {response.text}")
        if not self.args.ignore_errors:
            self.logout()
            sys.exit(1)

    def run(self):
        username, password = self.read_config()
        self.check_connection()
        self.login(username, password)
        
        if not os.path.exists(self.args.algorithms_file) and not self.args.ignore_errors:
             self.log(f"Input CSV file {self.args.algorithms_file} missing")
             sys.exit(1)

        try:
            with open(self.args.algorithms_file, 'r') as csvfile:
                for line in csvfile:
                    clean_line = line.replace('"', '').strip()
                    if not clean_line or clean_line.startswith('#'):
                        continue
                        
                    parts = clean_line.split(';')
                    if len(parts) < 1:
                        continue
                        
                    json_name = parts[0]
                    
                    if not os.path.exists(json_name):
                        self.log(f"Warning: JSON file {json_name} not found locally. Cannot determine Algorithm Name to delete.")
                        continue
                    
                    try:
                        with open(json_name, 'r') as jf:
                            algo_json = json.load(jf)
                            algo_name = algo_json.get('algorithmName')
                            
                            if algo_name:
                                self.delete_algorithm(algo_name)
                            else:
                                self.log(f"No algorithmName found in {json_name}")
                                
                    except json.JSONDecodeError:
                         self.log(f"JSON Decode Error in {json_name}")
                         continue
                    
        finally:
            self.logout()

def main():
    parser = argparse.ArgumentParser(description="Delete Algorithms from CSV list")
    parser.add_argument('-a', '--algorithms-file', default=DEFAULT_ALGO_FILE, help="File containing Algorithms")
    parser.add_argument('-i', '--ignore-errors', action='store_true', help="Ignore errors")
    parser.add_argument('-o', '--log-file', help="Log file name")
    parser.add_argument('-k', '--https-insecure', action='store_true', help="Make Https Insecure")
    
    args = parser.parse_args()
    
    deleter = AlgorithmDeleter(args)
    deleter.run()

if __name__ == "__main__":
    main()
