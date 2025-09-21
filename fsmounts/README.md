# File System Mounts Scripts

This directory contains scripts for managing File System Mounts on the Delphix Masking Engine.

---

## dpxcc_get_fsmounts.sh

This script retrieves a list of all file system mounts.

```
Usage: dpxcc_get_fsmounts.sh [options]
Options:
  --fsmounts-file     -f  FS Mounts Output File                 - Default: connect_fsmounts.csv
  --log-file          -o  Log file name                         - Default: Current date_time.log
  --proxy-bypass      -x  Proxy ByPass                          - Default: true
  --https-insecure    -k  Make Https Insecure                   - Default: false
  --masking-engine    -m  Masking Engine Address                - Required value
  --masking-username  -u  Masking Engine User Name              - Required value
  --masking-pwd       -p  Masking Engine Password               - Required value
  --help              -h  Show this help
Example:
dpxcc_get_fsmounts.sh -m <MASKING IP> -u <MASKING User> -p <MASKING Password>
```

---

## dpxcc_create_fsmounts.sh

This script creates new file system mounts.

```
Usage: dpxcc_create_fsmounts.sh [options]
Options:
  --fsmounts-file     -f  File containing FS mounts parameters  - Default: fsmounts.csv
  --log-file          -o  Log file name                         - Default: Current date_time.log
  --proxy-bypass      -x  Proxy ByPass                          - Default: true
  --https-insecure    -k  Make Https Insecure                   - Default: false
  --masking-engine    -m  Masking Engine Address                - Required value
  --masking-username  -u  Masking Engine User Name              - Required value
  --masking-pwd       -p  Masking Engine Password               - Required value
  --help              -h  Show this help
Example:
dpxcc_create_fsmounts.sh -m <MASKING IP> -u <MASKING User> -p <MASKING Password>
```

---

## dpxcc_connect_fsmounts.sh

This script connects existing file system mounts.

```
Usage: dpxcc_connect_fsmounts.sh [options]
Options:
  --fsmounts-file     -f  FS Mounts Input File                  - Default: connect_fsmounts.csv
  --log-file          -o  Log file name                         - Default: Current date_time.log
  --proxy-bypass      -x  Proxy ByPass                          - Default: true
  --https-insecure    -k  Make Https Insecure                   - Default: false
  --masking-engine    -m  Masking Engine Address                - Required value
  --masking-username  -u  Masking Engine User Name              - Required value
  --masking-pwd       -p  Masking Engine Password               - Required value
  --help              -h  Show this help
Example:
dpxcc_connect_fsmounts.sh -m <MASKING IP> -u <MASKING User> -p <MASKING Password>
```

---

## dpxcc_disconnect_fsmounts.sh

This script disconnects existing file system mounts.

```
Usage: dpxcc_disconnect_fsmounts.sh [options]
Options:
  --fsmounts-file     -f  FS Mounts Input File                  - Default: connect_fsmounts.csv
  --log-file          -o  Log file name                         - Default: Current date_time.log
  --proxy-bypass      -x  Proxy ByPass                          - Default: true
  --https-insecure    -k  Make Https Insecure                   - Default: false
  --masking-engine    -m  Masking Engine Address                - Required value
  --masking-username  -u  Masking Engine User Name              - Required value
  --masking-pwd       -p  Masking Engine Password               - Required value
  --help              -h  Show this help
Example:
dpxcc_disconnect_fsmounts.sh -m <MASKING IP> -u <MASKING User> -p <MASKING Password>
```

---

## dpxcc_delete_fsmounts.sh

This script deletes existing file system mounts.

```
Usage: dpxcc_delete_fsmounts.sh [options]
Options:
  --fsmounts-file     -f  FS Mounts Input File                  - Default: connect_fsmounts.csv
  --log-file          -o  Log file name                         - Default: Current date_time.log
  --proxy-bypass      -x  Proxy ByPass                          - Default: true
  --https-insecure    -k  Make Https Insecure                   - Default: false
  --masking-engine    -m  Masking Engine Address                - Required value
  --masking-username  -u  Masking Engine User Name              - Required value
  --masking-pwd       -p  Masking Engine Password               - Required value
  --help              -h  Show this help
Example:
dpxcc_delete_fsmounts.sh -m <MASKING IP> -u <MASKING User> -p <MASKING Password>
```