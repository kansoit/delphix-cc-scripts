#!/usr/bin/bash


apiVer="v5.1.22"
MASKING_ENGINE=""
MASKING_USERNAME=""
MASKING_PASSWORD=""
URL_BASE=""
PROFILE_NAME=""
EXPRESS_FILE='expressions.csv'
DOMAINS_FILE='domains.csv'
ALGO_FILE='algorithms.csv'
ALGO_EXE=true
IGN_ERROR='false'
KEEPALIVE=300
EXPRESSID_LIST="7,8,11,22,23,49,50"
# Extra Expression Ids
# 7 - Creditcard
# 8 - Creditcard
# 11 - Email
# 22 - Creditcard Data
# 23 - Email Data
# 49 - Ip Address Data
# 50 - Ip Address
logFileDate=$(date '+%d%m%Y_%H%M%S')
logFileName="dpxcc_setup_profileset_$logFileDate.log"
PROXY_BYPASS=true
SECURE_CONN=false


show_help() {
    echo "Usage: dpxcc_setup_profileset.sh [options]"
    echo "Options:"
    echo "  --profile-name      -f  Profile Name                    - Required value"
    echo "  --expressions-file  -e  File with Expressions           - Default: expressions.csv"
    echo "  --domains-file      -d  File with Domains               - Default: domains.csv"
    echo "  --algorithms-file   -a  File with Algorithms            - Default: algorithms.csv"
    echo "  --run-algorithms    -r  Run Algorithms Setup            - Default: true"
    echo "  --ignore-errors     -i  Ignore errors                   - Default: false"
    echo "  --log-file          -o  Log file name                   - Default: Current date_time.log"
    echo "  --proxy-bypass      -x  Proxy ByPass                    - Default: true"
    echo "  --http-secure       -k  (http/https)                    - Default: false"
    echo "  --masking-engine    -m  Masking Engine Address          - Required value"
    echo "  --masking-username  -u  Masking Engine User Name        - Required value"
    echo "  --masking-pwd       -p  Masking Engine Password         - Required value"
    echo "  --help              -h  Show this help"
    echo "Example:"
    echo "dpxcc_setup_profileset.sh -f <PROFILE NAME> -m <MASKING IP> -u <MASKING User> -p <MASKING Password>"
    exit 1
}

log (){
    local logMsg="$1"
    local logMsgDate
    logMsgDate="[$(date '+%d%m%Y %T')]"
    echo -ne "$logMsgDate $logMsg" | tee -a "$logFileName"
}

add_parms() {
    ALLPARMS="$ALLPARMS""$1"
}

check_parm() {
    local PARMS="$1"

    local KEY="f"
    if [[ ! "$PARMS" == *"$KEY"* ]]; then
        echo "Option -f is missing. Profile Name is required."
        exit 1
    fi

    local KEY="m"
    if [[ ! "$PARMS" == *"$KEY"* ]]; then
        echo "Option -m is missing. Masking Engine IP Address is required."
        exit 1
    fi

    local KEY="u"
    if [[ ! "$PARMS" == *"$KEY"* ]]; then
        echo "Option -u is missing. Masking Engine User Name is required."
        exit 1
    fi

    local KEY="p"
    if [[ ! "$PARMS" == *"$KEY"* ]]; then
        echo "Option -p is missing. Masking Engine Password is required."
        exit 1
    fi
}

check_packages() {
    # Check Required Packages
    local JQ
    JQ=$(which jq)
    local CURL
    CURL=$(which curl)

    [ -x "${JQ}" ] || { echo "jq not found. Please install 'jq' package and try again." ; exit 1 ; }
    [ -x "${CURL}" ] || { echo "curl not found. Please install 'curl' package and try again." ; exit 1 ; }
}

