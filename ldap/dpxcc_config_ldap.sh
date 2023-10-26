#!/bin/bash


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
LDAP_ENABLED='false'
NOASK='no'
NOROLLBACK='no'
KEEPALIVE=600
logFileDate="`date '+%d%m%Y_%H%M%S'`"
logFileName="dpxcc_config_ldap_$logFileDate.log"


show_help() {
    echo "Usage: dpcc_config_ldap.sh [options]"
    echo "Options:"
    echo "  --ldap-host       -s 	LDAP Server IP Address - Required value"
    echo "  --ldap-port       -t	LDAP Port Number - Default: 389"
    echo "  --ldap-basedn     -b	BaseDN - Default: DC=candy,DC=com,DC=ar"
    echo "  --ldap-domain     -d	NETBIOS Domain Name - Default: CANDY"
    echo "  --ldap-tls        -l	Enable LDAP TLS (true/false) - Default: false"
    echo "  --ldap-filter     -f	LDAP Filter - Default: (&(objectClass=person)(sAMAccountName=?))"
    echo "  --ldap-enabled    -e	Enable LDAP (true/false) - Default: false"
    echo "  --masking-engine  -m	Masking Engine Address - Required value"
    echo "  --masking-user    -u	Masking Engine User Name - Required value"
    echo "  --masking-pwd     -p	Masking Engine Password - Required value"
    echo "  --no-ask          -a	No Ask dialog - Default: no"
    echo "  --no-rollback     -r	No Rollback dialog - Default: no"
    echo "  --help            -h	Show this help"
    echo "Example:"
    echo "dpxcc_config_ldap.sh -s <LDAP IP> -b DC=candy,DC=com,DC=ar -d CANDY -e true -m <MASKING IP> -u <MASKING User> -p <MASKING Password>" 
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
    local JQ="$(which jq)"
    local CURL="$(which curl)"
    local DIALOG="$(which dialog)"

    [ -x "${JQ}" ] || { echo "jq not found. Please install 'jq' package and try again." ; exit 1 ; }
    [ -x "${CURL}" ] || { echo "curl not found. Please install 'curl' package and try again." ; exit 1 ; }
    [ -x "${DIALOG}" ] || { echo "dialog not found. Please install 'dialog' package and try again." ; exit 1 ; }
}

