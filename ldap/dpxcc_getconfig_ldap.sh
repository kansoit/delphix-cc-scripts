#!/bin/bash


apiVer="v5.1.22"
MASKING_ENGINE=""
MASKING_USERNAME=""
MASKING_PASSWORD=""
URL_BASE=""
KEEPALIVE=600
logFileDate=$(date '+%d%m%Y_%H%M%S')
logFileName="dpxcc_getconfig_ldap_$logFileDate.log"
PROXY_BYPASS=true
SECURE_CONN=false


show_help() {
    echo "Usage: dpcc_getconfig_ldap.sh [options]"
    echo "Options:"
    echo "  --log-file        -o    Log file name                - Default Value: Current date_time.log"
    echo "  --proxy-bypass    -x    Proxy ByPass                 - Default: true"
    echo "  --http-secure     -k    (http/https)                 - Default: false"
    echo "  --masking-engine  -m    Masking Engine Address       - Required value"
    echo "  --masking-user    -u    Masking Engine User Name     - Required value"
    echo "  --masking-pwd     -p    Masking Engine Password      - Required value"
    echo "  --help            -h    Show this help"
    echo "Example:"
    echo "dpxcc_getconfig_ldap.sh -m <MASKING IP> -u <MASKING User> -p <MASKING Password>"
    exit 1
}

log (){
    local logMsg="$1"
    local logMsgDate
    logMsgDate="[$(date '+%d%m%Y %T')]"
    echo -ne "$logMsgDate $logMsg" >> "$logFileName"
}


msg_box() {
    ALLMSG="$ALLMSG""$1"
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
    local JQ
    JQ=$(which jq)
    local CURL
    CURL=$(which curl)
    local DIALOG
    DIALOG=$(which dialog)

    [ -x "${JQ}" ] || { echo "jq not found. Please install 'jq' package and try again." ; exit 1 ; }
    [ -x "${CURL}" ] || { echo "curl not found. Please install 'curl' package and try again." ; exit 1 ; }
    [ -x "${DIALOG}" ] || { echo "dialog not found. Please install 'dialog' package and try again." ; exit 1 ; }
}

check_conn() {
    local MASKING_IP="$1"
    local PROXY_BYPASS="$2"
    local SECURE_CONN="$3"

    local curl_conn
    curl_conn="curl -s -v -m 5"

    local URL

    if [ "$SECURE_CONN" = true ]; then
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

    local errorMessage

    # jq returns a literal null so we have to check against that...
    if [ "$(echo "$RESPONSE" | jq -r 'if type=="object" then .errorMessage else "null" end')" != 'null' ];
    then
        log "Check Error! Function: $FUNC Api_Endpoint: $API Req_Response=$RESPONSE\n"
        if [[ ! "$FUNC" == "dpxlogin" ]];
        then
            dpxlogout
            exit 1
        else
            errorMessage=$(echo "$RESPONSE" | jq -r '.errorMessage')
            echo "$errorMessage"
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

# Login
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
    check_error "$FUNC" "$API" "$LOGIN_RESPONSE"
    local LOGIN_VALUE
    LOGIN_VALUE=$(echo "$LOGIN_RESPONSE" | jq -r '.errorMessage')
    check_response "$LOGIN_VALUE"
    TOKEN=$(echo "$LOGIN_RESPONSE" | jq -r '.Authorization')
    AUTH_HEADER="Authorization: $TOKEN"
    log "$MASKING_USERNAME logged in successfully with token $TOKEN\n"
}

# Logout
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
        build_curl "$URL_BASE" "$API" "$METHOD" "$AUTH_HEADER" "$CONTENT_TYPE" "$KEEPALIVE" "$PROXY_BYPASS" "$SECURE_CONN" "$FORM" "$DATA"
        eval "$curl_command"
        log "$MASKING_USERNAME Logged out successfully with token $TOKEN\n"
    fi
}

