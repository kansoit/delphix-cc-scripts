#!/bin/bash

URL_BASE='http://192.168.1.100/masking/api/v5.1.22'
USERNAME='Admin'
PASSWORD='Admin-12'

KEEPALIVE=600
declare -a messages

# Print the message and exit the program.
die() {
    echo "*******************************************************************************"
    echo "$(basename $0) ERROR: $*" >&2
    echo "*******************************************************************************"
    exit 1
}

# Check if $1 is equal to 0. If so print out message specified in $2 and exit.
check_empty() {
    if [ -z "$1" ]; then
        print_msg "$2"
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

print_msg() {
    messages+=("$1")
    message_text=$(printf "%s\n" "${messages[@]}")
}

# Login and set the correct $AUTH_HEADER.
dpxlogin() {
    local FUNC='dpxlogin'
    local API='login'
    local DATA='{
      "username": "'"$USERNAME"'",
      "password": "'"$PASSWORD"'"
    }'
    LOGIN_RESPONSE=$(curl -X POST -H 'Content-Type: application/json' -H 'Accept: application/json' --keepalive-time "$KEEPALIVE" --data "$DATA" -s "$URL_BASE/$API"
) || die "Login failed with exit code $?"
    check_error "$FUNC" "$API" "$LOGIN_RESPONSE"
    TOKEN=$(echo $LOGIN_RESPONSE | jq -r '.Authorization')
    AUTH_HEADER="Authorization: $TOKEN"
    print_msg "$USERNAME logged in successfully"
}

# Logout
dpxlogout() {
    local FUNC='dpxlogout'
    local API='logout'
    LOGOUT_RESPONSE=$(curl -X PUT -H ''"$AUTH_HEADER"'' -H 'Content-Type: application/json' --keepalive-time "$KEEPALIVE" -s "$URL_BASE/$API")
    print_msg "$USERNAME Logged out successfully"
}

# Get LDAP Status (true/false)
get_ldap_status() {
    local FUNC='get_ldap_status'
    local API='application-settings/30'
    LDAP_STATUS_RESPONSE=$(curl -X GET -H ''"$AUTH_HEADER"'' -H 'Content-Type: application/json' --keepalive-time "$KEEPALIVE" -s "$URL_BASE/$API")
    check_error "$FUNC" "$API" "$LDAP_STATUS_RESPONSE"
    LDAP_STATUS_VALUE=$(echo $LDAP_STATUS_RESPONSE | jq -r '.settingValue')
    check_empty $LDAP_STATUS_VALUE "No data!"
    print_msg "LDAP status=$LDAP_STATUS_VALUE"
}

# Get LDAP Server Name
get_ldap_server() {
    local FUNC='get_ldap_server'
    local API='application-settings/31'
    LDAP_SERVER_RESPONSE=$(curl -X GET -H ''"$AUTH_HEADER"'' -H 'Content-Type: application/json' --keepalive-time "$KEEPALIVE" -s "$URL_BASE/$API")
    check_error "$FUNC" "$API" "$LDAP_SERVER_RESPONSE"
    LDAP_SERVER_VALUE=$(echo $LDAP_SERVER_RESPONSE | jq -r '.settingValue')
    check_empty $LDAP_SERVER_VALUE "No data!"
    print_msg "LDAP server=$LDAP_SERVER_VALUE"
}

# Get LDAP Port Number (389/686=SSL)
get_ldap_port() {
    local FUNC='get_ldap_port'
    local API='application-settings/32'
    LDAP_PORT_RESPONSE=$(curl -X GET -H ''"$AUTH_HEADER"'' -H 'Content-Type: application/json' --keepalive-time "$KEEPALIVE" -s "$URL_BASE/$API")
    check_error "$FUNC" "$API" "$LDAP_PORT_RESPONSE"
    LDAP_PORT_VALUE=$(echo $LDAP_PORT_RESPONSE | jq -r '.settingValue')
    check_empty $LDAP_PORT_VALUE "No data!"
    print_msg "LDAP port=$LDAP_PORT_VALUE"
}

