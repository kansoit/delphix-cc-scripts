#!/bin/bash


MASKING_ENGINE=""
MASKING_USERNAME=""
MASKING_PASSWORD=""
URL_BASE=""
ALGO_FILE=""
KEEPALIVE=300
LOG_FILE='dpxcc_setup_algorithms.log'

show_help() {
    echo "Usage: dpxcc_setup_algorithms.sh [options]"
    echo "Options:"
    echo "  --algorithms-file   -a  File containing Algorithms   - Required value"
    echo "  --masking-engine    -m  Masking Engine Address       - Required value"
    echo "  --masking-username  -u  Masking Engine User Name     - Required value"
    echo "  --masking-pwd       -p  Masking Engine Password      - Required value"
    echo "  --help              -h  Show this help"
    echo "Example:"
    echo "dpxcc_setup_profileset.sh -a algorithms.csv -m <MASKING IP> -u <MASKING User> -p <MASKING Password>" 
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

upload_files() {
    local FILE_NAME="$1"
    local FILE_TYPE="$2"
    local FORM="file=@$FILE_NAME;type=$FILE_TYPE"
    local FUNC='upload_files'
    local API='file-uploads?permanent=false'
    local FILE_UPLOADS_RESPONSE=$(curl -X POST -H ''"$AUTH_HEADER"'' -H 'Content-Type:  multipart/form-data' --keepalive-time "$KEEPALIVE" --form "$FORM" -s "$URL_BASE/$API")
    check_error "$FUNC" "$API" "$FILE_UPLOADS_RESPONSE"
    FILE_UPLOADS_VALUE=$(echo "$FILE_UPLOADS_RESPONSE" | jq -r '.filename')
    check_response "$FILE_UPLOADS_VALUE"
    fileReferenceId=$(echo "$FILE_UPLOADS_RESPONSE" | jq -r '.fileReferenceId')
    log "File: $FILE_UPLOADS_VALUE added with ID: $fileReferenceId\n"
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
    local API='algorithms'

    #### SECURE LOOKUP FRAMEWORK=26 PLUGIN= 7 - OK NO TOCAR - ####
    if [[ "$frameworkId" == "26" && "$pluginId" == "7" ]]
    then
        local lookupFile="{\"uri\": \"$uri\"}"
        local algorithmExtension="{\"hashMethod\": \"$hashMethod\", \"lookupFile\": $lookupFile"
        local DATA="{\"algorithmName\": \"$algorithmName\", \"algorithmType\": \"$algorithmType\", \"description\": \"$description\",
                     \"frameworkId\": \"$frameworkId\", \"pluginId\": \"$pluginId\", \"algorithmExtension\": $algorithmExtension,
                     \"maskedValueCase\": \"$maskedValueCase\", \"inputCaseSensitive\": \"$inputCaseSensitive\",
                     \"trimWhitespaceFromInput\": \"$trimWhitespaceFromInput\", \"trimWhitespaceInLookupFile\": \"$trimWhitespaceInLookupFile\"}}"
    fi
    
    local ADD_ALGO_RESPONSE=$(curl -X POST -H ''"$AUTH_HEADER"'' -H 'Content-Type: application/json' --keepalive-time "$KEEPALIVE" --data "$DATA" -s "$URL_BASE/$API")
    check_error "$FUNC" "$API" "$ADD_ALGO_RESPONSE"
    ADD_ALGO_VALUE=$(echo "$ADD_ALGO_RESPONSE" | jq -r '.reference')
    check_response "$ADD_ALGO_VALUE"
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
    local API='algorithms'
   
    #### NAME FRAMEWORK=25 PLUGIN= 7 - OK NO TOCAR - ####
    if [[ "$frameworkId" == "25" && "$pluginId" == "7" ]]
    then
        local lookupFile="{\"uri\": \"$uri\"}"
        local algorithmExtension="{\"lookupFile\": $lookupFile"
        local DATA="{\"algorithmName\": \"$algorithmName\", \"algorithmType\": \"$algorithmType\", \"description\": \"$description\",
                     \"frameworkId\": \"$frameworkId\", \"pluginId\": \"$pluginId\", \"algorithmExtension\": $algorithmExtension,
                     \"maskedValueCase\": \"$maskedValueCase\", \"filterAccent\": \"$filterAccent\", \"inputCaseSensitive\": \"$inputCaseSensitive\",
                     \"maxLengthOfMaskedName\": \"$maxLengthOfMaskedName\"}}"
    fi
    
    local ADD_ALGO_RESPONSE=$(curl -X POST -H ''"$AUTH_HEADER"'' -H 'Content-Type: application/json' --keepalive-time "$KEEPALIVE" --data "$DATA" -s "$URL_BASE/$API")
    check_error "$FUNC" "$API" "$ADD_ALGO_RESPONSE"
    ADD_ALGO_VALUE=$(echo "$ADD_ALGO_RESPONSE" | jq -r '.reference')
    check_response "$ADD_ALGO_VALUE"
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
    local API='algorithms'

    #### FULLNAME FRAMEWORK=5 PLUGIN=7  --- OK NO TOCAR --- ####
    if [[ "$frameworkId" == "5" && "$pluginId" == "7" ]]
    then                   
        lastNameAlgRef="{\"name\": \"$lastNameAlgorithmRef\"}"
        firstNameAlgRef="{\"name\": \"$firstNameAlgorithmRef\"}"
        algorithmExtension="{\"lastNameAtTheEnd\": $lastNameAtTheEnd, \"lastNameSeparators\": [$lastNameSeparators], \"maxNumberFirstNames\": $maxNumberFirstNames, 
                             \"lastNameAlgorithmRef\": $lastNameAlgRef, \"firstNameAlgorithmRef\": $firstNameAlgRef"
                             
        DATA="{\"algorithmName\": \"$algorithmName\", \"algorithmType\": \"$algorithmType\", \"description\": \"$description\",
               \"frameworkId\": $frameworkId, \"pluginId\": $pluginId, \"algorithmExtension\": $algorithmExtension,
               \"maxLengthOfMaskedName\": $maxLengthOfMaskedName, \"ifSingleWordConsiderAsLastName\": $ifSingleWordConsiderAsLastName}}"
    fi
    
    local ADD_ALGO_RESPONSE=$(curl -X POST -H ''"$AUTH_HEADER"'' -H 'Content-Type: application/json' --keepalive-time "$KEEPALIVE" --data "$DATA" -s "$URL_BASE/$API")
    check_error "$FUNC" "$API" "$ADD_ALGO_RESPONSE"
    ADD_ALGO_VALUE=$(echo "$ADD_ALGO_RESPONSE" | jq -r '.reference')
    check_response "$ADD_ALGO_VALUE"
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
    local API='algorithms'

    #### FULLNAME FRAMEWORK=10 PLUGIN=7  --- NO TOCAR ----- ####
    if [[ "$frameworkId" == "10" && "$pluginId" == "7" ]]
    then
        local lookupFile="{\"uri\": \"$uri\"}"
        local algorithmExtension="{\"preserve\": \"$preserve\", \"minMaskedPositions\": $minMaskedPositions"
        local DATA="{\"algorithmName\": \"$algorithmName\", \"algorithmType\": \"$algorithmType\", \"description\": \"$description\",
                     \"frameworkId\": \"$frameworkId\", \"pluginId\": \"$pluginId\", \"algorithmExtension\": $algorithmExtension}}"
    fi
    
    local ADD_ALGO_RESPONSE=$(curl -X POST -H ''"$AUTH_HEADER"'' -H 'Content-Type: application/json' --keepalive-time "$KEEPALIVE" --data "$DATA" -s "$URL_BASE/$API")
    check_error "$FUNC" "$API" "$ADD_ALGO_RESPONSE"
    ADD_ALGO_VALUE=$(echo "$ADD_ALGO_RESPONSE" | jq -r '.reference')
    check_response "$ADD_ALGO_VALUE"
    log "Algorithm: $ADD_ALGO_VALUE added.\n"
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

while getopts ":h:a:m:u:p:" PARAMETERS; do
    case $PARAMETERS in
        h)
        	;;
        a)
        	ALGO_FILE=${OPTARG[@]}
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
URL_BASE="http://${MASKING_ENGINE}/masking/api"

