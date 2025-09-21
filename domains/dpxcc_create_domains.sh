#!/usr/bin/bash

set -euo pipefail

apiVer="v5.1.27"
MASKING_ENGINE=""
URL_BASE=""
DOMAIN_FILE='domains.csv'
IGN_ERROR='false'
KEEPALIVE=300
logFileDate=$(date '+%d%m%Y_%H%M%S')
logFileName="dpxcc_create_domains_$logFileDate.log"
PROXY_BYPASS=true
HttpsInsecure=false


show_help() {
    echo "Usage: dpxcc_create_domains.sh [options]"
    echo "Options:"
    echo "  --domains-file      -d  File with Domains               - Default: domains.csv"
    echo "  --ignore-errors     -i  Ignore errors                   - Default: false"
    echo "  --log-file          -o  Log file name                   - Default: Current date_time.log"
    echo "  --proxy-bypass      -x  Proxy ByPass                    - Default: true"
    echo "  --https-insecure    -k  Make Https Insecure             - Default: false"
    echo "  --help              -h  Show this help"
    echo "Example:"
    echo "dpxcc_create_domains.sh"
    exit 1
}



log (){
    local logMsg="$1"
    local logMsgDate
    logMsgDate="[$(date '+%d%m%Y %T')]"
    echo -ne "$logMsgDate $logMsg" | tee -a "$logFileName"
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
    local HttpsInsecure="$3"

    local URL
    if [ "$HttpsInsecure" = true ]; then
        URL="https://$MASKING_IP"
    else
        URL="http://$MASKING_IP"
    fi

    local curl_cmd="curl -s -v -m 5 -o /dev/null"
    if [ "$PROXY_BYPASS" = true ]; then
        curl_cmd="$curl_cmd -x ''"
    fi
    if [ "$HttpsInsecure" = true ]; then
        curl_cmd="$curl_cmd -k"
    fi
    curl_cmd="$curl_cmd $URL 2>&1"

    local curlResponse
    curlResponse=$(eval "$curl_cmd")
    local curl_exit_code=$? # Capture exit code

    # Helper function for error messages
    handle_conn_error() {
        local error_pattern="$1"
        local user_message="$2"
        local suggested_curl="$3"
        local error_detail
        error_detail=$(echo "$curlResponse" | grep -o "$error_pattern")
        if [ -n "$error_detail" ]; then
            echo "Error: $error_detail - $user_message"
            echo "Ejecuta $suggested_curl y verifica la salida para identificar problemas de comunicación entre $HOSTNAME y el Masking Engine."
            exit 1
        fi
    }
    if [ "$curl_exit_code" -ne 0 ]; then
        # Check for specific error patterns in verbose output
        handle_conn_error "Connection timed out" "Por favor, verifica si la dirección IP del Masking Engine $MASKING_IP es correcta o si es necesario omitir el proxy con la opción -x true." "curl -s -v -m 5 -o /dev/null http://$MASKING_IP"
        handle_conn_error "Connection refused" "Por favor, confirma el nivel de seguridad deseado para la conexión (http/https) y asegúrate de que $MASKING_IP no esté bloqueado." "curl -s -v -m 5 -o /dev/null http://$MASKING_IP"
        handle_conn_error "307 Temporary Redirect" "Por favor, verifica si se requiere una conexión segura (https) al Masking Engine." "curl -s -v -m 5 -o /dev/null https://$MASKING_IP"
        handle_conn_error "Could not resolve host" "Por favor, verifica si el nombre del Masking Engine es correcto." "curl -s -v -m 5 -o /dev/null https://$MASKING_IP"

        # Generic error if none of the above matched
        echo "Error: Problema de conexión desconocido. El comando curl falló con código de salida $curl_exit_code."
        echo "Respuesta completa de curl: $curlResponse"
        exit 1
    fi

    # If we reach here, connection is successful
    log "Connection to $URL successful.\n"
}

check_csvf() {
    local csvFile="$1"
    local IGNORE="$2"

    if [ ! -f "$csvFile" ] && [ "$IGNORE" != "true" ]; then
        echo "Input CSV file $csvFile is missing"
        exit 1
    fi
}

check_jsonf() {
    local jsonFile="$1"
    local IGNORE="$2"

    if [ ! -f "$jsonFile" ] && [ "$IGNORE" != "true" ]; then
        echo "Input json file $jsonFile is missing"
        exit 1
    fi
}

