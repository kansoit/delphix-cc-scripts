# Delphix CC LDAP Scripts

### Assorted scripts to configure Delphix CC LDAP parameters
```sh
# dpxcc_config_ldap.sh
# Created: Horacio Dos - 10/2023
#
#   dpxcc_config_ldap.sh --help
#
#    Parameter             Short Description                                                        Default
#    --------------------- ----- ------------------------------------------------------------------ --------------
#    --ldap-host              -s LDAP Server Address                                                
#    --ldap-port              -t LDAP Port Number                                                   389
#    --ldap-basedn            -b BaseDN                                                             DC=candy,DC=com,DC=ar
#    --ldap-domain            -d NETBIOS Domain Name                                                CANDY
#    --ldap-tls               -l Enable TLS                                                         false
#    --ldap-filter            -f LDAP Search Filter                                                 (&(objectClass=person)(sAMAccountName=?))
#    --ldap-enabled           -e LDAP Enabled                                                       false
#    --masking-engine         -m Masking Engine Address                                             
#    --masking-user           -u Masking Engine User Name
#    --masking-pwd            -p Password
#    --no-ask                 -a No Ask dialog                                                      no
#    --no-rollback            -r No Rollback dialog                                                 no
#    --help                   -h help
#
#   Ex.: dpxcc_config_ldap.sh -s <Your IP> -b DC=candy,DC=com,DC=ar -d CANDY -e true -m <Your IP> -u <Your User> -p <Your Password>
```
