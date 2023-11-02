#!/usr/bin/bash


MASKING_ENGINE=""
MASKING_USERNAME=""
MASKING_PASSWORD=""
URL_BASE=""
ALGO_FILE=""
IGN_ERROR="false"
KEEPALIVE=300
logFileDate="`date '+%d%m%Y_%H%M%S'`"
logFileName="dpxcc_setup_algorithms_$logFileDate.log"
PROXY_BYPASS=true
SECURE_CONN=false


show_help() {
    echo "Usage: dpxcc_setup_algorithms.sh [options]"
    echo "Options:"
    echo "  --algorithms-file   -a  File containing Algorithms            - Required value"
    echo "  --ignore-errors     -i  Ignore errors while adding Algorithms - Default Value: false"
    echo "  --log-file          -o  Log file name                         - Default Value: Current date_time.log"
    echo "  --proxy-bypass      -x  Proxy ByPass                          - Default Value: true"
    echo "  --http-secure       -k  (http/https)                          - Default Value: false"
    echo "  --masking-engine    -m  Masking Engine Address                - Required value"
    echo "  --masking-username  -u  Masking Engine User Name              - Required value"
    echo "  --masking-pwd       -p  Masking Engine Password               - Required value"
    echo "  --help              -h  Show this help"
    echo "Example:"
    echo "dpxcc_setup_algorithms.sh -a algorithms.csv -i false -m <MASKING IP> -u <MASKING User> -p <MASKING Password>"
    exit 1
}

# Print the message and exit the program.
die() {
    echo "*******************************************************************************"
    echo "$(basename $0) ERROR: $*" >&2
    echo "*******************************************************************************"
    exit 1
}

log (){
    local logMsg="$1"
    local logMsgDate="[`date '+%d%m%Y %T'`]"
    echo -ne "$logMsgDate $logMsg" | tee -a "$logFileName"
}

add_parms() {
    ALLPARMS="$ALLPARMS""$1"
}

check_parm() {
    local PARMS="$1"

    local KEY="a"
    if [[ ! "$PARMS" == *"$KEY"* ]]; then
        echo "Option -a is missing. Algorithms file is required."
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
    local JQ="$(which jq)"
    local CURL="$(which curl)"

    [ -x "${JQ}" ] || { echo "jq not found. Please install 'jq' package and try again." ; exit 1 ; }
    [ -x "${CURL}" ] || { echo "curl not found. Please install 'curl' package and try again." ; exit 1 ; }
}

