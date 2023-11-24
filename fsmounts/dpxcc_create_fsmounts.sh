#!/usr/bin/bash


apiVer="v5.1.22"
MASKING_ENGINE=""
MASKING_USERNAME=""
MASKING_PASSWORD=""
URL_BASE=""
FSMOUNTS_FILE="fsmounts.csv"
KEEPALIVE=300
logFileDate=$(date '+%d%m%Y_%H%M%S')
logFileName="dpxcc_create_fsmounts_$logFileDate.log"
PROXY_BYPASS=true
HttpsInsecure=false


show_help() {
    echo "Usage: dpxcc_create_fsmounts.sh [options]"
    echo "Options:"
    echo "  --fsmounts-file     -f  File containing FS mounts parameters  - Default: fsmounts.csv"
    echo "  --log-file          -o  Log file name                         - Default: Current date_time.log"
    echo "  --proxy-bypass      -x  Proxy ByPass                          - Default: true"
    echo "  --https-insecure    -k  Make Https Insecure                   - Default: false"
    echo "  --masking-engine    -m  Masking Engine Address                - Required value"
    echo "  --masking-username  -u  Masking Engine User Name              - Required value"
    echo "  --masking-pwd       -p  Masking Engine Password               - Required value"
    echo "  --help              -h  Show this help"
    echo "Example:"
    echo "dpxcc_create_fsmounts.sh -m <MASKING IP> -u <MASKING User> -p <MASKING Password>"
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
    local HttpsInsecure="$3"

    local curl_conn
    curl_conn="curl -s -v -m 5"

    local URL

    if [ "$HttpsInsecure" = true ]; then
        URL="https://$MASKING_IP"
    else
        URL="http://$MASKING_IP"
    fi

    if [ "$PROXY_BYPASS" = true ]; then
        curl_conn="$curl_conn -x ''"
    fi

    local curl_conn="$curl_conn -o /dev/null $URL 2>&1"
    local curlResponse
    curlResponse=$(eval "$curl_conn")

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

    if [ ! -f "$csvFile" ]; then
        echo "Input file $csvFile is missing"
        exit 1
    fi
}

# Check if $1 not empty. If so print out message specified in $2 and exit.
check_response() {
    local RESPONSE="$1"

    if [ -z "$RESPONSE" ];
    then
       log "Check Response! No data\n"
       dpxlogout
       exit 1
    fi
}

check_error() {
    local FUNC="$1"
    local API="$2"
    local RESPONSE="$3"

    # jq returns a literal null so we have to check against that...
    if [ "$(echo "$RESPONSE" | jq -r 'if type=="object" then .errorMessage else "null" end')" != 'null' ];
    then
        log "Check Error! Function: $FUNC Api_Endpoint: $API Req_Response=$RESPONSE\n"
        dpxlogout
        exit 1
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
    local HttpsInsecure="$8"
    local FORM="$9"
    local DATA="${10}"

    if [ "$HttpsInsecure" = true ]; then
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

    if [ "$HttpsInsecure" = true ]; then
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
    build_curl "$URL_BASE" "$API" "$METHOD" "$AUTH_HEADER" "$CONTENT_TYPE" "$KEEPALIVE" "$PROXY_BYPASS" "$HttpsInsecure" "$FORM" "$DATA"
    local LOGIN_RESPONSE
    LOGIN_RESPONSE=$(eval "$curl_command")
    check_error "$FUNC" "$API" "$LOGIN_RESPONSE"
    local LOGIN_VALUE
    LOGIN_VALUE=$(echo "$LOGIN_RESPONSE" | jq -r '.errorMessage')
    check_response "$LOGIN_VALUE"
    TOKEN=$(echo "$LOGIN_RESPONSE" | jq -r '.Authorization')
    AUTH_HEADER="Authorization: $TOKEN"
    log "$MASKING_USERNAME logged in successfully with token $TOKEN\n"
}

dpxlogout() {
    local FUNC='dpxlogout'
    local URL_BASE="$MASKING_ENGINE/masking/api/$apiVer"
    local API='logout'
    local METHOD="PUT"
    local CONTENT_TYPE="application/json"
    local FORM=""
    local DATA=""

    if [ -n "$AUTH_HEADER" ]; then
        log "Logging out ...\n"
        build_curl "$URL_BASE" "$API" "$METHOD" "$AUTH_HEADER" "$CONTENT_TYPE" "$KEEPALIVE" "$PROXY_BYPASS" "$HttpsInsecure" "$FORM" "$DATA"
        eval "$curl_command"
        log "$MASKING_USERNAME Logged out successfully with token $TOKEN\n"
    fi
}

create_fsmounts() {
    local mountName="$1"
    local hostAddress="$2"
    local mountPath="$3"
    local type="$4"
    local options="$5"
    local connectOnStartup="$6"

    local FUNC='create_fsmounts'
    local URL_BASE="$MASKING_ENGINE/masking/api/$apiVer"
    local API='mount-filesystem'
    local METHOD="POST"
    local AUTH="$AUTH_HEADER"
    local CONTENT_TYPE="application/json"
    local FORM=""

    local FullJson
    FullJson="{\"mountName\": \"$mountName\", \"hostAddress\": \"$hostAddress\", \"mountPath\": \"$mountPath\",\
               \"type\": \"$type\", \"options\": \"$options\", \"connectOnStartup\": $connectOnStartup}"
    local DATA
    DATA=$(echo "$FullJson" | jq -c)

    log "Creating fsmount $mountName ...\n"
    build_curl "$URL_BASE" "$API" "$METHOD" "$AUTH" "$CONTENT_TYPE" "$KEEPALIVE" "$PROXY_BYPASS" "$HttpsInsecure" "$FORM" "$DATA"
    local CREATE_FSMOUNT_RESPONSE
    CREATE_FSMOUNT_RESPONSE=$(eval "$curl_command")
    check_error "$FUNC" "$API" "$CREATE_FSMOUNT_RESPONSE"
    local CREATE_FSMOUNT_VALUE
    CREATE_FSMOUNT_VALUE=$(echo "$CREATE_FSMOUNT_RESPONSE" | jq -r '.mountName')
    check_response "$CREATE_FSMOUNT_VALUE"

    local MOUNTID_VALUE
    MOUNTID_VALUE=$(echo "$CREATE_FSMOUNT_RESPONSE" | jq -r '.mountId')

    if [ ! "$CREATE_FSMOUNT_VALUE" == "null" ]; then
        log "FS Mount: $CREATE_FSMOUNT_VALUE added with mountId: $MOUNTID_VALUE.\n"
    else
        log "FS Mount NOT added.\n"
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
        --fsmounts-file)
            args="${args}-f "
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

while getopts ":h:f:o:x:k:m:u:p:" PARAMETERS; do
    case $PARAMETERS in
        h)
        	;;
        f)
        	FSMOUNTS_FILE=${OPTARG[*]}
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
        	HttpsInsecure=${OPTARG[*]}
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
check_conn "$MASKING_ENGINE" "$PROXY_BYPASS" "$HttpsInsecure"

check_file "$FSMOUNTS_FILE"

dpxlogin "$MASKING_USERNAME" "$MASKING_PASSWORD"


while IFS=\; read -r mountName hostAddress mountPath type options algorithmExtension connectOnStartup
do
    if [[ ! "$mountName" =~ "#" ]];
    then
        create_fsmounts "$mountName" "$hostAddress" "$mountPath" "$type" "$options" "$algorithmExtension" "$connectOnStartup"
    fi
done < "$FSMOUNTS_FILE"

dpxlogout