# Get LDAP BaseDN
get_ldap_baseDN() {
    local FUNC='get_ldap_baseDN'
    local API='application-settings/33'
    LDAP_BASEDN_RESPONSE=$(curl -X GET -H ''"$AUTH_HEADER"'' -H 'Content-Type: application/json' --keepalive-time "$KEEPALIVE" -s "$URL_BASE/$API")
    check_error "$FUNC" "$API" "$LDAP_BASEDN_RESPONSE"
    LDAP_BASEDN_VALUE=$(echo $LDAP_BASEDN_RESPONSE | jq -r '.settingValue')
    check_empty $LDAP_BASEDN_VALUE "No data!"
    print_msg "LDAP baseDN=$LDAP_BASEDN_VALUE"
}

# Get LDAP Filter
get_ldap_filter() {
    local FUNC='get_ldap_filter'
    local API='application-settings/34'
    LDAP_FILTER_RESPONSE=$(curl -X GET -H ''"$AUTH_HEADER"'' -H 'Content-Type: application/json' --keepalive-time "$KEEPALIVE" -s "$URL_BASE/$API")
    check_error "$FUNC" "$API" "$LDAP_FILTER_RESPONSE"
    LDAP_FILTER_VALUE=$(echo $LDAP_FILTER_RESPONSE | jq -r '.settingValue')
    check_empty $LDAP_FILTER_VALUE "No data!"
    print_msg "LDAP filter=$LDAP_FILTER_VALUE"
}

# Get LDAP Domain
get_ldap_domain() {
    local FUNC='get_ldap_domain'
    local API='application-settings/35'
    LDAP_DOMAIN_RESPONSE=$(curl -X GET -H ''"$AUTH_HEADER"'' -H 'Content-Type: application/json' --keepalive-time "$KEEPALIVE" -s "$URL_BASE/$API")
    check_error "$FUNC" "$API" "$LDAP_DOMAIN_RESPONSE"
    LDAP_DOMAIN_VALUE=$(echo $LDAP_DOMAIN_RESPONSE | jq -r '.settingValue')
    check_empty $LDAP_DOMAIN_VALUE "No data!"
    print_msg "LDAP domain=$LDAP_DOMAIN_VALUE"
}

# Get LDAP TLS (true/false)
get_ldap_tls() {
    local FUNC='get_ldap_tls'
    local API='application-settings/51'
    LDAP_TLS_RESPONSE=$(curl -X GET -H ''"$AUTH_HEADER"'' -H 'Content-Type: application/json' --keepalive-time "$KEEPALIVE" -s "$URL_BASE/$API")
    check_error "$FUNC" "$API" "$LDAP_TLS_RESPONSE"
    LDAP_TLS_VALUE=$(echo $LDAP_TLS_RESPONSE | jq -r '.settingValue')
    check_empty $LDAP_TLS_VALUE "No data!"
    print_msg "LDAP tls=$LDAP_TLS_VALUE"
}

set_ldap_status() {
    local FUNC='set_ldap_status'
    local API='application-settings/30'
    local DATA="$1"
    LDAP_STATUS_RESPONSE=$(curl -X PUT -H ''"$AUTH_HEADER"'' -H 'Content-Type: application/json' --keepalive-time "$KEEPALIVE" --data "$DATA" -s "$URL_BASE/$API")
    check_error "$FUNC" "$API" "$LDAP_STATUS_RESPONSE"
    LDAP_STATUS_VALUE=$(echo $LDAP_STATUS_RESPONSE | jq -r '.settingValue')
    check_empty $LDAP_STATUS_VALUE "No data!"
    print_msg "LDAP status=$LDAP_STATUS_VALUE"
}

