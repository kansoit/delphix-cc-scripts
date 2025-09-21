# Execution Scripts

This directory contains scripts to retrieve execution-related data from the Delphix Masking Engine.

---

## dpxcc_get_execution_event.sh

```
Usage: dpxcc_get_execution_event.sh [options]
Options:
  --log-file          -l  Log file name              - Default Value: Current date_time.log
  --output-file       -o  Output filename            - Default Value: Current date_time.json/csv
  --output-type       -t  Output filetype (json/csv) - Default Value: json
  --proxy-bypass      -x  Proxy ByPass               - Default: true
  --https-insecure    -k  Make Https Insecure        - Default: false
  --masking-engine    -m  Masking Engine Address     - Required value
  --masking-username  -u  Masking Engine User Name   - Required value
  --masking-pwd       -p  Masking Engine Password    - Required value
  --help              -h  Show this help
Example:
dpxcc_get_execution_event.sh -m <MASKING IP> -u <MASKING User> -p <MASKING Password>
```

---

## dpxcc_get_execution_comp.sh

```
Usage: dpxcc_get_execution_comp.sh [options]
Options:
  --log-file          -l  Log file name              - Default Value: Current date_time.log
  --output-file       -o  Output filename            - Default Value: Current date_time.json/csv
  --output-type       -t  Output filetype (json/csv) - Default Value: json
  --proxy-bypass      -x  Proxy ByPass               - Default: true
  --https-insecure    -k  Make Https Insecure        - Default: false
  --masking-engine    -m  Masking Engine Address     - Required value
  --masking-username  -u  Masking Engine User Name   - Required value
  --masking-pwd       -p  Masking Engine Password    - Required value
  --help              -h  Show this help
Example:
dpxcc_get_execution_comp.sh -m <MASKING IP> -u <MASKING User> -p <MASKING Password>
```

---

## dpxcc_get_execution.sh

```
Usage: dpxcc_get_execution.sh [options]
Options:
  --log-file          -l  Log file name              - Default Value: Current date_time.log
  --output-file       -o  Output filename            - Default Value: Current date_time.json/csv
  --output-type       -t  Output filetype (json/csv) - Default Value: json
  --proxy-bypass      -x  Proxy ByPass               - Default: true
  --https-insecure    -k  Make Https Insecure        - Default: false
  --masking-engine    -m  Masking Engine Address     - Required value
  --masking-username  -u  Masking Engine User Name   - Required value
  --masking-pwd       -p  Masking Engine Password    - Required value
  --help              -h  Show this help
Example:
dpxcc_get_execution.sh -m <MASKING IP> -u <MASKING User> -p <MASKING Password>
```
