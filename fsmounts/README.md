# Delphix CC Filesystem Mounts

```sh
# dpxcc_create_fsmounts.sh
# Created: Horacio Dos - 11/2023
# Parameters:
#
#   dpxcc_create_fsmounts.sh --help
#
#    Parameter             Short Description                                                        Default
#    --------------------- ----- ------------------------------------------------------------------ --------------
#    --fsmounts-file       -f    File containing FS Mounts                                          fsmounts.csv
#    --proxy-bypass        -x    Proxy ByPass                                                       true
#    --http-secure         -k    (http/https)                                                       false
#    --masking-engine      -m    Masking Engine Address                                             Required value
#    --masking-username    -u    Masking Engine User Name                                           Required value
#    --masking-pwd         -p    Masking Engine Password                                            Required value
#    --help                -h    Show this help
#     
#    Example: dpxcc_create_fsmounts.sh -m <MASKING IP> -u <MASKING User> -p <MASKING Password>
#
```