check_conn() {
    local MASKING_IP="$1"
    local PROXY_BYPASS="$2"
    local SECURE_CONN="$3"

    local curl_command="curl -s -v -m 5"

    if [ "$SECURE_CONN" = true ]; then
        local URL="https://$MASKING_IP"
    else
        local URL="http://$MASKING_IP"
    fi

    if [ "$PROXY_BYPASS" = true ]; then
        curl_command="$curl_command -x \"\""
    fi

    local curl_command="$curl_command -o /dev/null $URL 2>&1"
    local curlResponse=$(eval "$curl_command")

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
        curl_command="$curl_command -x \"\""
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

# Login and set the correct $AUTH_HEADER.
dpxlogin() {
    local USERNAME="$1"
    local PASSWORD="$2"

    local FUNC='dpxlogin'
    local URL_BASE="$MASKING_ENGINE/masking/api/v5.1.22"
    local API='login'
    local METHOD="POST"
    local AUTH=""
    local CONTENT_TYPE="application/json"
    local FORM=""

    local DATA="{\"username\": \"$USERNAME\", \"password\": \"$PASSWORD\"}"

    log "Logging in with $USERNAME ...\n"
    build_curl "$URL_BASE" "$API" "$METHOD" "$AUTH" "$CONTENT_TYPE" "$KEEPALIVE" "$PROXY_BYPASS" "$SECURE_CONN" "$FORM" "$DATA"
    local LOGIN_RESPONSE=$(eval "$curl_command") || die "Login failed with exit code $?"
    check_error "$FUNC" "$API" "$LOGIN_RESPONSE"
    TOKEN=$(echo $LOGIN_RESPONSE | jq -r '.Authorization')
    AUTH_HEADER="Authorization: $TOKEN"
    log "$MASKING_USERNAME logged in successfully\n"
}

# Logout
dpxlogout() {
    local FUNC='dpxlogout'
    local URL_BASE="$MASKING_ENGINE/masking/api/v5.1.22"
    local API='logout'
    local METHOD="PUT"
    local AUTH="$AUTH_HEADER"
    local CONTENT_TYPE="application/json"
    local FORM=""
    local DATA=""

    log "Logging out ...\n"
    build_curl "$URL_BASE" "$API" "$METHOD" "$AUTH" "$CONTENT_TYPE" "$KEEPALIVE" "$PROXY_BYPASS" "$SECURE_CONN" "$FORM" "$DATA"
    local LOGOUT_RESPONSE=$(eval "$curl_command")
    log "$MASKING_USERNAME Logged out successfully\n"
}

upload_files() {
    local FILE_NAME="$1"
    local FILE_TYPE="$2"

    local FUNC='upload_files'
    local URL_BASE="$MASKING_ENGINE/masking/api/v5.1.22"
    local API='file-uploads?permanent=false'
    local METHOD="POST"
    local AUTH="$AUTH_HEADER"
    local CONTENT_TYPE="multipart/form-data"
    local FORM="file=@$FILE_NAME;type=$FILE_TYPE"
    local DATA=""

    log "Uploading file $FILE_NAME ...\n"
    build_curl "$URL_BASE" "$API" "$METHOD" "$AUTH" "$CONTENT_TYPE" "$KEEPALIVE" "$PROXY_BYPASS" "$SECURE_CONN" "$FORM" "$DATA"
    local FILE_UPLOADS_RESPONSE=$(eval "$curl_command")

    check_error "$FUNC" "$API" "$FILE_UPLOADS_RESPONSE" "$IGN_ERROR"
    FILE_UPLOADS_VALUE=$(echo "$FILE_UPLOADS_RESPONSE" | jq -r '.filename')
    check_response "$FILE_UPLOADS_VALUE" "$IGN_ERROR"
    fileReferenceId=$(echo "$FILE_UPLOADS_RESPONSE" | jq -r '.fileReferenceId')
    log "File: $FILE_UPLOADS_VALUE uploaded - ID: $fileReferenceId\n"
}

add_sl_algorithms() {
    local algorithmName="$1"
    local algorithmType="$2"
    local description="$3"
    local frameworkId="$4"
    local pluginId="$5"
    local hashMethod="$6"
    local maskedValueCase="$7"
    local inputCaseSensitive="$8"
    local trimWhitespaceFromInput="${9}"
    local trimWhitespaceInLookupFile="${10}"
    local uri="${11}"

    local FUNC='add_sl_algorithms'
    local URL_BASE="$MASKING_ENGINE/masking/api/v5.1.22"
    local API='algorithms'
    local METHOD="POST"
    local AUTH="$AUTH_HEADER"
    local CONTENT_TYPE="application/json"
    local FORM=""

    local lookupFile="{\"uri\": \"$uri\"}"
    local algorithmExtension="{\"hashMethod\": \"$hashMethod\", \"lookupFile\": $lookupFile}"
    local DATA="{\"algorithmName\": \"$algorithmName\", \"algorithmType\": \"$algorithmType\", \"description\": \"$description\",\
                 \"frameworkId\": \"$frameworkId\", \"pluginId\": \"$pluginId\", \"algorithmExtension\": $algorithmExtension,\
                 \"maskedValueCase\": \"$maskedValueCase\", \"inputCaseSensitive\": \"$inputCaseSensitive\",\
                 \"trimWhitespaceFromInput\": \"$trimWhitespaceFromInput\", \"trimWhitespaceInLookupFile\": \"$trimWhitespaceInLookupFile\"}"
    local DATA="$(echo "$DATA" | sed -e 's/  */ /g')"

    log "Adding Algorithm $algorithmName using Secure Lookup Framework - FrameworkId: $frameworkId PluginId: $pluginId ...\n"
    build_curl "$URL_BASE" "$API" "$METHOD" "$AUTH" "$CONTENT_TYPE" "$KEEPALIVE" "$PROXY_BYPASS" "$SECURE_CONN" "$FORM" "$DATA"
    local ADD_ALGO_RESPONSE=$(eval "$curl_command")

    check_error "$FUNC" "$API" "$ADD_ALGO_RESPONSE" "$IGN_ERROR"
    ADD_ALGO_VALUE=$(echo "$ADD_ALGO_RESPONSE" | jq -r '.reference')
    check_response "$ADD_ALGO_VALUE" "$IGN_ERROR"
    log "Algorithm: $ADD_ALGO_VALUE added.\n"
}

add_nm_algorithms() {
    local algorithmName="$1"
    local algorithmType="$2"
    local description="$3"
    local frameworkId="$4"
    local pluginId="$5"
    local maskedValueCase="$6"
    local inputCaseSensitive="$7"
    local filterAccent="${8}"
    local maxLengthOfMaskedName="${9}"
    local uri="${10}"

    local FUNC='add_nm_algorithms'
    local URL_BASE="$MASKING_ENGINE/masking/api/v5.1.22"
    local API='algorithms'
    local METHOD="POST"
    local AUTH="$AUTH_HEADER"
    local CONTENT_TYPE="application/json"
    local FORM=""

    local lookupFile="{\"uri\": \"$uri\"}"
    local algorithmExtension="{\"lookupFile\": $lookupFile}"
    local DATA="{\"algorithmName\": \"$algorithmName\", \"algorithmType\": \"$algorithmType\", \"description\": \"$description\",\
                 \"frameworkId\": \"$frameworkId\", \"pluginId\": \"$pluginId\", \"algorithmExtension\": $algorithmExtension,\
                 \"maskedValueCase\": \"$maskedValueCase\", \"filterAccent\": \"$filterAccent\", \"inputCaseSensitive\": \"$inputCaseSensitive\",\
                 \"maxLengthOfMaskedName\": \"$maxLengthOfMaskedName\"}"
    local DATA="$(echo "$DATA" | sed -e 's/  */ /g')"

    log "Adding Algorithm $algorithmName using Name Framework - FrameworkId: $frameworkId PluginId: $pluginId ...\n"
    build_curl "$URL_BASE" "$API" "$METHOD" "$AUTH" "$CONTENT_TYPE" "$KEEPALIVE" "$PROXY_BYPASS" "$SECURE_CONN" "$FORM" "$DATA"
    local ADD_ALGO_RESPONSE=$(eval "$curl_command")

    check_error "$FUNC" "$API" "$ADD_ALGO_RESPONSE" "$IGN_ERROR"
    ADD_ALGO_VALUE=$(echo "$ADD_ALGO_RESPONSE" | jq -r '.reference')
    check_response "$ADD_ALGO_VALUE" "$IGN_ERROR"
    log "Algorithm: $ADD_ALGO_VALUE added.\n"
}

add_nmfull_algorithms() {
    local algorithmName="$1"
    local algorithmType="$2"
    local description="$3"
    local frameworkId="$4"
    local pluginId="$5"
    local lastNameAtTheEnd="${6}"
    local lastNameSeparators="${7}"
    local maxNumberFirstNames="${8}"
    local lastNameAlgorithmRef="${9}"
    local firstNameAlgorithmRef="${10}"
    local maxLengthOfMaskedName="${11}"
    local ifSingleWordConsiderAsLastName="${12}"
    local uri="${13}"

    local FUNC='add_nmfull_algorithms'
    local URL_BASE="$MASKING_ENGINE/masking/api/v5.1.22"
    local API='algorithms'
    local METHOD="POST"
    local AUTH="$AUTH_HEADER"
    local CONTENT_TYPE="application/json"
    local FORM=""

    local lastNameAlgRef="{\"name\": \"$lastNameAlgorithmRef\"}"
    local firstNameAlgRef="{\"name\": \"$firstNameAlgorithmRef\"}"
    local algorithmExtension="{\"lastNameAtTheEnd\": $lastNameAtTheEnd, \"lastNameSeparators\": [$lastNameSeparators], \"maxNumberFirstNames\": $maxNumberFirstNames,\
                         \"lastNameAlgorithmRef\": $lastNameAlgRef, \"firstNameAlgorithmRef\": $firstNameAlgRef}"
    local DATA="{\"algorithmName\": \"$algorithmName\", \"algorithmType\": \"$algorithmType\", \"description\": \"$description\",\
               \"frameworkId\": $frameworkId, \"pluginId\": $pluginId, \"algorithmExtension\": $algorithmExtension,\
               \"maxLengthOfMaskedName\": $maxLengthOfMaskedName, \"ifSingleWordConsiderAsLastName\": $ifSingleWordConsiderAsLastName}"
    local DATA="$(echo "$DATA" | sed -e 's/  */ /g')"

    log "Adding Algorithm $algorithmName using Full Name Framework - FrameworkId: $frameworkId PluginId: $pluginId ...\n"
    build_curl "$URL_BASE" "$API" "$METHOD" "$AUTH" "$CONTENT_TYPE" "$KEEPALIVE" "$PROXY_BYPASS" "$SECURE_CONN" "$FORM" "$DATA"
    local ADD_ALGO_RESPONSE=$(eval "$curl_command")

    check_error "$FUNC" "$API" "$ADD_ALGO_RESPONSE" "$IGN_ERROR"
    ADD_ALGO_VALUE=$(echo "$ADD_ALGO_RESPONSE" | jq -r '.reference')
    check_response "$ADD_ALGO_VALUE" "$IGN_ERROR"
    log "Algorithm: $ADD_ALGO_VALUE added.\n"
}

add_pc_algorithms() {
    local algorithmName="$1"
    local algorithmType="$2"
    local description="$3"
    local frameworkId="$4"
    local pluginId="$5"
    local preserve="$6"
    local minMaskedPositions="$7"

    local FUNC='add_pc_algorithms'
    local URL_BASE="$MASKING_ENGINE/masking/api/v5.1.22"
    local API='algorithms'
    local METHOD="POST"
    local AUTH="$AUTH_HEADER"
    local CONTENT_TYPE="application/json"
    local FORM=""

    local algorithmExtension="{\"preserve\": \"$preserve\", \"minMaskedPositions\": $minMaskedPositions}"
    local DATA="{\"algorithmName\": \"$algorithmName\", \"algorithmType\": \"$algorithmType\", \"description\": \"$description\",\
                 \"frameworkId\": \"$frameworkId\", \"pluginId\": \"$pluginId\", \"algorithmExtension\": $algorithmExtension}"
    local DATA="$(echo "$DATA" | sed -e 's/  */ /g')"

    log "Adding Algorithm $algorithmName using PaymentCard Framework - FrameworkId: $frameworkId PluginId: $pluginId ...\n"
    build_curl "$URL_BASE" "$API" "$METHOD" "$AUTH" "$CONTENT_TYPE" "$KEEPALIVE" "$PROXY_BYPASS" "$SECURE_CONN" "$FORM" "$DATA"
    local ADD_ALGO_RESPONSE=$(eval "$curl_command")

    check_error "$FUNC" "$API" "$ADD_ALGO_RESPONSE" "$IGN_ERROR"
    ADD_ALGO_VALUE=$(echo "$ADD_ALGO_RESPONSE" | jq -r '.reference')
    check_response "$ADD_ALGO_VALUE" "$IGN_ERROR"
    log "Algorithm: $ADD_ALGO_VALUE added.\n"
}

add_cm_algorithms() {
    local algorithmName="$1"
    local algorithmType="$2"
    local description="$3"
    local frameworkId="$4"
    local pluginId="$5"
    local caseSensitive="${6}"
    local start="${7}"
    local length="${8}"
    local direction="${9}"
    local characterGroups="${10}"
    local minMaskedPositions="${11}"
    local preserveLeadingZeros="${12}"

    local FUNC='add_cm_algorithms'
    local URL_BASE="$MASKING_ENGINE/masking/api/v5.1.22"
    local API='algorithms'
    local METHOD="POST"
    local AUTH="$AUTH_HEADER"
    local CONTENT_TYPE="application/json"
    local FORM=""

    local algorithmExtension="{\"caseSensitive\":$caseSensitive,\"preserveRanges\":[$preserveRanges],\
                               \"characterGroups\":[\"$characterGroups\"],\"minMaskedPositions\":$minMaskedPositions,\
                               \"preserveLeadingZeros\":$preserveLeadingZeros}"
    local DATA="{\"algorithmName\":\"$algorithmName\",\"algorithmType\":\"$algorithmType\",\"description\":\"$description\",\
                 \"frameworkId\":$frameworkId,\"pluginId\":$pluginId,\"algorithmExtension\":$algorithmExtension}"
    local DATA="$(echo "$DATA" | sed -e 's/  */ /g')"

    log "Adding Algorithm $algorithmName using Character Mapping Framework - FrameworkId: $frameworkId PluginId: $pluginId ...\n"
    build_curl "$URL_BASE" "$API" "$METHOD" "$AUTH" "$CONTENT_TYPE" "$KEEPALIVE" "$PROXY_BYPASS" "$SECURE_CONN" "$FORM" "$DATA"
    local ADD_ALGO_RESPONSE=$(eval "$curl_command")

    check_error "$FUNC" "$API" "$ADD_ALGO_RESPONSE" "$IGN_ERROR"
    ADD_ALGO_VALUE=$(echo "$ADD_ALGO_RESPONSE" | jq -r '.reference')
    check_response "$ADD_ALGO_VALUE" "$IGN_ERROR"
    log "Algorithm: $ADD_ALGO_VALUE added.\n"
}

add_em_algorithms() {
    local algorithmName="$1"
    local algorithmType="$2"
    local description="$3"
    local frameworkId="$4"
    local pluginId="$5"
    local nameAction="${6}"
    local domainAction="${7}"
    local nameAlgorithm="${8}"
    local nameLookupFile="${9}"
    local domainAlgorithm="${10}"
    local domainReplacementString="${11}"

    local FUNC='add_em_algorithms'
    local URL_BASE="$MASKING_ENGINE/masking/api/v5.1.22"
    local API='algorithms'
    local METHOD="POST"
    local AUTH="$AUTH_HEADER"
    local CONTENT_TYPE="application/json"
    local FORM=""

    local nameAlgo="{\"name\": \"$nameAlgorithm\"}"
    local domainAlgo="{\"name\": \"$domainAlgorithm\"}"
    local algorithmExtension="{\"nameAction\": \"$nameAction\", \"domainAction\": \"$domainAction\", \"nameAlgorithm\": $nameAlgo,\
                               \"nameLookupFile\": $nameLookupFile, \"domainAlgorithm\": $domainAlgo,\
                               \"domainReplacementString\": $domainReplacementString}"
    local DATA="{\"algorithmName\": \"$algorithmName\", \"algorithmType\": \"$algorithmType\", \"description\": \"$description\",\
           \"frameworkId\": $frameworkId, \"pluginId\": $pluginId, \"algorithmExtension\": $algorithmExtension}"
    local DATA="$(echo "$DATA" | sed -e 's/  */ /g')"

    log "Adding Algorithm $algorithmName using Email Framework - FrameworkId: $frameworkId PluginId: $pluginId ...\n"
    build_curl "$URL_BASE" "$API" "$METHOD" "$AUTH" "$CONTENT_TYPE" "$KEEPALIVE" "$PROXY_BYPASS" "$SECURE_CONN" "$FORM" "$DATA"
    local ADD_ALGO_RESPONSE=$(eval "$curl_command")

    check_error "$FUNC" "$API" "$ADD_ALGO_RESPONSE" "$IGN_ERROR"
    ADD_ALGO_VALUE=$(echo "$ADD_ALGO_RESPONSE" | jq -r '.reference')
    check_response "$ADD_ALGO_VALUE" "$IGN_ERROR"
    log "Algorithm: $ADD_ALGO_VALUE added.\n"
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
    local GET_FRAMEWORK_RESPONSE=$(eval "$curl_command")

    check_error "$FUNC" "$API" "$GET_FRAMEWORK_RESPONSE" "$IGN_ERROR"
    GET_FRAMEWORK_VALUE=$(echo "$GET_FRAMEWORK_RESPONSE" | jq -r '.responseList')
    check_response "$GET_FRAMEWORK_VALUE" "$IGN_ERROR"
    log "Got frameworks...\n"
}

get_framework_ID() {
    local searchFramework="$1"
    local jsonResponse="$2"
    local parsedJson=$(echo "$jsonResponse" | jq --arg search "$searchFramework" 'map(select(.frameworkName == $search)) | .[0]')
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

eval set -- $args

while getopts ":h:a:i:o:x:k:m:u:p:" PARAMETERS; do
    case $PARAMETERS in
        h)
        	;;
        a)
        	ALGO_FILE=${OPTARG[@]}
        	add_parms "$PARAMETERS";
        	;;
        i)
        	IGN_ERROR=${OPTARG[@]}
        	add_parms "$PARAMETERS";
        	;;
        o)
        	logFileName=${OPTARG[@]}
        	add_parms "$PARAMETERS";
        	;;
        x)
        	PROXY_BYPASS=${OPTARG[@]}
        	add_parms "$PARAMETERS";
        	;;
        k)
        	SECURE_CONN=${OPTARG[@]}
        	add_parms "$PARAMETERS";
        	;;
        m)
        	MASKING_ENGINE=${OPTARG[@]}
        	add_parms "$PARAMETERS";
        	;;
        u)
        	MASKING_USERNAME=${OPTARG[@]}
        	add_parms "$PARAMETERS";
        	;;
        p)
        	MASKING_PASSWORD=${OPTARG[@]}
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
dpxlogout