# Delete logfile
# rm "$LOG_FILE"

# Login
dpxlogin "$MASKING_USERNAME" "$MASKING_PASSWORD"

log "Creating Algorithms: \n"

if [[ "$ALGO_FILE" == *"sl_"* ]]
then
    while IFS=\; read -r algorithmName algorithmType description frameworkId pluginId hashMethod maskedValueCase inputCaseSensitive\
                         trimWhitespaceFromInput trimWhitespaceInLookupFile fileName fileType
    do
        if [[ ! "$algorithmName" =~ "#" ]]
        then
            # upload_files "$fileName" "$fileType"
            fileReferenceId="delphix-file://upload/f_7ae6eb2cfed040f8a4ae4f0324034a86/Provincias.txt"
            add_sl_algorithms "$algorithmName" "$algorithmType" "$description" "$frameworkId" "$pluginId" "$hashMethod" "$maskedValueCase" "$inputCaseSensitive"\
                              "$trimWhitespaceFromInput" "$trimWhitespaceInLookupFile" "$fileReferenceId"       
        fi
    done < "$ALGO_FILE"
fi

if [[ "$ALGO_FILE" == *"nm_"* ]]
then  
    while IFS=\; read -r algorithmName algorithmType description frameworkId pluginId maskedValueCase inputCaseSensitive\
                         filterAccent maxLengthOfMaskedName fileName fileType                       
    do
        if [[ ! "$algorithmName" =~ "#" ]]
        then
            # upload_files "$FILE_NAME" "$FILE_TYPE"
            fileReferenceId="delphix-file://upload/f_7ae6eb2cfed040f8a4ae4f0324034a86/Provincias.txt"
            add_nm_algorithms "$algorithmName" "$algorithmType" "$description" "$frameworkId" "$pluginId" "$maskedValueCase" "$inputCaseSensitive"\
                              "$filterAccent" "$maxLengthOfMaskedName" "$fileReferenceId"       
        fi
    done < "$ALGO_FILE"