check_conn() {
    curl_timeout=$(curl -s -v -m 5 -o /dev/null http://"$MASKING_ENGINE" 2>&1 | grep "timed out")
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
    if [ -z "$RESPONSE" ]; then
    	log "No data!"
        exit 1
    fi
}

check_error() {
    local FUNC="$1"
    local API="$2"
    local RESPONSE="$3"

    # jq returns a literal null so we have to check against that...
    if [ "$(echo "$RESPONSE" | jq -r 'if type=="object" then .errorMessage else "null" end')" != 'null' ]; then
        log "Error: Func=$FUNC API=$API Response=$RESPONSE"
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
    msg_box "$MASKING_USERNAME logged in successfully\n"
    log "$MASKING_USERNAME logged in successfully\n"
}

# Logout
dpxlogout() {
    local FUNC='dpxlogout'
    local API='logout'
    LOGOUT_RESPONSE=$(curl -X PUT -H ''"$AUTH_HEADER"'' -H 'Content-Type: application/json' --keepalive-time "$KEEPALIVE" -s "$URL_BASE/$API")
    msg_box "$MASKING_USERNAME Logged out successfully\n"
    log "$MASKING_USERNAME Logged out successfully\n"
}

# Get LDAP Server Name
get_ldap_server() {
    local FUNC='get_ldap_server'
    local API='application-settings/31'
    LDAP_SERVER_RESPONSE=$(curl -X GET -H ''"$AUTH_HEADER"'' -H 'Content-Type: application/json' --keepalive-time "$KEEPALIVE" -s "$URL_BASE/$API")
    check_error "$FUNC" "$API" "$LDAP_SERVER_RESPONSE"
    LDAP_SERVER_VALUE=$(echo $LDAP_SERVER_RESPONSE | jq -r '.settingValue')
    check_response "$LDAP_SERVER_VALUE"
    msg_box "LDAP server: $LDAP_SERVER_VALUE\n"
    log "Get LDAP server: $LDAP_SERVER_VALUE\n"
}

# Get LDAP Port Number (389/686=SSL)
get_ldap_port() {
    local FUNC='get_ldap_port'
    local API='application-settings/32'
    LDAP_PORT_RESPONSE=$(curl -X GET -H ''"$AUTH_HEADER"'' -H 'Content-Type: application/json' --keepalive-time "$KEEPALIVE" -s "$URL_BASE/$API")
    check_error "$FUNC" "$API" "$LDAP_PORT_RESPONSE"
    LDAP_PORT_VALUE=$(echo $LDAP_PORT_RESPONSE | jq -r '.settingValue')
    check_response "$LDAP_PORT_VALUE"
    msg_box "LDAP port: $LDAP_PORT_VALUE\n"
    log "Get LDAP port: $LDAP_PORT_VALUE\n"
}

# Get LDAP BaseDN
get_ldap_baseDN() {
    local FUNC='get_ldap_baseDN'
    local API='application-settings/33'
    LDAP_BASEDN_RESPONSE=$(curl -X GET -H ''"$AUTH_HEADER"'' -H 'Content-Type: application/json' --keepalive-time "$KEEPALIVE" -s "$URL_BASE/$API")
    check_error "$FUNC" "$API" "$LDAP_BASEDN_RESPONSE"
    LDAP_BASEDN_VALUE=$(echo $LDAP_BASEDN_RESPONSE | jq -r '.settingValue')
    check_response "$LDAP_BASEDN_VALUE"
    msg_box "LDAP baseDN: $LDAP_BASEDN_VALUE\n"
    log "Get LDAP baseDN: $LDAP_BASEDN_VALUE\n"
}

# Get LDAP Filter
get_ldap_filter() {
    local FUNC='get_ldap_filter'
    local API='application-settings/34'
    LDAP_FILTER_RESPONSE=$(curl -X GET -H ''"$AUTH_HEADER"'' -H 'Content-Type: application/json' --keepalive-time "$KEEPALIVE" -s "$URL_BASE/$API")
    check_error "$FUNC" "$API" "$LDAP_FILTER_RESPONSE"
    LDAP_FILTER_VALUE=$(echo $LDAP_FILTER_RESPONSE | jq -r '.settingValue')
    check_response "$LDAP_FILTER_VALUE"
    msg_box "LDAP filter: $LDAP_FILTER_VALUE\n"
    log "Get LDAP filter: $LDAP_FILTER_VALUE\n"
}

# Get LDAP Domain
get_ldap_domain() {
    local FUNC='get_ldap_domain'
    local API='application-settings/35'
    LDAP_DOMAIN_RESPONSE=$(curl -X GET -H ''"$AUTH_HEADER"'' -H 'Content-Type: application/json' --keepalive-time "$KEEPALIVE" -s "$URL_BASE/$API")
    check_error "$FUNC" "$API" "$LDAP_DOMAIN_RESPONSE"
    LDAP_DOMAIN_VALUE=$(echo $LDAP_DOMAIN_RESPONSE | jq -r '.settingValue')
    check_response "$LDAP_DOMAIN_VALUE"
    msg_box "LDAP domain: $LDAP_DOMAIN_VALUE\n"
    log "Get LDAP domain: $LDAP_DOMAIN_VALUE\n"
}

# Get LDAP TLS (true/false)
get_ldap_tls() {
    local FUNC='get_ldap_tls'
    local API='application-settings/51'
    LDAP_TLS_RESPONSE=$(curl -X GET -H ''"$AUTH_HEADER"'' -H 'Content-Type: application/json' --keepalive-time "$KEEPALIVE" -s "$URL_BASE/$API")
    check_error "$FUNC" "$API" "$LDAP_TLS_RESPONSE"
    LDAP_TLS_VALUE=$(echo $LDAP_TLS_RESPONSE | jq -r '.settingValue')
    check_response "$LDAP_TLS_VALUE"
    msg_box "LDAP tls: $LDAP_TLS_VALUE\n"
    log "Get LDAP tls: $LDAP_TLS_VALUE\n"
}

# Get LDAP Status (true/false)
get_ldap_status() {
    local FUNC='get_ldap_status'
    local API='application-settings/30'
    LDAP_STATUS_RESPONSE=$(curl -X GET -H ''"$AUTH_HEADER"'' -H 'Content-Type: application/json' --keepalive-time "$KEEPALIVE" -s "$URL_BASE/$API")
    check_error "$FUNC" "$API" "$LDAP_STATUS_RESPONSE"
    LDAP_STATUS_VALUE=$(echo $LDAP_STATUS_RESPONSE | jq -r '.settingValue')
    check_response "$LDAP_STATUS_VALUE"
    msg_box "LDAP status: $LDAP_STATUS_VALUE\n"
    log "Get LDAP status: $LDAP_STATUS_VALUE\n"
}

set_ldap_server() {
    local LDAP_SERVER_VALUE="$1"
    local FUNC='set_ldap_server'
    local API='application-settings/31'
    local DATA="{\"settingValue\": \"$LDAP_SERVER_VALUE\"}"
    local LDAP_SERVER_RESPONSE=$(curl -X PUT -H ''"$AUTH_HEADER"'' -H 'Content-Type: application/json' --keepalive-time "$KEEPALIVE" --data "$DATA" -s "$URL_BASE/$API")
    check_error "$FUNC" "$API" "$LDAP_SERVER_RESPONSE"
    LDAP_SERVER_VALUE=$(echo $LDAP_SERVER_RESPONSE | jq -r '.settingValue')
    check_response "$LDAP_SERVER_VALUE"
    msg_box "LDAP server: $LDAP_SERVER_VALUE\n"
    log "Set LDAP server: $LDAP_SERVER_VALUE\n"
}

set_ldap_port() {
    local LDAP_PORT_VALUE="$1"
    local FUNC='set_ldap_port'
    local API='application-settings/32'
    local DATA="{\"settingValue\": \"$LDAP_PORT_VALUE\"}"
    local LDAP_PORT_RESPONSE=$(curl -X PUT -H ''"$AUTH_HEADER"'' -H 'Content-Type: application/json' --keepalive-time "$KEEPALIVE" --data "$DATA" -s "$URL_BASE/$API")
    check_error "$FUNC" "$API" "$LDAP_PORT_RESPONSE"
    LDAP_PORT_VALUE=$(echo $LDAP_PORT_RESPONSE | jq -r '.settingValue')
    check_response "$LDAP_PORT_VALUE"
    msg_box "LDAP port: $LDAP_PORT_VALUE\n"
    log "Set LDAP port: $LDAP_PORT_VALUE\n"
}

set_ldap_baseDN() {
    local LDAP_BASEDN_VALUE="$1"
    local FUNC='set_ldap_baseDN'
    local API='application-settings/33'
    local DATA="{\"settingValue\": \"$LDAP_BASEDN_VALUE\"}"
    local LDAP_BASEDN_RESPONSE=$(curl -X PUT -H ''"$AUTH_HEADER"'' -H 'Content-Type: application/json' --keepalive-time "$KEEPALIVE" --data "$DATA" -s "$URL_BASE/$API")
    check_error "$FUNC" "$API" "$LDAP_BASEDN_RESPONSE"
    LDAP_BASEDN_VALUE=$(echo $LDAP_BASEDN_RESPONSE | jq -r '.settingValue')
    check_response "$LDAP_BASEDN_VALUE"
    msg_box "LDAP baseDN: $LDAP_BASEDN_VALUE\n"
    log "Set LDAP baseDN: $LDAP_BASEDN_VALUE\n"
}

set_ldap_filter() {
    local LDAP_FILTER_VALUE="$1"
    local FUNC='set_ldap_filter'
    local API='application-settings/34'
    local DATA="{\"settingValue\": \"$LDAP_FILTER_VALUE\"}"
    local LDAP_FILTER_RESPONSE=$(curl -X PUT -H ''"$AUTH_HEADER"'' -H 'Content-Type: application/json' --keepalive-time "$KEEPALIVE" --data "$DATA" -s "$URL_BASE/$API")
    check_error "$FUNC" "$API" "$LDAP_FILTER_RESPONSE"
    LDAP_FILTER_VALUE=$(echo $LDAP_FILTER_RESPONSE | jq -r '.settingValue')
    check_response "$LDAP_FILTER_VALUE"
    msg_box "LDAP filter: $LDAP_FILTER_VALUE\n"
    log "Set LDAP filter: $LDAP_FILTER_VALUE\n"
}

set_ldap_domain() {
    local LDAP_DOMAIN_VALUE="$1"
    local FUNC='set_ldap_domain'
    local API='application-settings/35'
    local DATA="{\"settingValue\": \"$LDAP_DOMAIN_VALUE\"}"
    local LDAP_DOMAIN_RESPONSE=$(curl -X PUT -H ''"$AUTH_HEADER"'' -H 'Content-Type: application/json' --keepalive-time "$KEEPALIVE" --data "$DATA" -s "$URL_BASE/$API")
    check_error "$FUNC" "$API" "$LDAP_DOMAIN_RESPONSE"
    LDAP_DOMAIN_VALUE=$(echo $LDAP_DOMAIN_RESPONSE | jq -r '.settingValue')
    check_response "$LDAP_DOMAIN_VALUE"
    msg_box "LDAP domain: $LDAP_DOMAIN_VALUE\n"
    log "Set LDAP domain: $LDAP_DOMAIN_VALUE\n"
}

set_ldap_tls() {
    local LDAP_TLS_VALUE="$1"
    local FUNC='set_ldap_tls'
    local API='application-settings/51'
    local DATA="{\"settingValue\": \"$LDAP_TLS_VALUE\"}"
    local LDAP_TLS_RESPONSE=$(curl -X PUT -H ''"$AUTH_HEADER"'' -H 'Content-Type: application/json' --keepalive-time "$KEEPALIVE" --data "$DATA" -s "$URL_BASE/$API")
    check_error "$FUNC" "$API" "$LDAP_TLS_RESPONSE"
    LDAP_TLS_VALUE=$(echo $LDAP_TLS_RESPONSE | jq -r '.settingValue')
    check_response "$LDAP_TLS_VALUE"
    msg_box "LDAP tls: $LDAP_TLS_VALUE\n"
    log "Set LDAP tls: $LDAP_TLS_VALUE\n"
}

set_ldap_status() {
    local LDAP_STATUS_VALUE="$1"
    local FUNC='set_ldap_status'
    local API='application-settings/30'
    local DATA="{\"settingValue\": \"$LDAP_STATUS_VALUE\"}"
    local LDAP_STATUS_RESPONSE=$(curl -X PUT -H ''"$AUTH_HEADER"'' -H 'Content-Type: application/json' --keepalive-time "$KEEPALIVE" --data "$DATA" -s "$URL_BASE/$API")
    check_error "$FUNC" "$API" "$LDAP_STATUS_RESPONSE"
    LDAP_STATUS_VALUE=$(echo $LDAP_STATUS_RESPONSE | jq -r '.settingValue')
    check_response "$LDAP_STATUS_VALUE"
    msg_box "LDAP status: $LDAP_STATUS_VALUE\n"
    log "Set LDAP status: $LDAP_STATUS_VALUE\n"
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
        --ldap-status)
            args="${args}-e "
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

eval set -- $args

while getopts ":h:s:t:b:d:l:f:e:m:u:p:a:r:" PARAMETERS; do
    case $PARAMETERS in
        h)
        	;;
        s)
        	LDAP_SERVER=${OPTARG[@]}
        	add_parms "$PARAMETERS";
        	;;
        t)
        	LDAP_PORT=${OPTARG[@]}
        	add_parms "$PARAMETERS";
        	;;
        b)
        	LDAP_BASEDN=${OPTARG[@]}
        	add_parms "$PARAMETERS";
        	;;
        d)
        	LDAP_DOMAIN=${OPTARG[@]}
        	add_parms "$PARAMETERS";
        	;;
        l)
        	LDAP_TLS=${OPTARG[@]}
        	add_parms "$PARAMETERS";
        	;;
        f)
        	LDAP_FILTER=${OPTARG[@]}
        	add_parms "$PARAMETERS";
        	;;
        e)
        	LDAP_STATUS=${OPTARG[@]}
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
        a)
        	NOASK=${OPTARG[@]}
        	add_parms "$PARAMETERS";
        	;;
        r)
        	NOROLLBACK=${OPTARG[@]}
        	add_parms "$PARAMETERS";
        	;;
        :) echo "Option -$OPTARG requires an argument."; exit 1;;
        *) echo "$OPTARG is an unrecognized option"; exit 1;;
    esac