split_response() {
    local CURL_FULL_RESPONSE="$1"

    # Extract HTTP status code directly from CURL_FULL_RESPONSE
    CURL_HEADER_RESPONSE=$(printf %s "$CURL_FULL_RESPONSE" | awk '/^< HTTP/{print $3; exit}')

    # Filter out verbose lines (starting with * or > or containing [bytes data])
    local CLEANED_RESPONSE
    CLEANED_RESPONSE=$(printf %s "$CURL_FULL_RESPONSE" | grep -v '^\*\|^>\|\[[0-9]\+ bytes data\]')

    # Extract body: find the first line that starts with '{' or '[' (start of JSON) and print all subsequent lines
    CURL_BODY_RESPONSE=$(printf %s "$CLEANED_RESPONSE" | sed -n '/^[[:space:]]*[{[]/,$p')
}

check_response_value() {
    local RESPONSE_VALUE="$1"
    local IGNORE="$2"

    if [ -z "$RESPONSE_VALUE" ];
    then
        if [[ "$IGNORE" == "false" ]];
        then
            log "${FUNCNAME[0]}() -> No data in response variable\n"
            dpxlogout
            exit 1
        fi
    fi
}

check_response_error() {
    local FUNC="$1"
    local API="$2"
    local IGNORE="$3"

    local errorMessage

    # jq returns a literal null so we have to check against that...
    local JQ_ERROR_CHECK
    local JQ_ERROR_CHECK_EXIT_CODE
    JQ_ERROR_CHECK=$(echo "$CURL_BODY_RESPONSE" | jq -r 'if type=="object" then .errorMessage else "null" end')
    JQ_ERROR_CHECK_EXIT_CODE=$?

    if [ "$JQ_ERROR_CHECK_EXIT_CODE" -ne 0 ]; then
        log "Error: jq failed to parse errorMessage in check_response_error. Exit code: $JQ_ERROR_CHECK_EXIT_CODE\\n"
        log "CURL_BODY_RESPONSE was: $CURL_BODY_RESPONSE\\n"
        dpxlogout
        exit 1
    fi

    if [ "$JQ_ERROR_CHECK" != 'null' ];
    then
        if [[ ! "$FUNC" == "dpxlogin" ]];
        then
            if [[ "$IGNORE" == "false" ]];
            then
                log "${FUNCNAME[0]}() -> Function: $FUNC() - Api: $API - Response Code: $CURL_HEADER_RESPONSE - Response Body: $CURL_BODY_RESPONSE\n"
                dpxlogout
                exit 1
            else
                log "${FUNCNAME[0]}() -> Function: $FUNC() - Api: $API - Response Code: $CURL_HEADER_RESPONSE - Response Body: $CURL_BODY_RESPONSE\n"
            fi
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

    curl_command="$curl_command -H 'Expect:' -i -v $URL_BASE/$API"
    log "$curl_command\n"
}

# Login
dpxlogin() {
    local FUNC="${FUNCNAME[0]}"

    # Read base64 encoded username and password from CONFIG file
    local ENCODED_USERNAME
    ENCODED_USERNAME=$(head -n 1 "CONFIG") # Read first line
    local ENCODED_PASSWORD
    ENCODED_PASSWORD=$(sed -n '2p' "CONFIG") # Read second line

    # Decode the base64 username and password
    local USERNAME
    USERNAME=$(echo "$ENCODED_USERNAME" | base64 --decode)
    local PASSWORD
    PASSWORD=$(echo "$ENCODED_PASSWORD" | base64 --decode)

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
    LOGIN_RESPONSE=$(eval "$curl_command" 2>/dev/null)

    split_response "$LOGIN_RESPONSE"
    check_response_error "$FUNC" "$API" "$IGN_ERROR"

    local LOGIN_VALUE
    LOGIN_VALUE=$(echo "$CURL_BODY_RESPONSE" | jq -r '.errorMessage')
    check_response_value "$LOGIN_VALUE" "$IGN_ERROR"

    TOKEN=$(echo "$CURL_BODY_RESPONSE" | jq -r '.Authorization')
    AUTH_HEADER="Authorization: $TOKEN"
    log "$USERNAME logged in successfully with token $TOKEN\n"
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
        LOGOUT_RESPONSE=$(eval "$curl_command" 2>/dev/null)
        split_response "$LOGOUT_RESPONSE"
        log "Response Code: $CURL_HEADER_RESPONSE - Response Body: $CURL_BODY_RESPONSE\n"
        log "Logged out successfully with token $TOKEN\n"
    fi
}