fi

if [[ "$ALGO_FILE" == *"nmfull_"* ]]
then
    while IFS=\; read -r algorithmName algorithmType description frameworkId pluginId lastNameAtTheEnd \
                         lastNameSeparators maxNumberFirstNames lastNameAlgorithmRef firstNameAlgorithmRef maxLengthOfMaskedName\
                         ifSingleWordConsiderAsLastName FileName FileType  
    do
        if [[ ! "$algorithmName" =~ "#" ]]
        then
            # upload_files "$FILE_NAME" "$FILE_TYPE" USO FUTURO
            fileReferenceId="delphix-file://upload/f_7ae6eb2cfed040f8a4ae4f0324034a86/Provincias.txt"
            add_nmfull_algorithms "$algorithmName" "$algorithmType" "$description" "$frameworkId" "$pluginId" "$lastNameAtTheEnd"\
                                  "$lastNameSeparators" "$maxNumberFirstNames" "$lastNameAlgorithmRef" "$firstNameAlgorithmRef" "$maxLengthOfMaskedName"\
                                  "$ifSingleWordConsiderAsLastName" "$lastNameAtTheEnd" "$fileReferenceId"       
        fi
    done < "$ALGO_FILE"
fi

if [[ "$ALGO_FILE" == *"pc_"* ]]
then
    while IFS=\; read -r algorithmName algorithmType description frameworkId pluginId preserve minMaskedPositions
    do
        if [[ ! "$algorithmName" =~ "#" ]]
        then
            add_pc_algorithms "$algorithmName" "$algorithmType" "$description" "$frameworkId" "$pluginId" "$preserve" "$minMaskedPositions"
        fi
    done < "$ALGO_FILE"
fi

# Logout
dpxlogout
