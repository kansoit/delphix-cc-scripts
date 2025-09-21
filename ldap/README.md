# LDAP Configuration Scripts

This directory contains scripts for managing LDAP configuration on the Delphix Masking Engine.

---

## dpxcc_setup_ldap.sh

This script configures the LDAP settings on the Masking Engine.

```
Usage: dpxcc_setup_ldap.sh [options]
Options:
  --ldap-host       -s    LDAP Server IP Address       - Required value
  --ldap-port       -t    LDAP Port Number             - Default: 389
  --ldap-basedn     -b    BaseDN                       - Default: DC=candy,DC=com,DC=ar
  --ldap-domain     -d    NETBIOS Domain Name          - Default: CANDY
  --ldap-tls        -l    Enable LDAP TLS (true/false) - Default: false
  --ldap-filter     -f    LDAP Filter                  - Default: (&(objectClass=person)(sAMAccountName=?))
  --ldap-enabled    -e    Enable LDAP (true/false)     - Default: false
  --log-file        -o    Log file name                - Default Value: Current date_time.log
  --proxy-bypass    -x    Proxy ByPass                 - Default: true
  --https-insecure  -k    Make Https Insecure          - Default: false
  --masking-engine  -m    Masking Engine Address       - Required value
  --masking-user    -u    Masking Engine User Name     - Required value
  --masking-pwd     -p    Masking Engine Password      - Required value
  --no-ask          -a    No Ask dialog                - Default: no (Future use)
  --no-rollback     -r    No Rollback dialog           - Default: no (Future use)
  --help            -h    Show this help
Example:
dpxcc_setup_ldap.sh -s <LDAP IP> -b DC=candy,DC=com,DC=ar -d CANDY -e true -m <MASKING IP> -u <MASKING User> -p <MASKING Password>
```

---

## dpxcc_getconfig_ldap.sh

This script retrieves the current LDAP configuration from the Masking Engine.

```
Usage: dpcc_getconfig_ldap.sh [options]
Options:
  --log-file        -o    Log file name                - Default Value: Current date_time.log
  --proxy-bypass    -x    Proxy ByPass                 - Default: true
  --https-insecure  -k    Make Https insecure          - Default: false
  --masking-engine  -m    Masking Engine Address       - Required value
  --masking-user    -u    Masking Engine User Name     - Required value
  --masking-pwd     -p    Masking Engine Password      - Required value
  --help            -h    Show this help
Example:
dpxcc_getconfig_ldap.sh -m <MASKING IP> -u <MASKING User> -p <MASKING Password>
```