set_ldap_server() {
    local FUNC='set_ldap_server'
    local API='application-settings/31'
    local DATA="$1"
    LDAP_SERVER_RESPONSE=$(curl -X PUT -H ''"$AUTH_HEADER"'' -H 'Content-Type: application/json' --keepalive-time "$KEEPALIVE" --data "$DATA" -s "$URL_BASE/$API")
    check_error "$FUNC" "$API" "$LDAP_SERVER_RESPONSE"
    LDAP_SERVER_VALUE=$(echo $LDAP_SERVER_RESPONSE | jq -r '.settingValue')
    check_empty $LDAP_SERVER_VALUE "No data!"
    print_msg "LDAP server=$LDAP_SERVER_VALUE"
}

set_ldap_port() {
    local FUNC='set_ldap_port'
    local API='application-settings/32'
    local DATA="$1"
    LDAP_PORT_RESPONSE=$(curl -X PUT -H ''"$AUTH_HEADER"'' -H 'Content-Type: application/json' --keepalive-time "$KEEPALIVE" --data "$DATA" -s "$URL_BASE/$API")
    check_error "$FUNC" "$API" "$LDAP_PORT_RESPONSE"
    LDAP_PORT_VALUE=$(echo $LDAP_PORT_RESPONSE | jq -r '.settingValue')
    check_empty $LDAP_PORT_VALUE "No data!"
    print_msg "LDAP port=$LDAP_PORT_VALUE"
}

set_ldap_baseDN() {
    local FUNC='set_ldap_baseDN'
    local API='application-settings/33'
    local DATA="$1"
    LDAP_BASEDN_RESPONSE=$(curl -X PUT -H ''"$AUTH_HEADER"'' -H 'Content-Type: application/json' --keepalive-time "$KEEPALIVE" --data "$DATA" -s "$URL_BASE/$API")
    check_error "$FUNC" "$API" "$LDAP_BASEDN_RESPONSE"
    LDAP_BASEDN_VALUE=$(echo $LDAP_BASEDN_RESPONSE | jq -r '.settingValue')
    check_empty $LDAP_BASEDN_VALUE "No data!"
    print_msg "LDAP baseDN=$LDAP_BASEDN_VALUE"
}

set_ldap_filter() {
    local FUNC='set_ldap_filter'
    local API='application-settings/34'
    local DATA="$1"
    LDAP_FILTER_RESPONSE=$(curl -X PUT -H ''"$AUTH_HEADER"'' -H 'Content-Type: application/json' --keepalive-time "$KEEPALIVE" --data "$DATA" -s "$URL_BASE/$API")
    check_error "$FUNC" "$API" "$LDAP_FILTER_RESPONSE"
    LDAP_FILTER_VALUE=$(echo $LDAP_FILTER_RESPONSE | jq -r '.settingValue')
    check_empty $LDAP_FILTER_VALUE "No data!"
    print_msg "LDAP filter=$LDAP_FILTER_VALUE"
}

set_ldap_domain() {
    local FUNC='set_ldap_domain'
    local API='application-settings/35'
    local DATA="$1"
    LDAP_DOMAIN_RESPONSE=$(curl -X PUT -H ''"$AUTH_HEADER"'' -H 'Content-Type: application/json' --keepalive-time "$KEEPALIVE" --data "$DATA" -s "$URL_BASE/$API")
    check_error "$FUNC" "$API" "$LDAP_DOMAIN_RESPONSE"
    LDAP_DOMAIN_VALUE=$(echo $LDAP_DOMAIN_RESPONSE | jq -r '.settingValue')
    check_empty $LDAP_DOMAIN_VALUE "No data!"
    print_msg "LDAP domain=$LDAP_DOMAIN_VALUE"
}

set_ldap_tls() {
    local FUNC='set_ldap_tls'
    local API='application-settings/51'
    local DATA="$1"
    LDAP_TLS_RESPONSE=$(curl -X PUT -H ''"$AUTH_HEADER"'' -H 'Content-Type: application/json' --keepalive-time "$KEEPALIVE" --data "$DATA" -s "$URL_BASE/$API")
    check_error "$FUNC" "$API" "$LDAP_TLS_RESPONSE"
    LDAP_TLS_VALUE=$(echo $LDAP_TLS_RESPONSE | jq -r '.settingValue')
    check_empty $LDAP_TLS_VALUE "No data!"
    print_msg "LDAP tls=$LDAP_TLS_VALUE"
}

