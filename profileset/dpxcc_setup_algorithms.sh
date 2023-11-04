#!/usr/bin/bash


apiVer="v5.1.22"
MASKING_ENGINE=""
MASKING_USERNAME=""
MASKING_PASSWORD=""
URL_BASE=""
ALGO_FILE="algorithms.csv"
IGN_ERROR="false"
KEEPALIVE=300
logFileDate=$(date '+%d%m%Y_%H%M%S')
logFileName="dpxcc_setup_algorithms_$logFileDate.log"
PROXY_BYPASS=true
SECURE_CONN=false


show_help() {
    echo "Usage: dpxcc_setup_algorithms.sh [options]"
    echo "Options:"
    echo "  --algorithms-file   -a  File containing Algorithms            - Default: algorithms.csv"
    echo "  --ignore-errors     -i  Ignore errors while adding Algorithms - Default: false"
    echo "  --log-file          -o  Log file name                         - Default: Current date_time.log"
    echo "  --proxy-bypass      -x  Proxy ByPass                          - Default: true"
    echo "  --http-secure       -k  (http/https)                          - Default: false"
    echo "  --masking-engine    -m  Masking Engine Address                - Required value"
    echo "  --masking-username  -u  Masking Engine User Name              - Required value"
    echo "  --masking-pwd       -p  Masking Engine Password               - Required value"
    echo "  --help              -h  Show this help"
    echo "Example:"
    echo "dpxcc_setup_algorithms.sh -m <MASKING IP> -u <MASKING User> -p <MASKING Password>"
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

upload_files() {
    local FILE_NAME="$1"
    local FILE_TYPE="$2"

    local FUNC='upload_files'
    local URL_BASE="$MASKING_ENGINE/masking/api/$apiVer"
    local API='file-uploads?permanent=false'
    local METHOD="POST"
    local AUTH="$AUTH_HEADER"
    local CONTENT_TYPE="multipart/form-data"
    local FORM="file=@$FILE_NAME;type=$FILE_TYPE"
    local DATA=""

    log "Uploading file $FILE_NAME ...\n"
    build_curl "$URL_BASE" "$API" "$METHOD" "$AUTH" "$CONTENT_TYPE" "$KEEPALIVE" "$PROXY_BYPASS" "$SECURE_CONN" "$FORM" "$DATA"
    local FILE_UPLOAD_RESPONSE
    FILE_UPLOAD_RESPONSE=$(eval "$curl_command")

    check_error "$FUNC" "$API" "$FILE_UPLOAD_RESPONSE" "$IGN_ERROR"
    local FILE_UPLOAD_VALUE
    FILE_UPLOAD_VALUE=$(echo "$FILE_UPLOAD_RESPONSE" | jq -r '.filename')
    check_response "$FILE_UPLOAD_VALUE" "$IGN_ERROR"

    fileReferenceId=""
    fileReferenceId=$(echo "$FILE_UPLOAD_RESPONSE" | jq -r '.fileReferenceId')

    if [ -n "$fileReferenceId" ]; then
        log "File: $FILE_UPLOAD_VALUE uploaded - ID: $fileReferenceId\n"
    else
        log "File NOT uploaded\n"
    fi
}

add_algorithm() {
    local algorithmName="$1"
    local algorithmType="$2"
    local description="$3"
    local frameworkId="$4"
    local pluginId="$5"
    local ExtensionJson="$6"
    local newUri="$7"

    local FUNC='add_algorithm'
    local URL_BASE="$MASKING_ENGINE/masking/api/v5.1.22"
    local API='algorithms'
    local METHOD="POST"
    local AUTH="$AUTH_HEADER"
    local CONTENT_TYPE="application/json"
    local FORM=""

    local algorithmExtension

    if [ -n "$newUri" ]; then
        algorithmExtension=$(echo "$ExtensionJson" | jq --arg newUri "$newUri" '.lookupFile.uri = $newUri')
    else
        algorithmExtension="$ExtensionJson"
    fi

    local FullJson
    FullJson="{\"algorithmName\": \"$algorithmName\", \"algorithmType\": \"$algorithmType\", \"description\": \"$description\",\
               \"frameworkId\": \"$frameworkId\", \"pluginId\": \"$pluginId\", \"algorithmExtension\": $algorithmExtension}"
    local DATA
    DATA=$(echo "$FullJson" | jq -c)

    log "Adding Algorithm $algorithmName using FrameworkId: $frameworkId PluginId: $pluginId ...\n"
    build_curl "$URL_BASE" "$API" "$METHOD" "$AUTH" "$CONTENT_TYPE" "$KEEPALIVE" "$PROXY_BYPASS" "$SECURE_CONN" "$FORM" "$DATA"
    local ADD_ALGO_RESPONSE
    ADD_ALGO_RESPONSE=$(eval "$curl_command")

    check_error "$FUNC" "$API" "$ADD_ALGO_RESPONSE" "$IGN_ERROR"
    local ADD_ALGO_VALUE
    ADD_ALGO_VALUE=$(echo "$ADD_ALGO_RESPONSE" | jq -r '.reference')
    check_response "$ADD_ALGO_VALUE" "$IGN_ERROR"

    if [ ! "$ADD_ALGO_VALUE" == "null" ]; then
        log "Algorithm: $ADD_ALGO_VALUE added.\n"
    else
        log "Algorithm NOT added.\n"
    fi
}

get_frameworks() {
    local page_number="1"
    local page_size="256"
    local include_schema="true"
    local FUNC='get_frameworks'
    local URL_BASE="$MASKING_ENGINE/masking/api/v5.1.22"
    local API='algorithm/frameworks'
    local METHOD="GET"
    local AUTH="$AUTH_HEADER"
    local CONTENT_TYPE="application/json"
    local FORM=""
    local DATA="{\"include_schema\": $include_schema, \"page_number\": $page_number, \"page_size\": $page_size}"

    log "Getting frameworks...\n"
    build_curl "$URL_BASE" "$API" "$METHOD" "$AUTH" "$CONTENT_TYPE" "$KEEPALIVE" "$PROXY_BYPASS" "$SECURE_CONN" "$FORM" "$DATA"
    local GET_FRAMEWORK_RESPONSE
    GET_FRAMEWORK_RESPONSE=$(eval "$curl_command")

    check_error "$FUNC" "$API" "$GET_FRAMEWORK_RESPONSE" "$IGN_ERROR"
    GET_FRAMEWORK_VALUE=$(echo "$GET_FRAMEWORK_RESPONSE" | jq -r '.responseList')
    check_response "$GET_FRAMEWORK_VALUE" "$IGN_ERROR"
    log "Got frameworks...\n"
}

get_framework_ID() {
    local searchFramework="$1"
    local jsonResponse="$2"
    local parsedJson
    parsedJson=$(echo "$jsonResponse" | jq --arg search "$searchFramework" 'map(select(.frameworkName == $search)) | .[0]')
    frameworkId=$(echo "$parsedJson" | jq -r '.frameworkId')
    pluginId=$(echo "$parsedJson" | jq -r '.plugin.pluginId')
}


check_packages

# Parameters
[ "$1" ] || { show_help; }

args=""
for arg
do
    delim=""
    case "$arg" in
        --algorithm-file)
            args="${args}-a "
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

while getopts ":h:a:i:o:x:k:m:u:p:" PARAMETERS; do
    case $PARAMETERS in
        h)
        	;;
        a)
        	ALGO_FILE=${OPTARG[*]}
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

check_file "$ALGO_FILE" "$IGN_ERROR"

dpxlogin "$MASKING_USERNAME" "$MASKING_PASSWORD"

get_frameworks

while IFS=\; read -r algorithmName algorithmType description frameworkName fileName fileType algorithmExtension
do
    if [[ ! "$algorithmName" =~ "#" ]];
    then
        get_framework_ID "$frameworkName" "$GET_FRAMEWORK_VALUE" "$frameworkId" "$pluginId"
        ReferenceId=""
        if [ -n "$fileName" ]; then
            upload_files "$fileName" "$fileType"
            ReferenceId="$fileReferenceId"
        fi
        add_algorithm "$algorithmName" "$algorithmType" "$description" "$frameworkId" "$pluginId" "$algorithmExtension" "$ReferenceId"
    fi
done < "$ALGO_FILE"

dpxlogout