done

# Check parameters
check_parm "$ALLPARMS"

# Update URL
URL_BASE="http://${MASKING_ENGINE}/masking/api"

# Check connection
check_conn

if dialog --stdout --no-collapse --title "Change LDAP Parameters" \
          --backtitle "Delphix LDAP Configurator" \
          --yesno "Yes: Apply new LDAP parameters No:  Quit safely!" 5 60; then

   dpxlogin "$MASKING_USERNAME" "$MASKING_PASSWORD"

   msg_box "\n"
   msg_box "Getting current LDAP parameters\n"
   log "Getting current LDAP parameters\n"

   get_ldap_server
   get_ldap_port
   get_ldap_baseDN
   get_ldap_filter
   get_ldap_domain
   get_ldap_tls
   get_ldap_status

   msg_box "\n"
   msg_box "Applying new LDAP parameters\n"
   log "Applying new LDAP parameters\n"

   set_ldap_server "$LDAP_SERVER"
   set_ldap_port   "$LDAP_PORT"
   set_ldap_baseDN "$LDAP_BASEDN"
   set_ldap_filter "$LDAP_FILTER"
   set_ldap_domain "$LDAP_DOMAIN"
   set_ldap_tls    "$LDAP_TLS"
   set_ldap_status "$LDAP_STATUS"

   msg_box "\n"
   msg_box "You have $KEEPALIVE seconds to test changes and revert back them if needed. Hurry Up!\n"
   msg_box "\n"
   msg_box "Yes: Revert to factory LDAP parameters No: Keep new parameters and Quit.\n"

   if dialog --stdout --no-collapse --title "Change LDAP Parameters" \
    	      --backtitle "Delphix LDAP Configurator" \
     	      --yesno "$ALLMSG" 0 0; then

      msg_box "\n"
      msg_box "Reverting LDAP Parameters\n"
      log "Reverting LDAP Parameters\n"

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
             --msgbox "$ALLMSG" 0 0
   else
      msg_box "\n"
      dpxlogout
   fi
else
   exit
fi