check_conn() {
    local MASKING_IP="$1"
    local PROXY_BYPASS="$2"
    local SECURE_CONN="$3"

    local curl_cmd
    curl_cmd="curl -s -v -m 5"

    local URL

    if [ "$SECURE_CONN" = true ]; then
        URL="https://$MASKING_IP"
    else
        URL="http://$MASKING_IP"
    fi

    if [ "$PROXY_BYPASS" = true ]; then
        curl_cmd="$curl_command -x ''"
    fi

    local curl_cmd="$curl_cmd -o /dev/null $URL 2>&1"
    local curlResponse
    curlResponse=$(eval "$curl_cmd")

    local curlError

    if [[ "$curlResponse" == *"timed out"* ]];
    then
       curlError=$(echo "$curlResponse" | grep -o "Connection timed out")
       echo "Error: $curlError Please verify if the Masking IP Address $MASKING_IP is correct or bypass proxy if needed with -x true option."
       echo "Execute curl -s -v -m 5 -o /dev/null http://$MASKING_IP and check the output to verify communications issues between $HOSTNAME and the Masking Engine."
       exit 1
    fi

    if [[ "$curlResponse" == *"Connection refused"* ]];
    then
       curlError=$(echo "$curlResponse" | grep -o "Connection refused")
       echo "Error: $curlError - Please confirm the desired level of security for the connection (http/https) and ensure that $MASKING_IP is not blocked"
       echo "Execute curl -s -v -m 5 -o /dev/null http://$MASKING_IP and check the output to verify communications issues between $HOSTNAME and the Masking Engine."
       exit 1
    fi

    if [[ "$curlResponse" == *"307 Temporary Redirect"* ]];
    then
       curlError=$(echo "$curlResponse" | grep -o "307 Temporary Redirect")
       echo "Error: $curlError - Please verify if a secure connection (https) to the Masking Engine is required."
       echo "Execute curl -s -v -m 5 -o /dev/null https://$MASKING_IP and check the output to verify communications issues between $HOSTNAME and the Masking Engine."
       exit 1
    fi
}

check_file() {
    local csvFile="$1"
    local IGNORE="$2"

    if [ ! -f "$csvFile" ] && [ "$IGNORE" != "true" ]; then
        echo "Input file $csvFile is missing"
        exit 1
    fi
}

# Check if $1 not empty. If so print out message specified in $2 and exit.
check_response() {
    local RESPONSE="$1"
    local IGNORE="$2"

    if [ -z "$RESPONSE" ];
    then
       log "Check Response! No data\n"
       if [[ "$IGNORE" == "false" ]];
       then
          dpxlogout
          exit 1
       fi
    fi
}

check_error() {
    local FUNC="$1"
    local API="$2"
    local RESPONSE="$3"
    local IGNORE="$4"

    # jq returns a literal null so we have to check against that...
    if [ "$(echo "$RESPONSE" | jq -r 'if type=="object" then .errorMessage else "null" end')" != 'null' ];
    then
        log "Check Error! Function: $FUNC Api_Endpoint: $API Req_Response=$RESPONSE\n"
        if [[ "$IGNORE" == "false" ]];
        then
            dpxlogout
            exit 1
        fi
    fi
}

build_curl() {
    local URL_BASE="$1"
    local API="$2"
    local METHOD="$3"
    local AUTH="$4"
    local CONTENT_TYPE="$5"
    local KEEPALIVE="$6"
    local PROXY_BYPASS="$7"
    local SECURE_CONN="$8"
    local FORM="$9"
    local DATA="${10}"

    if [ "$SECURE_CONN" = true ]; then
        URL_BASE="https://$URL_BASE"
    else
        URL_BASE="http://$URL_BASE"
    fi

    curl_command="curl -X $METHOD"

    if [ -n "$AUTH" ]; then
        curl_command="$curl_command -H ''\"$AUTH\"''"
    fi

    curl_command="$curl_command -H 'Content-Type: $CONTENT_TYPE'"

    if [ "$PROXY_BYPASS" = true ]; then
        curl_command="$curl_command -x ''"
    fi

    curl_command="$curl_command --keepalive-time $KEEPALIVE"

    if [ -n "$FORM" ]; then
        curl_command="$curl_command -F '$FORM'"
    fi

    if [ -n "$DATA" ]; then
        curl_command="$curl_command --data '$DATA'"
    fi

    if [ "$SECURE_CONN" = true ]; then
        curl_command="$curl_command -k "
    fi

    curl_command="$curl_command -s $URL_BASE/$API"
    log "$curl_command\n"
}