add_domains() {
    local domainJson="$1"

    if [ -z "$domainJson" ]; then
        log "Error: Could not read or parse domain JSON content.\n"
        return 1
    fi

    local FUNC="${FUNCNAME[0]}"
    local URL_BASE_ARG="$MASKING_ENGINE/masking/api/$apiVer"
    local API='domains'
    local METHOD="POST"
    local AUTH="$AUTH_HEADER"
    local CONTENT_TYPE="application/json"
    local FORM_ARG=""
    local DATA_ARG
    DATA_ARG=$(echo "$domainJson" | jq -c .)

    local domainName
    domainName=$(echo "$DATA_ARG" | jq -r '.domainName')
    log "Adding Domain $domainName ...\n"

    build_curl "$URL_BASE_ARG" "$API" "$METHOD" "$AUTH" "$CONTENT_TYPE" "$KEEPALIVE" "$PROXY_BYPASS" "$HttpsInsecure" "$FORM_ARG" "$DATA_ARG"

    local ADD_DOMAINS_RESPONSE
    ADD_DOMAINS_RESPONSE=$(eval "$curl_command" 2>/dev/null)

    split_response "$ADD_DOMAINS_RESPONSE"
    check_response_error "$FUNC" "$API" "$IGN_ERROR"

    local ADD_DOMAINS_VALUE
    ADD_DOMAINS_VALUE=$(echo "$CURL_BODY_RESPONSE" | jq -r '.domainName')
    check_response_value "$ADD_DOMAINS_VALUE" "$IGN_ERROR"

    if [ ! "$ADD_DOMAINS_VALUE" == "null" ]; then
        log "Domain: $ADD_DOMAINS_VALUE added.\n"
    else
        log "Domain NOT added.\n"
    fi
}

check_packages

while getopts ":hd:i:o:x:k:" PARAMETERS; do
    case $PARAMETERS in
        h)
            show_help
            ;;
        d)
            DOMAIN_FILE=${OPTARG[*]};
            ;;
        i)
            IGN_ERROR=${OPTARG[*]};
            ;;
        o)
            logFileName=${OPTARG[*]};
            ;;
        x)
            PROXY_BYPASS=${OPTARG[*]};
            ;;
        k)
            HttpsInsecure=${OPTARG[*]};
            ;;

        :) echo "Error: La opción -$OPTARG requiere un argumento."; exit 1;;
        *) echo "Error: Opción no reconocida -$OPTARG"; exit 1;;
    esac
done

# Shift positional parameters so that getopts doesn't re-process them
shift $((OPTIND-1))

if [ ! -f "CONFIG" ]; then
    echo "CONFIG file not found!"
    exit 1
fi

MASKING_ENGINE=$(sed -n '3p' CONFIG)

# Check connection
check_conn "$MASKING_ENGINE" "$PROXY_BYPASS" "$HttpsInsecure"

check_csvf "$DOMAIN_FILE" "$IGN_ERROR"

dpxlogin

while read -r line
do
    # Eliminar comillas de la línea completa
    clean_line=$(echo "$line" | tr -d '"')

    # Usar IFS para dividir la línea limpia
    IFS=';' read -r jsonName <<< "$clean_line"

    if [[ ! "$jsonName" =~ "#" ]];
    then
        # Construir la ruta completa al archivo JSON
        json_file_path="$jsonName"

        check_jsonf "$json_file_path" "$IGN_ERROR"

        log "Processing file: $json_file_path\n"

        # Leer el contenido del JSON
        current_domain_json=$(cat "$json_file_path")

        # Check if defaultTokenizationCode is empty and remove it if so
        default_tokenization_code=$(echo "$current_domain_json" | jq -r '.defaultTokenizationCode')
        if [ -z "$default_tokenization_code" ]; then
            current_domain_json=$(echo "$current_domain_json" | jq 'del(.defaultTokenizationCode)')
        fi

        # Llamar a la función add_domains con el payload JSON final
        add_domains "$current_domain_json"
    fi
done < "$DOMAIN_FILE"

dpxlogout
