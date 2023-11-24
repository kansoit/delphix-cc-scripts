#!/bin/bash


apiVer="v5.1.22"
MASKING_ENGINE=""
MASKING_USERNAME=""
MASKING_PASSWORD=""
URL_BASE=""
LDAP_SERVER=""
LDAP_PORT='389'
LDAP_BASEDN='DC=candy,DC=com,DC=ar'
LDAP_FILTER='(&(objectClass=person)(sAMAccountName=?))'
LDAP_DOMAIN='CANDY'
LDAP_TLS='false'
LDAP_STATUS='false'
NOASK='no'
NOROLLBACK='no'
KEEPALIVE=600
logFileDate=$(date '+%d%m%Y_%H%M%S')
logFileName="dpxcc_setup_ldap_$logFileDate.log"
PROXY_BYPASS=true
HttpsInsecure=false


show_help() {
    echo "Usage: dpxcc_setup_ldap.sh [options]"
    echo "Options:"
    echo "  --ldap-host       -s    LDAP Server IP Address       - Required value"
    echo "  --ldap-port       -t    LDAP Port Number             - Default: 389"
    echo "  --ldap-basedn     -b    BaseDN                       - Default: DC=candy,DC=com,DC=ar"
    echo "  --ldap-domain     -d    NETBIOS Domain Name          - Default: CANDY"
    echo "  --ldap-tls        -l    Enable LDAP TLS (true/false) - Default: false"
    echo "  --ldap-filter     -f    LDAP Filter                  - Default: (&(objectClass=person)(sAMAccountName=?))"
    echo "  --ldap-enabled    -e    Enable LDAP (true/false)     - Default: false"
    echo "  --log-file        -o    Log file name                - Default Value: Current date_time.log"
    echo "  --proxy-bypass    -x    Proxy ByPass                 - Default: true"
    echo "  --https-insecure  -k    Make Https Insecure          - Default: false"
    echo "  --masking-engine  -m    Masking Engine Address       - Required value"
    echo "  --masking-user    -u    Masking Engine User Name     - Required value"
    echo "  --masking-pwd     -p    Masking Engine Password      - Required value"
    echo "  --no-ask          -a    No Ask dialog                - Default: no (Future use)"
    echo "  --no-rollback     -r    No Rollback dialog           - Default: no (Future use)"
    echo "  --help            -h    Show this help"
    echo "Example:"
    echo "dpxcc_setup_ldap.sh -s <LDAP IP> -b DC=candy,DC=com,DC=ar -d CANDY -e true -m <MASKING IP> -u <MASKING User> -p <MASKING Password>"
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

    local KEY="s"
    if [[ ! "$PARMS" == *"$KEY"* ]]; then
        echo "Option -s is missing. LDAP Server IP Address is required."
        exit 1
    fi

    local KEY="m"
    if [[ ! "$PARMS" == *"$KEY"* ]]; then
        echo "Option -m is missing. Masking Engine IP Address is required."
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

split_response() {
    local CURL_FULL_RESPONSE="$1"

    local line_break
    line_break=$(echo "$CURL_FULL_RESPONSE" | awk -v RS='\r\n' '/^$/{print NR; exit;}')

    CURL_HEADER_RESPONSE=$(echo "$CURL_FULL_RESPONSE" | awk -v LINE_BREAK="$line_break" 'NR<LINE_BREAK{print $0}')
    CURL_HEADER_RESPONSE=$(echo "$CURL_HEADER_RESPONSE" | awk '/^HTTP/{print $2}')
    CURL_BODY_RESPONSE=$(echo "$CURL_FULL_RESPONSE" | awk -v LINE_BREAK="$line_break" 'NR>LINE_BREAK{print $0}')
}

# Check if $1 not empty. If so print out message specified in $2 and exit.
check_response_value() {
    local RESPONSE_VALUE="$1"

    if [ -z "$RESPONSE_VALUE" ];
    then
        log "${FUNCNAME[0]}() -> No data in response variable\n"
        dpxlogout
        exit 1
    fi
}

check_response_error() {
    local FUNC="$1"
    local API="$2"

    local errorMessage

    # jq returns a literal null so we have to check against that...
    if [ "$(echo "$CURL_BODY_RESPONSE" | jq -r 'if type=="object" then .errorMessage else "null" end')" != 'null' ];
    then
        if [[ ! "$FUNC" == "dpxlogin" ]];
        then
            log "${FUNCNAME[0]}() -> Function: $FUNC() - Api: $API - Response Code: $CURL_HEADER_RESPONSE - Response Body: $CURL_BODY_RESPONSE\n"
            dpxlogout
            exit 1
        else
            errorMessage=$(echo "$CURL_BODY_RESPONSE" | jq -r '.errorMessage')
            log "${FUNCNAME[0]}() -> Function: $FUNC() - Api: $API - Response Code: $CURL_HEADER_RESPONSE - Response Body: $CURL_BODY_RESPONSE\n"
            echo "$errorMessage"
            exit 1
        fi
    else
        log "Response Code: $CURL_HEADER_RESPONSE - Response Body: $CURL_BODY_RESPONSE\n"
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

    curl_command="$curl_command -i -s $URL_BASE/$API"
    log "$curl_command\n"
}

# Login
dpxlogin() {
    local USERNAME="$1"
    local PASSWORD="$2"

    local FUNC="${FUNCNAME[0]}"
    local URL_BASE="$MASKING_ENGINE/masking/api/$apiVer"
    local API='login'
    local METHOD="POST"
    local CONTENT_TYPE="application/json"
    local FORM

    local DATA="{\"username\": \"$USERNAME\", \"password\": \"$PASSWORD\"}"
    AUTH_HEADER=""

    log "Logging in with $USERNAME ...\n"
    build_curl "$URL_BASE" "$API" "$METHOD" "$AUTH_HEADER" "$CONTENT_TYPE" "$KEEPALIVE" "$PROXY_BYPASS" "$HttpsInsecure" "$FORM" "$DATA"

    local LOGIN_RESPONSE
    LOGIN_RESPONSE=$(eval "$curl_command")

    split_response "$LOGIN_RESPONSE"
    check_response_error "$FUNC" "$API"

    local LOGIN_VALUE
    LOGIN_VALUE=$(echo "$CURL_BODY_RESPONSE" | jq -r '.errorMessage')
    check_response_value "$LOGIN_VALUE"

    TOKEN=$(echo "$CURL_BODY_RESPONSE" | jq -r '.Authorization')
    AUTH_HEADER="Authorization: $TOKEN"
    log "$MASKING_USERNAME logged in successfully with token $TOKEN\n"
}

# Logout
dpxlogout() {
    local FUNC="${FUNCNAME[0]}"
    local URL_BASE="$MASKING_ENGINE/masking/api/$apiVer"
    local API='logout'
    local METHOD="PUT"
    local CONTENT_TYPE="application/json"
    local FORM=""
    local DATA=""

    if [ -n "$AUTH_HEADER" ]; then
        log "Logging out ...\n"
        build_curl "$URL_BASE" "$API" "$METHOD" "$AUTH_HEADER" "$CONTENT_TYPE" "$KEEPALIVE" "$PROXY_BYPASS" "$HttpsInsecure" "$FORM" "$DATA"
        local LOGOUT_RESPONSE
        LOGOUT_RESPONSE=$(eval "$curl_command")
        split_response "$LOGOUT_RESPONSE"
        log "Response Code: $CURL_HEADER_RESPONSE - Response Body: $CURL_BODY_RESPONSE\n"
        log "$MASKING_USERNAME Logged out successfully with token $TOKEN\n"
    fi
}

# Get LDAP Config
get_ldap_config() {
    local setting_group="ldap"
    local page_number=1
    local page_size=10

    local FUNC="${FUNCNAME[0]}"
    local URL_BASE="$MASKING_ENGINE/masking/api/$apiVer"
    local API="application-settings?setting_group=$setting_group&page_number=$page_number&page_size=$page_size"
    local METHOD="GET"
    local AUTH="$AUTH_HEADER"
    local CONTENT_TYPE="application/json"
    local FORM=""
    local DATA=""

    local settingName
    local settingValue

    log "Getting LDAP Parameters ...\n"
    build_curl "$URL_BASE" "$API" "$METHOD" "$AUTH" "$CONTENT_TYPE" "$KEEPALIVE" "$PROXY_BYPASS" "$HttpsInsecure" "$FORM" "$DATA"

    local LDAP_CONFIG_RESPONSE
    LDAP_CONFIG_RESPONSE=$(eval "$curl_command")

    split_response "$LDAP_CONFIG_RESPONSE"
    check_response_error "$FUNC" "$API"

    local LDAP_CONFIG_VALUE
    LDAP_CONFIG_VALUE=$(echo "$CURL_BODY_RESPONSE" | jq -r '.responseList[]')
    check_response_value "$LDAP_CONFIG_VALUE"

    settingName="LdapHost"
    settingValue=$(echo "$CURL_BODY_RESPONSE" | jq -r ".responseList[] | select(.settingName == \"$settingName\") | .settingValue")
    msg_box "LDAP Server Name/Ip: $settingValue\n"
    log "LDAP Server Name/Ip: $settingValue\n"

    settingName="LdapPort"
    settingValue=$(echo "$CURL_BODY_RESPONSE" | jq -r ".responseList[] | select(.settingName == \"$settingName\") | .settingValue")
    msg_box "LDAP Port Number: $settingValue\n"
    log "LDAP Port Number: $settingValue\n"

    settingName="LdapBasedn"
    settingValue=$(echo "$CURL_BODY_RESPONSE" | jq -r ".responseList[] | select(.settingName == \"$settingName\") | .settingValue")
    msg_box "LDAP BaseDN: $settingValue\n"
    log "LDAP BaseDN: $settingValue\n"

    settingName="LdapFilter"
    settingValue=$(echo "$CURL_BODY_RESPONSE" | jq -r ".responseList[] | select(.settingName == \"$settingName\") | .settingValue")
    msg_box "LDAP Filter: $settingValue\n"
    log "LDAP Filter: $settingValue\n"

    settingName="MsadDomain"
    settingValue=$(echo "$CURL_BODY_RESPONSE" | jq -r ".responseList[] | select(.settingName == \"$settingName\") | .settingValue")
    msg_box "LDAP Domain Name: $settingValue\n"
    log "LDAP Domain Name: $settingValue\n"

    settingName="LdapTlsEnable"
    settingValue=$(echo "$CURL_BODY_RESPONSE" | jq -r ".responseList[] | select(.settingName == \"$settingName\") | .settingValue")
    msg_box "LDAP TLS Enabled: $settingValue\n"
    log "LDAP TLS Enabled: $settingValue\n"

    settingName="Enable"
    settingValue=$(echo "$CURL_BODY_RESPONSE" | jq -r ".responseList[] | select(.settingName == \"$settingName\") | .settingValue")
    msg_box "LDAP Status Enabled: $settingValue\n"
    log "LDAP Status Enabled: $settingValue\n"
}

set_ldap_server() {
    local LDAP_SERVER="$1"

    local FUNC="${FUNCNAME[0]}"
    local URL_BASE="$MASKING_ENGINE/masking/api/$apiVer"
    local API='application-settings/31'
    local METHOD="PUT"
    local AUTH="$AUTH_HEADER"
    local CONTENT_TYPE="application/json"
    local FORM=""

    local DATA="{\"settingValue\": \"$LDAP_SERVER\"}"

    log "Setting LDAP Server Name/Ip ...\n"
    build_curl "$URL_BASE" "$API" "$METHOD" "$AUTH" "$CONTENT_TYPE" "$KEEPALIVE" "$PROXY_BYPASS" "$HttpsInsecure" "$FORM" "$DATA"
    local LDAP_SERVER_RESPONSE
    LDAP_SERVER_RESPONSE=$(eval "$curl_command")

    split_response "$LDAP_SERVER_RESPONSE"
    check_response_error "$FUNC" "$API"

    local LDAP_SERVER_VALUE
    LDAP_SERVER_VALUE=$(echo "$CURL_BODY_RESPONSE" | jq -r '.settingValue')
    check_response_value "$LDAP_SERVER_VALUE"

    msg_box "LDAP Server Name/Ip: $LDAP_SERVER_VALUE\n"
    log "LDAP Server Name/Ip: $LDAP_SERVER_VALUE applied\n"
}

set_ldap_port() {
    local LDAP_PORT="$1"

    local FUNC="${FUNCNAME[0]}"
    local URL_BASE="$MASKING_ENGINE/masking/api/$apiVer"
    local API='application-settings/32'
    local METHOD="PUT"
    local AUTH="$AUTH_HEADER"
    local CONTENT_TYPE="application/json"
    local FORM=""

    local DATA="{\"settingValue\": \"$LDAP_PORT\"}"

    log "Setting LDAP Port Number ...\n"
    build_curl "$URL_BASE" "$API" "$METHOD" "$AUTH" "$CONTENT_TYPE" "$KEEPALIVE" "$PROXY_BYPASS" "$HttpsInsecure" "$FORM" "$DATA"

    local LDAP_PORT_RESPONSE
    LDAP_PORT_RESPONSE=$(eval "$curl_command")

    split_response "$LDAP_PORT_RESPONSE"
    check_response_error "$FUNC" "$API"

    local LDAP_PORT_VALUE
    LDAP_PORT_VALUE=$(echo "$CURL_BODY_RESPONSE" | jq -r '.settingValue')
    check_response_value "$LDAP_PORT_VALUE"

    msg_box "LDAP Port Number: $LDAP_PORT_VALUE\n"
    log "LDAP Port Number: $LDAP_PORT_VALUE applied\n"
}

set_ldap_baseDN() {
    local LDAP_BASEDN="$1"

    local FUNC="${FUNCNAME[0]}"
    local URL_BASE="$MASKING_ENGINE/masking/api/$apiVer"
    local API='application-settings/33'
    local METHOD="PUT"
    local AUTH="$AUTH_HEADER"
    local CONTENT_TYPE="application/json"
    local FORM=""

    local DATA="{\"settingValue\": \"$LDAP_BASEDN\"}"

    log "Setting LDAP BaseDN ...\n"
    build_curl "$URL_BASE" "$API" "$METHOD" "$AUTH" "$CONTENT_TYPE" "$KEEPALIVE" "$PROXY_BYPASS" "$HttpsInsecure" "$FORM" "$DATA"

    local LDAP_BASEDN_RESPONSE
    LDAP_BASEDN_RESPONSE=$(eval "$curl_command")

    split_response "$LDAP_BASEDN_RESPONSE"
    check_response_error "$FUNC" "$API"

    local LDAP_BASEDN_VALUE
    LDAP_BASEDN_VALUE=$(echo "$CURL_BODY_RESPONSE" | jq -r '.settingValue')
    check_response_value "$LDAP_BASEDN_VALUE"

    msg_box "LDAP BaseDN: $LDAP_BASEDN_VALUE\n"
    log "LDAP BaseDN: $LDAP_BASEDN_VALUE applied\n"
}

set_ldap_filter() {
    local LDAP_FILTER="$1"

    local FUNC="${FUNCNAME[0]}"
    local URL_BASE="$MASKING_ENGINE/masking/api/$apiVer"
    local API='application-settings/34'
    local METHOD="PUT"
    local AUTH="$AUTH_HEADER"
    local CONTENT_TYPE="application/json"
    local FORM=""

    local DATA="{\"settingValue\": \"$LDAP_FILTER\"}"

    log "Setting LDAP Filter ...\n"
    build_curl "$URL_BASE" "$API" "$METHOD" "$AUTH" "$CONTENT_TYPE" "$KEEPALIVE" "$PROXY_BYPASS" "$HttpsInsecure" "$FORM" "$DATA"

    local LDAP_FILTER_RESPONSE
    LDAP_FILTER_RESPONSE=$(eval "$curl_command")

    split_response "$LDAP_FILTER_RESPONSE"
    check_response_error "$FUNC" "$API"

    local LDAP_FILTER_VALUE
    LDAP_FILTER_VALUE=$(echo "$CURL_BODY_RESPONSE" | jq -r '.settingValue')
    check_response_value "$LDAP_FILTER_VALUE"

    msg_box "LDAP Filter: $LDAP_FILTER_VALUE\n"
    log "LDAP Filter: $LDAP_FILTER_VALUE applied\n"
}

set_ldap_domain() {
    local LDAP_DOMAIN="$1"

    local FUNC="${FUNCNAME[0]}"
    local URL_BASE="$MASKING_ENGINE/masking/api/$apiVer"
    local API='application-settings/35'
    local METHOD="PUT"
    local AUTH="$AUTH_HEADER"
    local CONTENT_TYPE="application/json"
    local FORM=""

    local DATA="{\"settingValue\": \"$LDAP_DOMAIN\"}"

    log "Setting LDAP Domain Name ...\n"
    build_curl "$URL_BASE" "$API" "$METHOD" "$AUTH" "$CONTENT_TYPE" "$KEEPALIVE" "$PROXY_BYPASS" "$HttpsInsecure" "$FORM" "$DATA"

    local LDAP_DOMAIN_RESPONSE
    LDAP_DOMAIN_RESPONSE=$(eval "$curl_command")

    split_response "$LDAP_DOMAIN_RESPONSE"
    check_response_error "$FUNC" "$API"

    local LDAP_DOMAIN_VALUE
    LDAP_DOMAIN_VALUE=$(echo "$CURL_BODY_RESPONSE" | jq -r '.settingValue')
    check_response_value "$LDAP_DOMAIN_VALUE"

    msg_box "LDAP Domain Name: $LDAP_DOMAIN_VALUE\n"
    log "LDAP Domain Name: $LDAP_DOMAIN_VALUE applied\n"
}

set_ldap_tls() {
    local LDAP_TLS="$1"

    local FUNC="${FUNCNAME[0]}"
    local URL_BASE="$MASKING_ENGINE/masking/api/$apiVer"
    local API='application-settings/51'
    local METHOD="PUT"
    local AUTH="$AUTH_HEADER"
    local CONTENT_TYPE="application/json"
    local FORM=""

    local DATA="{\"settingValue\": \"$LDAP_TLS\"}"

    log "Setting LDAP TLS enabled ...\n"
    build_curl "$URL_BASE" "$API" "$METHOD" "$AUTH" "$CONTENT_TYPE" "$KEEPALIVE" "$PROXY_BYPASS" "$HttpsInsecure" "$FORM" "$DATA"

    local LDAP_TLS_RESPONSE
    LDAP_TLS_RESPONSE=$(eval "$curl_command")

    split_response "$LDAP_TLS_RESPONSE"
    check_response_error "$FUNC" "$API"

    local LDAP_TLS_VALUE
    LDAP_TLS_VALUE=$(echo "$CURL_BODY_RESPONSE" | jq -r '.settingValue')
    check_response_value "$LDAP_TLS_VALUE"

    msg_box "LDAP TLS Enabled: $LDAP_TLS_VALUE\n"
    log "LDAP TLS Enabled: $LDAP_TLS_VALUE applied\n"
}

set_ldap_status() {
    local LDAP_STATUS="$1"

    local FUNC="${FUNCNAME[0]}"
    local URL_BASE="$MASKING_ENGINE/masking/api/$apiVer"
    local API='application-settings/30'
    local METHOD="PUT"
    local AUTH="$AUTH_HEADER"
    local CONTENT_TYPE="application/json"
    local FORM=""

    local DATA="{\"settingValue\": \"$LDAP_STATUS\"}"

    log "Setting LDAP Status ...\n"
    build_curl "$URL_BASE" "$API" "$METHOD" "$AUTH" "$CONTENT_TYPE" "$KEEPALIVE" "$PROXY_BYPASS" "$HttpsInsecure" "$FORM" "$DATA"

    local LDAP_STATUS_RESPONSE
    LDAP_STATUS_RESPONSE=$(eval "$curl_command")

    split_response "$LDAP_STATUS_RESPONSE"
    check_response_error "$FUNC" "$API"

    local LDAP_STATUS_VALUE
    LDAP_STATUS_VALUE=$(echo "$CURL_BODY_RESPONSE" | jq -r '.settingValue')
    check_response_value "$LDAP_STATUS_VALUE"

    msg_box "LDAP Status Enabled: $LDAP_STATUS_VALUE\n"
    log "LDAP Status Enabled: $LDAP_STATUS_VALUE applied\n"
}

check_packages

# Parameters
[ "$1" ] || { show_help; }

args=""
for arg
do
    delim=""
    case "$arg" in
        --ldap-host)
            args="${args}-s "
            ;;
        --ldap-port)
            args="${args}-t "
            ;;
        --ldap-basedn)
            args="${args}-b "
            ;;
        --ldap-domain)
            args="${args}-d "
            ;;
        --ldap-tls)
            args="${args}-l "
            ;;
        --ldap-filter)
            args="${args}-f "
            ;;
        --log-file)
            args="${args}-o "
            ;;
        --ldap-status)
            args="${args}-e "
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
        --no-ask)
            args="${args}-a "
            ;;
        --no-rollback)
            args="${args}-r "
            ;;
        --help|-h)
            show_help
            ;;
      *) [[ "${arg:0:1}" == "-" ]] || delim="\""
         args="${args}${delim}${arg}${delim} ";;
    esac