dpxlogin() {
    local USERNAME="$1"
    local PASSWORD="$2"

    local FUNC='dpxlogin'
    local URL_BASE="$MASKING_ENGINE/masking/api/$apiVer"
    local API='login'
    local METHOD="POST"
    local CONTENT_TYPE="application/json"
    local FORM=""

    local DATA="{\"username\": \"$USERNAME\", \"password\": \"$PASSWORD\"}"
    AUTH_HEADER=""

    log "Logging in with $USERNAME ...\n"
    build_curl "$URL_BASE" "$API" "$METHOD" "$AUTH_HEADER" "$CONTENT_TYPE" "$KEEPALIVE" "$PROXY_BYPASS" "$SECURE_CONN" "$FORM" "$DATA"
    local LOGIN_RESPONSE
    LOGIN_RESPONSE=$(eval "$curl_command")
    local IGNORE="false"
    check_error "$FUNC" "$API" "$LOGIN_RESPONSE" "$IGNORE"
    local LOGIN_VALUE
    LOGIN_VALUE=$(echo "$LOGIN_RESPONSE" | jq -r '.errorMessage')
    check_response "$LOGIN_VALUE" "$IGNORE"
    TOKEN=$(echo "$LOGIN_RESPONSE" | jq -r '.Authorization')
    AUTH_HEADER="Authorization: $TOKEN"
    log "$MASKING_USERNAME logged in successfully with token $TOKEN\n"
}

dpxlogout() {
    local FUNC='dpxlogout'
    local URL_BASE="$MASKING_ENGINE/masking/api/$apiVer"
    local API='logout'
    local METHOD="PUT"
    local AUTH="$AUTH_HEADER"
    local CONTENT_TYPE="application/json"
    local FORM=""
    local DATA=""

    if [ -n "$AUTH_HEADER" ]; then
        log "Logging out ...\n"
        build_curl "$URL_BASE" "$API" "$METHOD" "$AUTH" "$CONTENT_TYPE" "$KEEPALIVE" "$PROXY_BYPASS" "$SECURE_CONN" "$FORM" "$DATA"
        eval "$curl_command"
        log "$MASKING_USERNAME Logged out successfully with token $TOKEN\n"
    fi
}

add_domains() {
    local DOMAIN_NAME="$1"
    local DFT_ALGO_CODE="$2"
    local DFT_TOKEN_CODE="$3"

    local FUNC='add_domains'
    local URL_BASE="$MASKING_ENGINE/masking/api/$apiVer"
    local API='domains'
    local METHOD="POST"
    local AUTH="$AUTH_HEADER"
    local CONTENT_TYPE="application/json"
    local FORM=""

    if [ -z "$DFT_TOKEN_CODE" ]; then
       local DATA="{\"defaultAlgorithmCode\": \"$DFT_ALGO_CODE\", \"domainName\": \"$DOMAIN_NAME\"}"
    else
       local DATA="{\"defaultAlgorithmCode\": \"$DFT_ALGO_CODE\", \"defaultTokenizationCode\": \"$DFT_TOKEN_CODE\", \"domainName\": \"$DOMAIN_NAME\"}"
    fi

    log "Adding Domain $DOMAIN_NAME using Algorithm $DFT_ALGO_CODE ...\n"
    build_curl "$URL_BASE" "$API" "$METHOD" "$AUTH" "$CONTENT_TYPE" "$KEEPALIVE" "$PROXY_BYPASS" "$SECURE_CONN" "$FORM" "$DATA"
    local ADD_DOMAINS_RESPONSE
    ADD_DOMAINS_RESPONSE=$(eval "$curl_command")

    check_error "$FUNC" "$API" "$ADD_DOMAINS_RESPONSE" "$IGN_ERROR"
    local ADD_DOMAINS_VALUE
    ADD_DOMAINS_VALUE=$(echo "$ADD_DOMAINS_RESPONSE" | jq -r '.domainName')
    check_response "$ADD_DOMAINS_VALUE" "$IGN_ERROR"

    if [ ! "$ADD_DOMAINS_VALUE" == "null" ]; then
        log "Domain: $ADD_DOMAINS_VALUE added.\n"
    else
        log "Domain NOT added.\n"
    fi
}