if [[ "$ALGO_FILE" == *"sl_"* ]];
then
    frameworkName="Secure Lookup"
    get_framework_ID "$frameworkName" "$GET_FRAMEWORK_VALUE"

    dpxlogin "$MASKING_USERNAME" "$MASKING_PASSWORD"
    while IFS=\; read -r algorithmName algorithmType description hashMethod maskedValueCase inputCaseSensitive\
                         trimWhitespaceFromInput trimWhitespaceInLookupFile fileName fileType
    do
        if [[ ! "$algorithmName" =~ "#" ]];
        then
            upload_files "$fileName" "$fileType"
            add_sl_algorithms "$algorithmName" "$algorithmType" "$description" "$frameworkId" "$pluginId" "$hashMethod" "$maskedValueCase" "$inputCaseSensitive"\
                              "$trimWhitespaceFromInput" "$trimWhitespaceInLookupFile" "$fileReferenceId"
        fi
    done < "$ALGO_FILE"
    dpxlogout
fi

if [[ "$ALGO_FILE" == *"nm_"* ]];
then
    frameworkName="Name"
    get_framework_ID "$frameworkName" "$GET_FRAMEWORK_VALUE"

    dpxlogin "$MASKING_USERNAME" "$MASKING_PASSWORD"
    while IFS=\; read -r algorithmName algorithmType description maskedValueCase inputCaseSensitive filterAccent maxLengthOfMaskedName fileName fileType
    do
        if [[ ! "$algorithmName" =~ "#" ]];
        then
            upload_files "$fileName" "$fileType"
            add_nm_algorithms "$algorithmName" "$algorithmType" "$description" "$frameworkId" "$pluginId" "$maskedValueCase" "$inputCaseSensitive"\
                              "$filterAccent" "$maxLengthOfMaskedName" "$fileReferenceId"
        fi
    done < "$ALGO_FILE"
    dpxlogout
