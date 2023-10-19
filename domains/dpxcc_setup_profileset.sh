#!/bin/bash


MASKING_ENGINE=""
MASKING_USERNAME=""
MASKING_PASSWORD=""
URL_BASE=""
PROFILE_NAME=""
EXPRESS_FILE='expressions.csv'
DOMAINS_FILE='domains.csv'
KEEPALIVE=300
LOG_FILE='dpxcc_setup_profileset.log'
EXPRESSID_LIST="7,8,11,22,23,49,50"
# Extra Expression Ids
# 7 - Creditcard
# 8 - Creditcard
# 11 - Email
# 22 - Creditcard Data
# 23 - Email Data
# 49 - Ip Address Data
# 50 - Ip Address


show_help() {
    echo "Usage: dpxcc_setup_profileset.sh [options]"
    echo "Options:"
    echo "  --profile-name      -f  Profile Name - Required value"
    echo "  --expressions-file  -e  File containing Expressions - Default: expressions.csv"
    echo "  --domains-file      -d  File containing Domains - Default: domains.csv"
    echo "  --masking-engine    -m  Masking Engine Address - Required value"
    echo "  --masking-username  -u  Masking Engine User Name - Required value"
    echo "  --masking-pwd       -p  Masking Engine Password - Required value"
    echo "  --help              -h  Show this help"
    echo "Example:"
    echo "dpxcc_setup_profileset.sh -f <PROFILE NAME> -e expressions.csv -d domains.csv -m <MASKING IP> -u <MASKING User> -p <MASKING Password>" 
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
    echo -ne "[`date '+%d%m%Y %T'`] $1" | tee -a "$LOG_FILE"
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
    local JQ="$(which jq)"
    local CURL="$(which curl)"

    [ -x "${JQ}" ] || { echo "jq not found. Please install 'jq' package and try again." ; exit 1 ; }
    [ -x "${CURL}" ] || { echo "curl not found. Please install 'curl' package and try again." ; exit 1 ; }
}

# Check if $1 not empty. If so print out message specified in $2 and exit.
check_response() {
    local RESPONSE="$1"
    if [ -z "$RESPONSE" ]; then
    	echo "No data!"
        exit 1
    fi
}

check_error() {
    local FUNC="$1"
    local API="$2"
    local RESPONSE="$3"

    # jq returns a literal null so we have to check against that...
    if [ "$(echo "$RESPONSE" | jq -r 'if type=="object" then .errorMessage else "null" end')" != 'null' ]; then
        echo "Error: Func=$FUNC API=$API Response=$RESPONSE"
        exit 1
    fi
}

