# Delphix CC Profile & Expressions Setup

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
#    --masking-engine         -m Masking Engine Address                                             Required Value
#    --masking-user           -u Masking Engine User Name                                           Required Value
#    --masking-pwd            -p Password                                                           Required Value
#    --help                   -h help
#
#   Ex.: dpxcc_setup_profileset.sh --profile-name <PROFILE> -e ./expressions.csv -d domains.csv -m <Masking IP> -u <Masking User> -p <Masking Password>
```