fi

if [[ "$ALGO_FILE" == *"fn_"* ]];
then
    frameworkName="FullName"
    get_framework_ID "$frameworkName" "$GET_FRAMEWORK_VALUE"

    dpxlogin "$MASKING_USERNAME" "$MASKING_PASSWORD"
    while IFS=\; read -r algorithmName algorithmType description lastNameAtTheEnd \
                         lastNameSeparators maxNumberFirstNames lastNameAlgorithmRef firstNameAlgorithmRef maxLengthOfMaskedName\
                         ifSingleWordConsiderAsLastName FileName FileType
    do
        if [[ ! "$algorithmName" =~ "#" ]];
        then
            add_nmfull_algorithms "$algorithmName" "$algorithmType" "$description" "$frameworkId" "$pluginId" "$lastNameAtTheEnd"\
                                  "$lastNameSeparators" "$maxNumberFirstNames" "$lastNameAlgorithmRef" "$firstNameAlgorithmRef" "$maxLengthOfMaskedName"\
                                  "$ifSingleWordConsiderAsLastName" "$lastNameAtTheEnd" "$fileReferenceId"
        fi
    done < "$ALGO_FILE"
    dpxlogout
fi

if [[ "$ALGO_FILE" == *"pc_"* ]];
then
    frameworkName="Payment Card"
    get_framework_ID "$frameworkName" "$GET_FRAMEWORK_VALUE"

    dpxlogin "$MASKING_USERNAME" "$MASKING_PASSWORD"
    while IFS=\; read -r algorithmName algorithmType description preserve minMaskedPositions
    do
        if [[ ! "$algorithmName" =~ "#" ]];
        then
            add_pc_algorithms "$algorithmName" "$algorithmType" "$description" "$frameworkId" "$pluginId" "$preserve" "$minMaskedPositions"
        fi
    done < "$ALGO_FILE"
    dpxlogout