done

eval set -- "$args"

while getopts ":h:s:t:b:d:l:f:e:o:x:k:m:u:p:a:r:" PARAMETERS; do
    case $PARAMETERS in
        h)
        	;;
        s)
        	LDAP_SERVER=${OPTARG[*]}
        	add_parms "$PARAMETERS";
        	;;
        t)
        	LDAP_PORT=${OPTARG[*]}
        	add_parms "$PARAMETERS";
        	;;
        b)
        	LDAP_BASEDN=${OPTARG[*]}
        	add_parms "$PARAMETERS";
        	;;
        d)
        	LDAP_DOMAIN=${OPTARG[*]}
        	add_parms "$PARAMETERS";
        	;;
        l)
        	LDAP_TLS=${OPTARG[*]}
        	add_parms "$PARAMETERS";
        	;;
        f)
        	LDAP_FILTER=${OPTARG[*]}
        	add_parms "$PARAMETERS";
        	;;
        e)
        	LDAP_STATUS=${OPTARG[*]}
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
        a)
        	NOASK=${OPTARG[*]}
        	add_parms "$PARAMETERS";
        	;;
        r)
        	NOROLLBACK=${OPTARG[*]}
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

if dialog --stdout --no-collapse --title "Change LDAP Parameters" \
          --backtitle "Delphix LDAP Configurator" \
          --yesno "Yes: Apply new LDAP parameters No:  Quit safely!" 5 60; then

   dpxlogin "$MASKING_USERNAME" "$MASKING_PASSWORD"

   msg_box "\n"
   msg_box "Current LDAP parameters\n"
   log "Getting current LDAP parameters\n"

   get_ldap_config

   msg_box "\n"
   msg_box "New LDAP parameters applied\n"
   log "Applying new LDAP parameters\n"

   set_ldap_server "$LDAP_SERVER"
   set_ldap_port   "$LDAP_PORT"
   set_ldap_baseDN "$LDAP_BASEDN"
   set_ldap_filter "$LDAP_FILTER"
   set_ldap_domain "$LDAP_DOMAIN"
   set_ldap_tls    "$LDAP_TLS"
   set_ldap_status "$LDAP_STATUS"

   msg_box "\n"
   msg_box "You have a limited time period to test changes and rollback them if needed. Hurry Up!\n"
   msg_box "\n"
   msg_box "Yes: Rollback to factory LDAP parameters No: Keep new parameters and Quit.\n"

   if dialog --stdout --no-collapse --title "Change LDAP Parameters" \
    	      --backtitle "Delphix LDAP Configurator" \
     	      --yesno "$ALLMSG" 0 0; then

      msg_box "\n"
      msg_box "LDAP Parameters rollbacked\n"
      log "Rolling back LDAP Parameters\n"

      set_ldap_server "10.10.10.31"
      set_ldap_port   "389"
      set_ldap_baseDN "DC=tbspune,DC=com"
      set_ldap_filter "(&(objectClass=person)(sAMAccountName=?))"
      set_ldap_domain "AD"
      set_ldap_tls    "false"
      set_ldap_status "false"

      msg_box "\n"
      dpxlogout

      dialog --stdout --no-collapse --title "Change LDAP Parameters" \
             --backtitle "Delphix LDAP Configurator" \
             --no-ok --infobox "$ALLMSG" 0 0
   else
      msg_box "\n"
      dpxlogout
   fi
else
   exit
fi
