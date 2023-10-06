# Delphix CC Scripts

### Assorted scripts to configure Delphix CC LDAP
```sh
# dpxcc_config_ldap.sh
# Created: Horacio Dos - 10/2023
# Todo: Include parameters
# Parameters:
#
#   dpxcc_config_ldap.sh --help
#
#    Parameter             Short Description                                                        Default
#    --------------------- ----- ------------------------------------------------------------------ --------------
#    --status                 -s Status                                                             disabled
#    --host                   -h LDAP Server Address                                                192.168.100.1
#    --port                   -p LDAP Port Number                                                   389
#    --masking-engine         -m Masking Engine Address                                             192.168.1.100 
#    --basedn                 -b BaseDN                                                             DC=candy,DC=com,DC=ar
#    --domain                 -d NETBIOS Domain Name                                                CANDY
#    --tls                    -t Enable TLS                                                         false
     --filter                 -f LDAP Filter                                                        (&(objectClass=person)(sAMAccountName=?))                  
#    --help                   -h help
#
#   Ex.: dpxcc_config_ldap.sh --status enabled 
```