JQ="$(which jq)"
CURL="$(which curl)"
DIALOG="$(which dialog)"

test -z "$JQ" && echo "jq binary not found" && exit
test -z "$CURL" && echo "curl binary not found" && exit
test -z "$DIALOG" && echo "dialog binary not found" && exit

if dialog --stdout --no-collapse --title "Change LDAP Parameters" \
          --backtitle "Delphix LDAP Configurator" \
          --yesno "Yes: Apply new LDAP parameters\nNo:  Quit safely!" 7 40 ; then
   dpxlogin
   print_msg ""
   print_msg "Getting current LDAP parameters"

   get_ldap_status
   get_ldap_server
   get_ldap_port
   get_ldap_baseDN
   get_ldap_filter
   get_ldap_domain
   get_ldap_tls
   
   print_msg ""
   print_msg "Setting new LDAP parameters"

   LDAP_STATUS='true'
   set_ldap_status '{"settingValue": "'"$LDAP_STATUS"'"}'

   LDAP_SERVER='192.168.73.160'
   set_ldap_server '{"settingValue": "'"$LDAP_SERVER"'"}'

   LDAP_PORT='389'
   set_ldap_port '{"settingValue": "'"$LDAP_PORT"'"}'

   LDAP_BASEDN='DC=gruponet,DC=com,DC=ar'
   set_ldap_baseDN '{"settingValue": "'"$LDAP_BASEDN"'"}'

   LDAP_FILTER='(&(objectClass=person)(sAMAccountName=?))'
   set_ldap_filter '{"settingValue": "'"$LDAP_FILTER"'"}'

   LDAP_DOMAIN='GRUPONET'
   set_ldap_domain '{"settingValue": "'"$LDAP_DOMAIN"'"}'

   LDAP_TLS='false'
   set_ldap_tls '{"settingValue": "'"$LDAP_TLS"'"}'

   print_msg ""
   print_msg "You have $KEEPALIVE seconds to test changes and revert back them if needed. Hurry Up!"
   print_msg ""
   print_msg "Yes: Revert to old LDAP parameters"
   print_msg "No: Keep new parameters and Quit."

   if dialog --stdout --no-collapse --title "Change LDAP Parameters" \
    	      --backtitle "Delphix LDAP Configurator" \
     	      --yesno "$message_text" 0 0; then
      print_msg ""
      print_msg "Reverting LDAP Parameters"

      LDAP_STATUS='false'
      set_ldap_status '{"settingValue": "'"$LDAP_STATUS"'"}'

      LDAP_SERVER='10.10.10.31'
      set_ldap_server '{"settingValue": "'"$LDAP_SERVER"'"}'

      LDAP_PORT='389'
      set_ldap_port '{"settingValue": "'"$LDAP_PORT"'"}'

      LDAP_BASEDN=DC='DC=tbspune,DC=com'
      set_ldap_baseDN '{"settingValue": "'"$LDAP_BASEDN"'"}'

      LDAP_FILTER='(&(objectClass=person)(sAMAccountName=?))'
      set_ldap_filter '{"settingValue": "'"$LDAP_FILTER"'"}'

      LDAP_DOMAIN='AD'
      set_ldap_domain '{"settingValue": "'"$LDAP_DOMAIN"'"}'

      LDAP_TLS='false'
      set_ldap_tls '{"settingValue": "'"$LDAP_TLS"'"}'

      print_msg ""   
      dpxlogout
      
      echo "$message_text" > dpx_config_ldap.log
      dialog --stdout --no-collapse --title "Change LDAP Parameters" \
             --backtitle "Delphix LDAP Configurator" \
             --msgbox "$message_text" 0 0
   else
      print_msg ""
      dpxlogout
   fi
else
   exit
fi
