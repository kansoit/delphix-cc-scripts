#!/usr/bin/bash


MASKING_ENGINE=""
MASKING_USERNAME=""
MASKING_PASSWORD=""
URL_BASE=""
IGN_ERROR='false'
KEEPALIVE=300
logFileDate="`date '+%d%m%Y_%H%M%S'`"
logFileName="dpxcc_get_algorithms_$logFileDate.log"


show_help() {
    echo "Usage: dpxcc_get_algorithms.sh [options]"
    echo "Options:"
    echo "  --log-file          -o  Log file name            - Default Value: Current date_time.log"
    echo "  --masking-engine    -m  Masking Engine Address   - Required value"
    echo "  --masking-username  -u  Masking Engine User Name - Required value"
    echo "  --masking-pwd       -p  Masking Engine Password  - Required value"
    echo "  --help              -h  Show this help"
    echo "Example:"
    echo "dpxcc_get_algorithms.sh -m <MASKING IP> -u <MASKING User> -p <MASKING Password>"
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
    curl_timeout=$(curl -s -v -m 5 -x "" -o /dev/null http://"$MASKING_ENGINE" 2>&1 | grep "timed out")
    if [[ "$curl_timeout" == *"timed out"* ]];
    then
       log "Error: $curl_timeout\n"
       log "Please verify if the Masking IP Address $MASKING_ENGINE is correct.\n"
       log "Execute curl -s -v -m 5 -o /dev/null http://$MASKING_ENGINE and check the output to verify communications issues between this machine and the Masking Engine.\n"
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

# Login and set the correct $AUTH_HEADER.
dpxlogin() {
    local USERNAME="$1"
    local PASSWORD="$2"
    local FUNC='dpxlogin'
    local API='login'
    local DATA="{\"username\": \"$USERNAME\", \"password\": \"$PASSWORD\"}"
    LOGIN_RESPONSE=$(curl -X POST -H 'Content-Type: application/json' -H 'Accept: application/json' -x "" --keepalive-time "$KEEPALIVE" --data "$DATA" -s "$URL_BASE/$API"
    ) || die "Login failed with exit code $?"
    check_error "$FUNC" "$API" "$LOGIN_RESPONSE"
    TOKEN=$(echo $LOGIN_RESPONSE | jq -r '.Authorization')
    AUTH_HEADER="Authorization: $TOKEN"
    log "$MASKING_USERNAME logged in successfully\n"
}

# Logout
dpxlogout() {
    local FUNC='dpxlogout'
    local API='logout'
    LOGOUT_RESPONSE=$(curl -X PUT -H ''"$AUTH_HEADER"'' -H 'Content-Type: application/json' -x "" --keepalive-time "$KEEPALIVE" -s "$URL_BASE/$API")
    log "$MASKING_USERNAME Logged out successfully\n"
}

get_algorithms() {
    local mask_type="STRING"
    local page_number="1"
    local page_size="256"
    local FUNC='get_algorithms'
    local API='algorithms'
    # local DATA="{\"mask_type\": \"$mask_type\", \"page_number\": $page_number, \"page_size\": $page_size}"
    local DATA="{\"page_number\": $page_number, \"page_size\": $page_size}"

    local GET_ALGO_RESPONSE=$(curl -X GET -H ''"$AUTH_HEADER"'' -H 'Content-Type: application/json' -x "" --keepalive-time "$KEEPALIVE" --data "$DATA" -s "$URL_BASE/$API")
    check_error "$FUNC" "$API" "$GET_ALGO_RESPONSE" "$IGN_ERROR"
    GET_ALGO_VALUE=$(echo "$GET_ALGO_RESPONSE" | jq -r '.responseList')
    check_response "$GET_ALGO_VALUE" "$IGN_ERROR"
    log "$GET_ALGO_VALUE\n"
}

check_packages

# Parameters
[ "$1" ] || { show_help; }

args=""
for arg
do
    delim=""
    case "$arg" in
        --log-file)
            args="${args}-o "
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

while getopts ":h:o:m:u:p:" PARAMETERS; do
    case $PARAMETERS in
        h)
        	;;
        o)
        	logFileName=${OPTARG[@]}
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

# Update URL
URL_BASE="http://${MASKING_ENGINE}/masking/api/v5.1.22"

# Check connection
check_conn

dpxlogin "$MASKING_USERNAME" "$MASKING_PASSWORD"
log "Getting algorithms...\n"
get_algorithms
dpxlogout
