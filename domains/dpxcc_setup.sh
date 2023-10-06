#!/bin/bash
#
# dpxcc_setup.sh
# Created: Paulo Victor Maluf - 09/2019
# Modified: Horacio Dos - 10/2023
#
# Parameters:
#
#   dpxcc_setup.sh --help
#
#    Parameter             Short Description                                                        Default
#    --------------------- ----- ------------------------------------------------------------------ ---------------
#    --profile-name           -p Profile name                                                       TEST
#    --expressions-file       -e Delimiter file with: ExpressionName;DomainName;level;Regex         expressions.csv               
#    --domains-file           -d Delimiter file with: Domain Name;Classification;Algorithm          domains.csv 
#    --masking-engine         -m Masking Engine Address 
#    --help                   -h help
#
#   Ex.: 
#   dpxcc_setup.sh --profile-name TEST -e ./expressions.csv -d domains.csv -m 192.168.73.85
#
# Changelog:
#
# Date       Author              Description
# ---------- ------------------- -------------------------------------------------------------------------
# 10/2023	 Horacio Dos		 Removed all parameters and keep only profile name, expressions & domains 
#=========================================================================================================

################################
# Global Variables             #
################################
USERNAME="Admin"
PASSWORD="Admin-12"
LAST=".last"
PROFILENAME="TEST"

################################
# Functions                    #
################################
help()
{
  head -33 $0 | tail -31
  exit
}

log (){
  echo -ne "[`date '+%d%m%Y %T'`] $1" | tee -a ${LAST}
}

# Check if $1 is equal to 0. If so print out message specified in $2 and exit.
check_empty() {
    if [ $1 -eq 0 ]; then
        echo $2
        exit 1
    fi
}

# Check if $1 is an object and if it has an 'errorMessage' specified. If so, print the object and exit.
check_error() {
    # ${JQ} returns a literal null so we have to check againt that...
    if [ "$(echo "$1" | ${JQ} -r 'if type=="object" then .errorMessage else "null" end')" != 'null' ]; then
        echo $1
        exit 1
    fi
}

# Login and set the correct $AUTH_HEADER.
login() {
echo "* logging in..."
LOGIN_RESPONSE=$(curl -s -X POST -H 'Content-Type: application/json' -H 'Accept: application/json' --data @- $MASKING_ENGINE/login <<EOF
{
    "username": "$USERNAME",
    "password": "$PASSWORD"
}
EOF
)
    check_error "$LOGIN_RESPONSE"
    TOKEN=$(echo $LOGIN_RESPONSE | ${JQ} -r '.Authorization')
    AUTH_HEADER="Authorization: $TOKEN"
}


add_expression(){
DOMAIN=${1}
EXPRESSNAME=${2}
REGEXP=${3}
DATALEVEL=${4}

curl -s -X POST -H ''"${AUTH_HEADER}"'' -H 'Content-Type: application/json' -H 'Accept: application/json' --data @- ${MASKING_ENGINE}/profile-expressions <<EOF
{
  "domainName": "${DOMAIN}",
  "expressionName": "${EXPRESSNAME}",
  "regularExpression": "${REGEXP}",
  "dataLevelProfiling": ${DATALEVEL}
}
EOF
}

add_domain(){
NEW_DOMAIN=${1}
CLASSIFICATION=${2}
ALGORITHM=${3}

curl -s -X POST -H ''"${AUTH_HEADER}"'' -H 'Content-Type: application/json' -H 'Accept: application/json' --data @- ${MASKING_ENGINE}/domains <<EOF
{
  "domainName": "${NEW_DOMAIN}",
  "classification": "${CLASSIFICATION}",
  "defaultAlgorithmCode": "${ALGORITHM}"
}
EOF
}

add_profileset(){
PROFILENAME=${1}
EXPRESSID=${2}

curl -s -X POST -H ''"${AUTH_HEADER}"'' -H 'Content-Type: application/json' -H 'Accept: application/json' --data @- ${MASKING_ENGINE}/profile-sets <<EOF
{
  "profileSetName": "${PROFILENAME}",
  "profileExpressionIds": [ ${EXPRESSID} ]
}
EOF
}

################################
# ARGPARSER                    #
################################
# Verifica se foi passado algum parametro
[ "$1" ] || { help ; exit 1 ; }

JQ="$(which jq)"
[ -x "${JQ}" ] || { echo "jq not found. Please install 'jq' package and try again." ; exit 1 ; }

# Tratamento dos Parametros
for arg
do
    delim=""
    case "$arg" in
    #translate --gnu-long-options to -g (short options)
      --profile-name)         args="${args}-p ";;
      --expressions-file)     args="${args}-e ";;
      --domains-file)         args="${args}-d ";;
      --masking-engine)       args="${args}-m ";;
      --help)                 args="${args}-h ";;
      #pass through anything else
      *) [[ "${arg:0:1}" == "-" ]] || delim="\""
         args="${args}${delim}${arg}${delim} ";;
    esac
done

eval set -- $args

while getopts ":h:p:d:m:e:" PARAMETRO
do
    case $PARAMETRO in
        h) help;;
        p) PROFILENAME=${OPTARG[@]};;
        e) EXPRESSFILE=${OPTARG[@]};;
        d) DOMAINSFILE=${OPTARG[@]};;
        m) MASKING_ENGINE=${OPTARG[@]};;
        :) echo "Option -$OPTARG requires an argument."; exit 1;;
        *) echo $OPTARG is an unrecognized option ; echo $USAGE; exit 1;;
    esac
done

################################
# MAIN                         #
################################
if [ ${MASKING_ENGINE} ]
  then
    # Set masking engine variable from user input
    MASKING_ENGINE="http://${MASKING_ENGINE}/masking/api"
    
    # Login on Masking Engine
    login
    
    if [ ${EXPRESSFILE} ] && [ ${DOMAINSFILE} ]
      then
        # Create Domains 
        log "Creating domain ${NEW_DOMAIN}...\n"
        while IFS=\; read -r NEW_DOMAIN CLASSIFICATION ALGORITHM
        do
          if [[ ! ${NEW_DOMAIN} =~ "#" ]]
            then
              ret=$(add_domain ${NEW_DOMAIN} ${CLASSIFICATION} ${ALGORITHM})
          fi
        done < ${DOMAINSFILE}

        # Create Expressions 
        log "Creating expressions: \n"
        while IFS=\; read -r EXPRESSNAME DOMAIN DATALEVEL REGEXP
        do
          if [[ ! ${EXPRESSNAME} =~ "#" ]]
            then
              log "* ${EXPRESSNAME}\n" 0
              ret=$(add_expression ${DOMAIN} ${EXPRESSNAME} ${REGEXP} ${DATALEVEL} | tee -a $$.tmp)
          fi
        done < ${EXPRESSFILE}
      
        # Get Created Expression Ids
        # 7 - Creditcard
        # 8 - Creditcard
        # 11 - Email
        # 22 - Creditcard Data
        # 23 - Email Data
        # 49 - Ip Address Data
        # 50 - Ip Address
        EXPRESSID=$(egrep -o '"profileExpressionId":[0-9]+' $$.tmp | cut -d: -f2 | xargs | sed 's/ /,/g')
        EXPRESSID="7,8,11,22,23,49,50,${EXPRESSID}"

        # Add ProfileSet
        log "Adding expressions ids ${EXPRESSID} to ${PROFILENAME}...\n"
        ret=$(add_profileset "${PROFILENAME}" "${EXPRESSID}")

        # remove tmpfile
        rm -f $$.tmp
    fi   
fi