# Login and set the correct $AUTH_HEADER.
dpxlogin() {
    local USERNAME="$1"
    local PASSWORD="$2"
    local FUNC='dpxlogin'
    local API='login'
    local DATA="{\"username\": \"$USERNAME\", \"password\": \"$PASSWORD\"}"
    LOGIN_RESPONSE=$(curl -X POST -H 'Content-Type: application/json' -H 'Accept: application/json' --keepalive-time "$KEEPALIVE" --data "$DATA" -s "$URL_BASE/$API"
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
    LOGOUT_RESPONSE=$(curl -X PUT -H ''"$AUTH_HEADER"'' -H 'Content-Type: application/json' --keepalive-time "$KEEPALIVE" -s "$URL_BASE/$API")
    log "$MASKING_USERNAME Logged out successfully\n"
}

add_domains() {
    local DOMAIN_NAME="$1"
    local DFT_ALGO_CODE="$2"
    local DFT_TOKEN_CODE="$3"
    local FUNC='add_domains'
    local API='domains'

    if [ -z "$DFT_TOKEN_CODE" ]; then
       local DATA="{ \"defaultAlgorithmCode\": \"$DFT_ALGO_CODE\", \"domainName\": \"$DOMAIN_NAME\"}"
    else
       local DATA="{ \"defaultAlgorithmCode\": \"$DFT_ALGO_CODE\", \"defaultTokenizationCode\": \"$DFT_TOKEN_CODE\", \"domainName\": \"$DOMAIN_NAME\"}"
    fi

    local ADD_DOMAINS_RESPONSE=$(curl -X POST -H ''"$AUTH_HEADER"'' -H 'Content-Type: application/json' --keepalive-time "$KEEPALIVE" --data "$DATA" -s "$URL_BASE/$API")
    check_error "$FUNC" "$API" "$ADD_DOMAINS_RESPONSE"
    ADD_DOMAINS_VALUE=$(echo "$ADD_DOMAINS_RESPONSE" | jq -r '.domainName')
    check_response "$ADD_DOMAINS_VALUE"
    log "Domain: $ADD_DOMAINS_VALUE added.\n"
}

add_expressions() {
    local DOMAIN="$1"
    local EXPRESSNAME="$2"
    local REGEXP="$3"
    local DATALEVEL="$4"
    local FUNC='add_domains'
    local API='profile-expressions'
    local DATA="{ \"domainName\": \"$DOMAIN\", \"expressionName\": \"$EXPRESSNAME\", \"regularExpression\": \"$REGEXP\", \"dataLevelProfiling\": \"$DATALEVEL\"}"

    local ADD_EXPRESS_RESPONSE=$(curl -X POST -H ''"$AUTH_HEADER"'' -H 'Content-Type: application/json' --keepalive-time "$KEEPALIVE" --data "$DATA" -s "$URL_BASE/$API")
    check_error "$FUNC" "$API" "$ADD_EXPRESS_RESPONSE"
    ADD_EXPRESS_VALUE=$(echo "$ADD_EXPRESS_RESPONSE" | jq -r '.expressionName')
    check_response "$ADD_EXPRESS_VALUE"
    log "Expression: $ADD_EXPRESS_VALUE added.\n"

    # Return EXPRESSID_LIST
    EXPRESSID_VALUE=$(echo "$ADD_EXPRESS_RESPONSE" | jq -r '.profileExpressionId')
    EXPRESSID_LIST="$EXPRESSID_LIST,$EXPRESSID_VALUE"
}

add_profileset() {
    local PROFILE_NAME="$1"
    local EXPRESSID_LIST="$2"
    local FUNC='add_profileset'
    local API='profile-sets'
    local DATA="{ \"profileSetName\": \"$PROFILE_NAME\", \"profileExpressionIds\": [ $EXPRESSID_LIST ] }"
    local ADD_PROFILE_RESPONSE=$(curl -X POST -H ''"$AUTH_HEADER"'' -H 'Content-Type: application/json' --keepalive-time "$KEEPALIVE" --data "$DATA" -s "$URL_BASE/$API")
    check_error "$FUNC" "$API" "$ADD_PROFILE_RESPONSE"
    ADD_PROFILE_VALUE=$(echo "$ADD_PROFILE_RESPONSE" | jq -r '.profileSetName')
    check_response "$ADD_PROFILE_VALUE"
    log "ProfileSet: $ADD_PROFILE_VALUE added.\n"
    log "Expressions ids ${EXPRESSID_LIST} added to ${PROFILE_NAME}\n"
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

while getopts ":h:f:e:d:m:u:p:" PARAMETERS; do
    case $PARAMETERS in
        h)
        	;;
        f)
        	PROFILE_NAME=${OPTARG[@]}
        	add_parms "$PARAMETERS";
        	;;
        e)
        	EXPRESS_FILE=${OPTARG[@]}
        	add_parms "$PARAMETERS";
        	;;
        d)
        	DOMAINS_FILE=${OPTARG[@]}
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

check_parm "$ALLPARMS"

URL_BASE="http://${MASKING_ENGINE}/masking/api"

dpxlogin "$MASKING_USERNAME" "$MASKING_PASSWORD"

# Delete logfile
rm "$LOG_FILE"

# Create Domains
log "Creating domains: \n"
while IFS=\; read -r DOMAIN_NAME DFT_ALGO_CODE DFT_TOKEN_CODE
do
    if [[ ! "$DOMAIN_NAME" =~ "#" ]]
    then
        add_domains "$DOMAIN_NAME" "$DFT_ALGO_CODE" "$DFT_TOKEN_CODE"
    fi
done < "$DOMAINS_FILE"

# Create Expressions
log "Creating expressions: \n"
while IFS=\; read -r EXPRESS_NAME DOMAIN DATALEVEL REGEXP
do
    if [[ ! "$EXPRESS_NAME" =~ "#" ]]
    then
        add_expressions "$DOMAIN" "$EXPRESS_NAME" "$REGEXP" "$DATALEVEL"
    fi
done < "$EXPRESS_FILE"

# Add ProfileSet
add_profileset "$PROFILE_NAME" "$EXPRESSID_LIST"

dpxlogout