# Get LDAP Config
get_ldap_config() {
    local setting_group="ldap"
    local page_number=1
    local page_size=256

    local FUNC='get_ldap_config'
    local URL_BASE="$MASKING_ENGINE/masking/api/$apiVer"
    local API='application-settings'
    local METHOD="GET"
    local AUTH="$AUTH_HEADER"
    local CONTENT_TYPE="application/json"
    local FORM=""
    local DATA

    local settingName
    local settingValue

    DATA="{\"setting_group\": \"$setting_group\", \"page_number\": $page_number, \"page_size\": $page_size}"

    log "Getting LDAP Server Name ...\n"
    build_curl "$URL_BASE" "$API" "$METHOD" "$AUTH" "$CONTENT_TYPE" "$KEEPALIVE" "$PROXY_BYPASS" "$SECURE_CONN" "$FORM" "$DATA"
    local LDAP_CONFIG_RESPONSE
    LDAP_CONFIG_RESPONSE=$(eval "$curl_command")
    check_error "$FUNC" "$API" "$LDAP_CONFIG_RESPONSE"
    local LDAP_CONFIG_VALUE
    LDAP_CONFIG_VALUE=$(echo "$LDAP_CONFIG_RESPONSE" | jq -r '.responseList[]')
    check_response "$LDAP_CONFIG_VALUE"

    settingName="LdapHost"
    settingValue=$(echo "$LDAP_CONFIG_RESPONSE" | jq -r ".responseList[] | select(.settingName == \"$settingName\") | .settingValue")
    msg_box "LDAP Server Name/Ip: $settingValue\n"
    log "LDAP Server Name/Ip: $settingValue\n"

    settingName="LdapPort"
    settingValue=$(echo "$LDAP_CONFIG_RESPONSE" | jq -r ".responseList[] | select(.settingName == \"$settingName\") | .settingValue")
    msg_box "LDAP Port Number: $settingValue\n"
    log "LDAP Port Number: $settingValue\n"

    settingName="LdapBasedn"
    settingValue=$(echo "$LDAP_CONFIG_RESPONSE" | jq -r ".responseList[] | select(.settingName == \"$settingName\") | .settingValue")
    msg_box "LDAP BaseDN: $settingValue\n"
    log "LDAP BaseDN: $settingValue\n"

    settingName="LdapFilter"
    settingValue=$(echo "$LDAP_CONFIG_RESPONSE" | jq -r ".responseList[] | select(.settingName == \"$settingName\") | .settingValue")
    msg_box "LDAP Filter: $settingValue\n"
    log "LDAP Filter: $settingValue\n"

    settingName="MsadDomain"
    settingValue=$(echo "$LDAP_CONFIG_RESPONSE" | jq -r ".responseList[] | select(.settingName == \"$settingName\") | .settingValue")
    msg_box "LDAP Domain Name: $settingValue\n"
    log "LDAP Domain Name: $settingValue\n"

    settingName="LdapTlsEnable"
    settingValue=$(echo "$LDAP_CONFIG_RESPONSE" | jq -r ".responseList[] | select(.settingName == \"$settingName\") | .settingValue")
    msg_box "LDAP TLS Enabled: $settingValue\n"
    log "LDAP TLS Enabled: $settingValue\n"

    settingName="Enable"
    settingValue=$(echo "$LDAP_CONFIG_RESPONSE" | jq -r ".responseList[] | select(.settingName == \"$settingName\") | .settingValue")
    msg_box "LDAP Status Enabled: $settingValue\n"
    log "LDAP Status Enabled: $settingValue\n"
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

while getopts ":h:o:x:k:m:u:p:" PARAMETERS; do
    case $PARAMETERS in
        h)
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

dpxlogin "$MASKING_USERNAME" "$MASKING_PASSWORD"

msg_box "\n"
log "Getting current LDAP Parameters\n"

get_ldap_config

msg_box "\n"

dpxlogout

dialog --stdout --no-collapse --title "Current LDAP Parameters" \
       --backtitle "Delphix LDAP GetConfig" \
       --no-ok --infobox "$ALLMSG" 0 0 
