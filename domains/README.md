# Delphix CC Profile & Expressions Setup

### dpxcc_setup.sh
```sh
# dpxcc_setup.sh
# Created: Paulo Victor Maluf - 09/2019
# Modified: Horacio Dos - 10/2023
# Parameters:
#
#   dpxcc_setup.sh --help
#
#    Parameter             Short Description                                                        Default
#    --------------------- ----- ------------------------------------------------------------------ --------------
#    --profile-name           -p Profile name                                                       TEST
#    --expressions-file       -e CSV file like ExpressionName;DomainName;level;Regex                expressions.csv
#    --domains-file           -d CSV file like Domain Name;Classification;Algorithm                 domains.csv
#    --masking-engine         -m Masking Engine Address
#    --help                   -h help
#
#   Ex.: dpxcc_setup.sh --profile-name TEST -e ./expressions.csv -d domains.csv -m 172.168.8.128
```
