# Delphix CC Profileset/Domains/Expressions/Algorithms Setup

### dpxcc_setup_profileset.sh
```sh
# dpxcc_setup_profileset.sh
# Created: Paulo Victor Maluf - 09/2019
# Modified: Horacio Dos - 10/2023
# Parameters:
#
#   dpxcc_setup_profileset.sh --help
#
#    Parameter             Short Description                                                        Default
#    --------------------- ----- ------------------------------------------------------------------ --------------
#    --profile-name           -p Profile name                                                       Required Value
#    --expressions-file       -e CSV file: ExpressionName;DomainName;level;Regex                    expressions.csv
#    --domains-file           -d CSV file: domainName;defaultAlgorithmCode;defaultTokenizationCode  domains.csv
#    --algorithms-file        -a Meta File with Algorithms files                                    algorithms.csv
#    --exe-algorithms         -x Execute Algorithms Setup                                           true
#    --ignore-errors          -i Ignore errors while adding domains/express/algorithms              false
#    --masking-engine         -m Masking Engine Address                                             Required Value
#    --masking-user           -u Masking Engine User Name                                           Required Value
#    --masking-pwd            -p Password                                                           Required Value
#    --help                   -h help
#
#    Example: dpxcc_setup_profileset.sh -p <PROFILE> -e ./expressions.csv -d domains.csv -a algorithms.csv -x true -i false -m  <Masking IP> -u <Masking User> -p <Masking Password>
#
# dpxcc_setup_algorithms.sh
# Created: Horacio Dos - 10/2023
# Parameters:
#
#   dpxcc_setup_algorithms.sh --help
#
#    Parameter             Short Description                                                        Default
#    --------------------- ----- ------------------------------------------------------------------ --------------
#    --algorithms-file     -a    File containing Algorithms                                         Required value
#    --ignore-errors       -i    Ignore errors while adding Algorithms                              false
#    --masking-engine      -m    Masking Engine Address                                             Required value
#    --masking-username    -u    Masking Engine User Name                                           Required value
#    --masking-pwd         -p    Masking Engine Password                                            Required value
#    --help                -h    Show this help
#     
#    Example: dpxcc_setup_algorithms.sh -a algorithms.csv -i false -m <MASKING IP> -u <MASKING User> -p <MASKING Password>
#
```