add_expressions() {
    local DOMAIN="$1"
    local EXPRESSNAME="$2"
    local REGEXP="$3"
    local DATALEVEL="$4"

    local FUNC='add_domains'
    local URL_BASE="$MASKING_ENGINE/masking/api/$apiVer"
    local API='profile-expressions'
    local METHOD="POST"
    local AUTH="$AUTH_HEADER"
    local CONTENT_TYPE="application/json"
    local FORM=""

    local DATA="{ \"domainName\": \"$DOMAIN\", \"expressionName\": \"$EXPRESSNAME\", \"regularExpression\": \"$REGEXP\", \"dataLevelProfiling\": \"$DATALEVEL\"}"

    log "Adding Expression $EXPRESSNAME to Domain $DOMAIN ...\n"
    build_curl "$URL_BASE" "$API" "$METHOD" "$AUTH" "$CONTENT_TYPE" "$KEEPALIVE" "$PROXY_BYPASS" "$SECURE_CONN" "$FORM" "$DATA"
    local ADD_EXPRESS_RESPONSE
    ADD_EXPRESS_RESPONSE=$(eval "$curl_command")

    check_error "$FUNC" "$API" "$ADD_EXPRESS_RESPONSE" "$IGN_ERROR"
    local ADD_EXPRESS_VALUE
    ADD_EXPRESS_VALUE=$(echo "$ADD_EXPRESS_RESPONSE" | jq -r '.expressionName')
    check_response "$ADD_EXPRESS_VALUE" "$IGN_ERROR"

    if [ ! "$ADD_EXPRESS_VALUE" == "null" ]; then
        log "Expression: $ADD_EXPRESS_VALUE added.\n"
    else
        log "Expression NOT added.\n"
    fi

    # Return EXPRESSID_LIST
    local EXPRESSID_VALUE
    EXPRESSID_VALUE=$(echo "$ADD_EXPRESS_RESPONSE" | jq -r '.profileExpressionId')
    if [[ ! "$EXPRESSID_VALUE" == "null" ]];
    then
        EXPRESSID_LIST="$EXPRESSID_LIST,$EXPRESSID_VALUE"
    fi
}

add_profileset() {
    local PROFILE_NAME="$1"
    local EXPRESSID_LIST="$2"

    local FUNC='add_profileset'
    local URL_BASE="$MASKING_ENGINE/masking/api/$apiVer"
    local API='profile-sets'
    local METHOD="POST"
    local AUTH="$AUTH_HEADER"
    local CONTENT_TYPE="application/json"
    local FORM=""

    local DATA="{\"profileSetName\": \"$PROFILE_NAME\", \"profileExpressionIds\": [ $EXPRESSID_LIST ]}"

    log "Adding Profileset $PROFILE_NAME using Expressions ids ${EXPRESSID_LIST} ...\n"
    build_curl "$URL_BASE" "$API" "$METHOD" "$AUTH" "$CONTENT_TYPE" "$KEEPALIVE" "$PROXY_BYPASS" "$SECURE_CONN" "$FORM" "$DATA"
    local ADD_PROFILE_RESPONSE
    ADD_PROFILE_RESPONSE=$(eval "$curl_command")

    check_error "$FUNC" "$API" "$ADD_PROFILE_RESPONSE" "$IGN_ERROR"
    local ADD_PROFILE_VALUE
    ADD_PROFILE_VALUE=$(echo "$ADD_PROFILE_RESPONSE" | jq -r '.profileSetName')
    check_response "$ADD_PROFILE_VALUE" "$IGN_ERROR"

    if [ ! "$ADD_PROFILE_VALUE" == "null" ]; then
        log "ProfileSet: $ADD_PROFILE_VALUE added using expressions ids ${EXPRESSID_LIST}\n"
    else
        log "ProfileSet NOT added.\n"
    fi
}

check_packages

# Parameters
[ "$1" ] || { show_help; }