fi

if [[ "$ALGO_FILE" == *"cm_"* ]];
then
    frameworkName="Character Mapping"
    get_framework_ID "$frameworkName" "$GET_FRAMEWORK_VALUE"

    dpxlogin "$MASKING_USERNAME" "$MASKING_PASSWORD"
    while IFS=\; read -r algorithmName algorithmType description caseSensitive \
                         start length direction characterGroups minMaskedPositions preserveLeadingZeros
    do
        if [[ ! "$algorithmName" =~ "#" ]];
        then
            add_cm_algorithms "$algorithmName" "$algorithmType" "$description" "$frameworkId" "$pluginId" "$caseSensitive"\
                              "$start" "$length" "$direction" "$characterGroups" "$minMaskedPositions" "$preserveLeadingZeros"
        fi
    done < "$ALGO_FILE"
    dpxlogout
fi

if [[ "$ALGO_FILE" == *"em_"* ]];
then
    frameworkName="Email"
    get_framework_ID "$frameworkName" "$GET_FRAMEWORK_VALUE"

    dpxlogin "$MASKING_USERNAME" "$MASKING_PASSWORD"
    while IFS=\; read -r algorithmName algorithmType description nameAction \
                         domainAction nameAlgorithm nameLookupFile domainAlgorithm domainReplacementString
    do
        if [[ ! "$algorithmName" =~ "#" ]];
        then
            add_em_algorithms "$algorithmName" "$algorithmType" "$description" "$frameworkId" "$pluginId" "$nameAction"\
                              "$domainAction" "$nameAlgorithm" "$nameLookupFile" "$domainAlgorithm" "$domainReplacementString"
        fi
    done < "$ALGO_FILE"
    dpxlogout
fi
