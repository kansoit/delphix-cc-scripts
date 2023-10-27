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


show_help() {
    echo "Usage: dpxcc_setup_algorithms.sh [options]"
    echo "Options:"
    echo "  --algorithms-file   -a  File containing Algorithms            - Required value"
    echo "  --ignore-errors     -i  Ignore errors while adding Algorithms - Default Value: false"
    echo "  --log-file          -o  Log file name                         - Default Value: Current date_time.log"
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
    curl_timeout=$(curl -s -v -m 5 -o /dev/null http://"$MASKING_ENGINE" 2>&1 | grep "timed out")
    if [[ "$curl_timeout" == *"timed out"* ]];
    then
       log "Error: $curl_timeout\n"
       log "Please verify if the Masking IP Address $MASKING_ENGINE is correct.\n"
       log "Execute curl -s -v -m 5 -o /dev/null http://$MASKING_ENGINE and check the output to verify communications issues between this machine and the Masking Engine.\n"
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

upload_files() {
    local FILE_NAME="$1"
    local FILE_TYPE="$2"
    local FORM="file=@$FILE_NAME;type=$FILE_TYPE"
    local FUNC='upload_files'
    local API='file-uploads?permanent=false'
    local FILE_UPLOADS_RESPONSE=$(curl -X POST -H ''"$AUTH_HEADER"'' -H 'Content-Type:  multipart/form-data' -x "" --keepalive-time "$KEEPALIVE" --form "$FORM" -s "$URL_BASE/$API")
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
    local API='algorithms'

    #### SECURE LOOKUP FRAMEWORK=26 PLUGIN= 7 - Don't touch. It's working - ####
    if [[ "$frameworkId" == "26" && "$pluginId" == "7" ]];
    then
        local lookupFile="{\"uri\": \"$uri\"}"
        local algorithmExtension="{\"hashMethod\": \"$hashMethod\", \"lookupFile\": $lookupFile"
        local DATA="{\"algorithmName\": \"$algorithmName\", \"algorithmType\": \"$algorithmType\", \"description\": \"$description\",
                     \"frameworkId\": \"$frameworkId\", \"pluginId\": \"$pluginId\", \"algorithmExtension\": $algorithmExtension,
                     \"maskedValueCase\": \"$maskedValueCase\", \"inputCaseSensitive\": \"$inputCaseSensitive\",
                     \"trimWhitespaceFromInput\": \"$trimWhitespaceFromInput\", \"trimWhitespaceInLookupFile\": \"$trimWhitespaceInLookupFile\"}}"
    fi

    local ADD_ALGO_RESPONSE=$(curl -X POST -H ''"$AUTH_HEADER"'' -H 'Content-Type: application/json' -x "" --keepalive-time "$KEEPALIVE" --data "$DATA" -s "$URL_BASE/$API")
    check_error "$FUNC" "$API" "$ADD_ALGO_RESPONSE" "$IGN_ERROR"
    ADD_ALGO_VALUE=$(echo "$ADD_ALGO_RESPONSE" | jq -r '.reference')
    check_response "$ADD_ALGO_VALUE" "$IGN_ERROR"
    log "Algorithm: $ADD_ALGO_VALUE $TEST.\n"
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

    #### NAME FRAMEWORK=25 PLUGIN= 7 - Don't touch. It's working - ####
    if [[ "$frameworkId" == "25" && "$pluginId" == "7" ]];
    then
        local lookupFile="{\"uri\": \"$uri\"}"
        local algorithmExtension="{\"lookupFile\": $lookupFile"
        local DATA="{\"algorithmName\": \"$algorithmName\", \"algorithmType\": \"$algorithmType\", \"description\": \"$description\",
                     \"frameworkId\": \"$frameworkId\", \"pluginId\": \"$pluginId\", \"algorithmExtension\": $algorithmExtension,
                     \"maskedValueCase\": \"$maskedValueCase\", \"filterAccent\": \"$filterAccent\", \"inputCaseSensitive\": \"$inputCaseSensitive\",
                     \"maxLengthOfMaskedName\": \"$maxLengthOfMaskedName\"}}"
    fi

    local ADD_ALGO_RESPONSE=$(curl -X POST -H ''"$AUTH_HEADER"'' -H 'Content-Type: application/json' -x "" --keepalive-time "$KEEPALIVE" --data "$DATA" -s "$URL_BASE/$API")
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
    local API='algorithms'

    #### FULLNAME FRAMEWORK=5 PLUGIN=7  --- Don't touch. It's working --- ####
    if [[ "$frameworkId" == "5" && "$pluginId" == "7" ]];
    then
        lastNameAlgRef="{\"name\": \"$lastNameAlgorithmRef\"}"
        firstNameAlgRef="{\"name\": \"$firstNameAlgorithmRef\"}"
        algorithmExtension="{\"lastNameAtTheEnd\": $lastNameAtTheEnd, \"lastNameSeparators\": [$lastNameSeparators], \"maxNumberFirstNames\": $maxNumberFirstNames,
                             \"lastNameAlgorithmRef\": $lastNameAlgRef, \"firstNameAlgorithmRef\": $firstNameAlgRef"
        DATA="{\"algorithmName\": \"$algorithmName\", \"algorithmType\": \"$algorithmType\", \"description\": \"$description\",
               \"frameworkId\": $frameworkId, \"pluginId\": $pluginId, \"algorithmExtension\": $algorithmExtension,
               \"maxLengthOfMaskedName\": $maxLengthOfMaskedName, \"ifSingleWordConsiderAsLastName\": $ifSingleWordConsiderAsLastName}}"
    fi

    local ADD_ALGO_RESPONSE=$(curl -X POST -H ''"$AUTH_HEADER"'' -H 'Content-Type: application/json' -x "" --keepalive-time "$KEEPALIVE" --data "$DATA" -s "$URL_BASE/$API")
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
    local API='algorithms'

    #### FULLNAME FRAMEWORK=10 PLUGIN=7  --- Don't touch. It's working ----- ####
    if [[ "$frameworkId" == "10" && "$pluginId" == "7" ]];
    then
        local lookupFile="{\"uri\": \"$uri\"}"
        local algorithmExtension="{\"preserve\": \"$preserve\", \"minMaskedPositions\": $minMaskedPositions"
        local DATA="{\"algorithmName\": \"$algorithmName\", \"algorithmType\": \"$algorithmType\", \"description\": \"$description\",
                     \"frameworkId\": \"$frameworkId\", \"pluginId\": \"$pluginId\", \"algorithmExtension\": $algorithmExtension}}"
    fi

    local ADD_ALGO_RESPONSE=$(curl -X POST -H ''"$AUTH_HEADER"'' -H 'Content-Type: application/json' -x "" --keepalive-time "$KEEPALIVE" --data "$DATA" -s "$URL_BASE/$API")
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
    local API='algorithms'

    #### FULLNAME FRAMEWORK=21 PLUGIN=7  --- Don't touch. It's working ----- ####
    if [[ "$frameworkId" == "21" && "$pluginId" == "7" ]];
    then
        preserveRanges="{\"start\": $start, \"length\": $length, \"direction\": \"$direction\"}"
        algorithmExtension="{\"caseSensitive\": $caseSensitive, \"preserveRanges\": [$preserveRanges], \"characterGroups\":  [\"$characterGroups\"],
                             \"minMaskedPositions\": $minMaskedPositions, \"preserveLeadingZeros\": $preserveLeadingZeros"
        DATA="{\"algorithmName\": \"$algorithmName\", \"algorithmType\": \"$algorithmType\", \"description\": \"$description\",
               \"frameworkId\": $frameworkId, \"pluginId\": $pluginId, \"algorithmExtension\": $algorithmExtension}}"
    fi

    local ADD_ALGO_RESPONSE=$(curl -X POST -H ''"$AUTH_HEADER"'' -H 'Content-Type: application/json' -x "" --keepalive-time "$KEEPALIVE" --data "$DATA" -s "$URL_BASE/$API")
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
    local API='algorithms'

    #### FULLNAME FRAMEWORK=22 PLUGIN=7  --- Don't touch. It's working --- ####
    if [[ "$frameworkId" == "22" && "$pluginId" == "7" ]];
    then
        nameAlgo="{\"name\": \"$nameAlgorithm\"}"
        domainAlgo="{\"name\": \"$domainAlgorithm\"}"
        algorithmExtension="{\"nameAction\": \"$nameAction\", \"domainAction\": \"$domainAction\", \"nameAlgorithm\": $nameAlgo,
                             \"nameLookupFile\": $nameLookupFile, \"domainAlgorithm\": $domainAlgo,
                             \"domainReplacementString\": $domainReplacementString}"
        DATA="{\"algorithmName\": \"$algorithmName\", \"algorithmType\": \"$algorithmType\", \"description\": \"$description\",
               \"frameworkId\": $frameworkId, \"pluginId\": $pluginId, \"algorithmExtension\": $algorithmExtension}"
    fi

    local ADD_ALGO_RESPONSE=$(curl -X POST -H ''"$AUTH_HEADER"'' -H 'Content-Type: application/json' -x "" --keepalive-time "$KEEPALIVE" --data "$DATA" -s "$URL_BASE/$API")
    check_error "$FUNC" "$API" "$ADD_ALGO_RESPONSE" "$IGN_ERROR"
    ADD_ALGO_VALUE=$(echo "$ADD_ALGO_RESPONSE" | jq -r '.reference')
    check_response "$ADD_ALGO_VALUE" "$IGN_ERROR"
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
        --ignore-errors)
            args="${args}-i "
            ;;
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

while getopts ":h:a:i:o:m:u:p:" PARAMETERS; do
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

# Check connection
check_conn

if [[ "$ALGO_FILE" == *"sl_"* ]];
then 
    check_file "$ALGO_FILE" "$IGN_ERROR"
    dpxlogin "$MASKING_USERNAME" "$MASKING_PASSWORD"
    log "Creating Algorithms with Secure Lookup Framework\n"
    while IFS=\; read -r algorithmName algorithmType description frameworkId pluginId hashMethod maskedValueCase inputCaseSensitive\
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
    dpxlogin "$MASKING_USERNAME" "$MASKING_PASSWORD"
    check_file "$ALGO_FILE" "$IGN_ERROR"
    log "Creating Algorithms with Name Framework\n"
    while IFS=\; read -r algorithmName algorithmType description frameworkId pluginId maskedValueCase inputCaseSensitive\
                         filterAccent maxLengthOfMaskedName fileName fileType
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

if [[ "$ALGO_FILE" == *"nmfull_"* ]];
then
    dpxlogin "$MASKING_USERNAME" "$MASKING_PASSWORD"
    check_file "$ALGO_FILE" "$IGN_ERROR"
    log "Creating Algorithms with Full Name Framework\n"
    while IFS=\; read -r algorithmName algorithmType description frameworkId pluginId lastNameAtTheEnd \
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
    # Check csv file exists
    check_file "$ALGO_FILE" "$IGN_ERROR"
    dpxlogin "$MASKING_USERNAME" "$MASKING_PASSWORD"
    log "Creating Algorithms with Payment Card Framework\n"
    while IFS=\; read -r algorithmName algorithmType description frameworkId pluginId preserve minMaskedPositions
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
    # Check csv file exists
    check_file "$ALGO_FILE" "$IGN_ERROR"
    dpxlogin "$MASKING_USERNAME" "$MASKING_PASSWORD"
    log "Creating Algorithms with Character Mapping Framework\n"
    while IFS=\; read -r algorithmName algorithmType description frameworkId pluginId caseSensitive \
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
    # Check csv file exists
    check_file "$ALGO_FILE" "$IGN_ERROR"
    dpxlogin "$MASKING_USERNAME" "$MASKING_PASSWORD"
    log "Creating Algorithms with Email Framework\n"
    while IFS=\; read -r algorithmName algorithmType description frameworkId pluginId nameAction \
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