args=""
for arg
do
    delim=""
    case "$arg" in
        --profile-name)
            args="${args}-f "
            ;;
        --expressions-file)
            args="${args}-e "
            ;;
        --domains-file)
            args="${args}-d "
            ;;
        --algorithms-file)
            args="${args}-a "
            ;;
        --run-algorithms)
            args="${args}-r "
            ;;
        --ignore-errors)
            args="${args}-i "
            ;;
        --log-file)
            args="${args}-o "
            ;;
        --proxy-bypass)
            args="${args}-x "
            ;;
        --http-secure)
            args="${args}-k "
            ;;
        --masking-engine)
            args="${args}-m "
            ;;
        --masking-user)
            args="${args}-u "
            ;;
        --masking-pwd)
            args="${args}-p "
            ;;
        --help|-h)
            show_help
            ;;
      *) [[ "${arg:0:1}" == "-" ]] || delim="\""
         args="${args}${delim}${arg}${delim} ";;
    esac
done

eval set -- "$args"

while getopts ":h:f:e:d:a:r:i:o:x:k:m:u:p:" PARAMETERS; do
    case $PARAMETERS in
        h)
        	;;
        f)
        	PROFILE_NAME=${OPTARG[*]}
        	add_parms "$PARAMETERS";
        	;;
        e)
        	EXPRESS_FILE=${OPTARG[*]}
        	add_parms "$PARAMETERS";
        	;;
        d)
        	DOMAINS_FILE=${OPTARG[*]}
        	add_parms "$PARAMETERS";
        	;;
        a)
        	ALGO_FILE=${OPTARG[*]}
        	add_parms "$PARAMETERS";
        	;;
        r)
        	ALGO_EXE=${OPTARG[*]}
        	add_parms "$PARAMETERS";
        	;;
        i)
        	IGN_ERROR=${OPTARG[*]}
        	add_parms "$PARAMETERS";
        	;;
        o)
        	logFileName=${OPTARG[*]}
        	add_parms "$PARAMETERS";
        	;;
        x)
        	PROXY_BYPASS=${OPTARG[*]}
        	add_parms "$PARAMETERS";
        	;;
        k)
        	SECURE_CONN=${OPTARG[*]}
        	add_parms "$PARAMETERS";
        	;;
        m)
        	MASKING_ENGINE=${OPTARG[*]}
        	add_parms "$PARAMETERS";
        	;;
        u)
        	MASKING_USERNAME=${OPTARG[*]}
        	add_parms "$PARAMETERS";
        	;;
        p)
        	MASKING_PASSWORD=${OPTARG[*]}
        	add_parms "$PARAMETERS";
        	;;
        :) echo "Option -$OPTARG requires an argument."; exit 1;;
        *) echo "$OPTARG is an unrecognized option"; exit 1;;
    esac
done

# Check all parameters
check_parm "$ALLPARMS"

# Check connection
check_conn "$MASKING_ENGINE" "$PROXY_BYPASS" "$SECURE_CONN"

# Check csv file exists
check_file "$ALGO_FILE" "$IGN_ERROR"
check_file "$DOMAINS_FILE" "$IGN_ERROR"
check_file "$EXPRESS_FILE" "$IGN_ERROR"

if [ "$ALGO_EXE" = true ]; then
    runCmd="./dpxcc_setup_algorithms.sh -a $ALGO_FILE -i $IGN_ERROR -o $logFileName -x $PROXY_BYPASS -k $SECURE_CONN -m $MASKING_ENGINE -u $MASKING_USERNAME -p $MASKING_PASSWORD"
    log "$runCmd\n"
    eval "$runCmd"
fi

dpxlogin "$MASKING_USERNAME" "$MASKING_PASSWORD"

# Create Domains
while IFS=\; read -r DOMAIN_NAME DFT_ALGO_CODE DFT_TOKEN_CODE
do
    if [[ ! "$DOMAIN_NAME" =~ "#" ]];
    then
        add_domains "$DOMAIN_NAME" "$DFT_ALGO_CODE" "$DFT_TOKEN_CODE"
    fi
done < "$DOMAINS_FILE"

# Create Expressions
while IFS=\; read -r EXPRESS_NAME DOMAIN DATALEVEL REGEXP
do
    if [[ ! "$EXPRESS_NAME" =~ "#" ]];
    then
        add_expressions "$DOMAIN" "$EXPRESS_NAME" "$REGEXP" "$DATALEVEL"
    fi
done < "$EXPRESS_FILE"

# Add ProfileSet
add_profileset "$PROFILE_NAME" "$EXPRESSID_LIST"

dpxlogout
