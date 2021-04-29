AGENTDESKTOP='User-Agent: cache_warmer'
AGENTMOBILE='User-Agent: cache_warmer iPhone'
SVALUE="0"
WITH_MOBILE='OFF'
WITH_COOKIE='OFF'
COOKIE=''
XML_LIST=()
CURL_OPTS=''
PROTECTOR='OFF'
VERBOSE='OFF'
DEBUGURL='OFF'
BLACKLIST='OFF'
CRAWLQS='OFF'
REPORT='OFF'
CRAWLLOG='/tmp/crawler.log'
BLACKLSPATH='/tmp/blk_crawler.txt'
CT_URLS=0
CT_NOCACHE=0
CT_CACHEHIT=0
CT_CACHEMISS=0
CT_BLACKLIST=0
CT_FAILCACHE=0
DETECT_NUM=0
DETECT_LIMIT=10
ERR_LIST="'400'|'401'|'403'|'404'|'407|'500'|'502'"

function help_message() {
case ${1} in

    "1")
        cat <<EOF
        Server crawler engine not enabled. Please check
        Stop crawling...
EOF
    ;;
    "2")
        cat <<EOF

        Important:
        Valid xml file and allow LSCache cawler are needed

        0. bash cachecrawler.sh -h                 ## help
        Example:
        1. bash cachecrawler.sh SITE-MAP-URL       ## When desktop and mobile share same theme
        2. bash cachecrawler.sh -m SITE-MAP-URL    ## When desktop & mobile have different theme
        3. bash cachecrawler.sh -c SITE-MAP-URL    ## For brining cookies case
        4. bash cachecrawler.sh -b -c SITE-MAP-URL ## For brining cookies case and blacklist check

        Debug example:
        1. bash cachecrawler.sh -v SITE-MAP-URL    ## To output details to crawler log
        2. bash cachecrawler.sh -d SITE-URL        ## Debug one URL directly
        3. bash cachecrawler.sh -b -c -d SITE-URL  ## Debug one URL with cookies and blacklist check

        ## Example for SITE-MAP-URL, http://magento.com/sitemap.xml

        Optional Arguments:
        -h, --help          Show this message and exit
        -m, --with-mobile   Crawl mobile view in addition to default view
        -c, --with-cookie   Crawl with site's cookies
        -b, --black-list    Page will be added to black list if html status error and no cache. Next run will bypas page
        -g, --general-ua    Use general user-agent instead of lscache_runner for desktop view
        -i, --interval      Change request interval. "-i 0.2" changes from default 0.1s to 0.2s
        -v, --verbose       Show complete response header under /tmp/crawler.log
        -d, --debug-url     Test one URL directly. "sh M2-crawler.sh -v -d http://example.com/test.html"
        -qs,--crawl-qs      Crawl sitemap, including URLS with query strings
        -r, --report        Display total count of crawl result
EOF
    ;;
    esac
exit 1
}


function checkcurlver(){
    curl --help | grep 'Use HTTP 2' > /dev/null
    if [ ${?} = 0 ]; then
        CURL_OPTS='--http1.1'
    fi    
}
### Curl with version1 only
checkcurlver

function excludecookie(){
    ### Check if cloudflare
    if [[ $(echo "${1}" | grep -i 'Server: cloudflare') ]]; then 
        CURLRESULT=$(echo "${1}" | grep -Ev 'Set-Cookie.*__cfduid')
    fi 
}

function duplicateck(){
    grep -w "${1}" ${2} >/dev/null 2>&1
}

function cachecount(){
    if [ ${1} = 'miss' ]; then 
        CT_CACHEMISS=$((CT_CACHEMISS+1))
    elif [ ${1} = 'hit' ]; then
        CT_CACHEHIT=$((CT_CACHEHIT+1))
    elif [ ${1} = 'no' ]; then   
        CT_NOCACHE=$((CT_NOCACHE+1))        
    elif [ ${1} = 'black' ]; then   
        CT_BLACKLIST=$((CT_BLACKLIST+1))
    elif [ ${1} = 'fail' ]; then 
        CT_FAILCACHE=$((CT_FAILCACHE+1))    
    elif [[ ${1} =~ ^[0-9]+$ ]]; then
        CT_URLS=$((CT_URLS+${1}))
    else
        echo "${1} no define to cachecount!"    
    fi    
}

prttwostr(){
    printf "\033[38;5;71m%s\033[39m \t%s\t \033[1;30m%s\033[0m \n" "${1}" "${2}" "${3}"
}

function cachereport(){
    echo '=====================Crawl result:======================='
    prttwostr "Total URLs :" "${CT_URLS}" ''
    prttwostr "Added      :" "${CT_CACHEMISS}" ''
    prttwostr "Existing   :" "${CT_CACHEHIT}" ''
    if [ "${CT_NOCACHE}" -gt 0 ]; then
        TMPMESG="(Page with 'no cache', please check cache debug log for the reason)"
    else
        TMPMESG=''
    fi 
    prttwostr "Skipped    :" "${CT_NOCACHE}" "${TMPMESG}"
    if [ "${BLACKLIST}" != 'OFF' ]; then
        if [ "${CT_BLACKLIST}" -gt 0 ]; then
            TMPMESG="(Pages with status code ${ERR_LIST} may add into blacklist)"
        else
            TMPMESG=''    
        fi
        prttwostr "Blacklisted:" "${CT_BLACKLIST}" "${TMPMESG}"
    fi    
    if [ "${CT_FAILCACHE}" -gt 0 ]; then
        TMPMESG="(Pages with status code ${ERR_LIST} may add into blacklist)"
    else
        TMPMESG=''    
    fi 
    prttwostr "Failed     :" "${CT_FAILCACHE}" "${TMPMESG}"
}

function protect_count(){
    if [ "${PROTECTOR}" = 'ON' ]; then
        if [ ${1} -eq 1 ]; then 
            DETECT_NUM=$((DETECT_NUM+1))
            if [ ${DETECT_NUM} -ge ${DETECT_LIMIT} ]; then
                echo "Hit ${DETECT_LIMIT} times 'page error' or 'no cache' in a row, abort !!"
                echo "To run script with no abort, please set PROTECTOR from 'ON' to 'OFF'."
                exit 1
            fi
        elif [ ${1} -eq 0 ]; then 
            DETECT_NUM=0
        fi
    fi
}
function addtoblacklist(){
    echo "Add ${1} to BlackList"
    echo "${1}" >> ${BLACKLSPATH}  
}

function debugurl_display(){
    echo ''
    echo "-------Debug curl start-------"
    echo "URL: ${2}"
    echo "AGENTDESKTOP: ${1}" 
    echo "COOKIE: ${3}"
    echo "${4}"
    echo "-------Debug curl end-------"
    echo "Header Match: ${5}" 
}

function crawl_verbose(){
    echo "URL: ${2}" >> ${CRAWLLOG}
    echo "AGENTDESKTOP: ${1}" >> ${CRAWLLOG}
    echo "COOKIE: ${3}" >> ${CRAWLLOG}      
    echo "${4}" >> ${CRAWLLOG}
    echo "Header Match: ${5}" >> ${CRAWLLOG}
    echo "----------------------------------------------------------" >> ${CRAWLLOG}   
}
function crawlreq() {
    if [ "${DEBUGURL}" != "OFF" ] && [ "${BLACKLIST}" = 'ON' ]; then
        duplicateck ${2} ${BLACKLSPATH}
        if [ ${?} = 0 ]; then
            echo "${2} is in blacklist"
            exit 0
        fi    
    fi
    echo "${2} -> " | tr -d '\n'
    CURLRESULT=$(curl ${CURL_OPTS} -siLk -b name="${3}" -X GET -H "${1}" ${2} | tac | tac | sed '/Server: /q')
    excludecookie "${CURLRESULT}"
    STATUS_CODE=$(echo "${CURLRESULT}" | grep HTTP | awk '{print $2}')

    CHECKMATCH=$(echo ${STATUS_CODE} | grep -Eio "$(echo ${ERR_LIST} | tr -d "'")")
    if [ "${CHECKMATCH}" == '' ]; then
        CHECKMATCH=$(grep -Eio '(x-lsadc-cache: hit,litemage|x-lsadc-cache: hit|x-lsadc-cache: miss|x-qc-cache: hit|x-qc-cache: miss|CF-Cache-Status: HIT|CF-Cache-Status: MISS|CF-Cache-Status: DYNAMIC)'\
        <<< ${CURLRESULT} | tr -d '\n')
    fi    
    if [ "${CHECKMATCH}" == '' ]; then
        CHECKMATCH=$(grep -Eio '(X-LiteSpeed-Cache: miss|X-Litespeed-Cache: hit|X-Litespeed-Cache-Control: no-cache)'\
        <<< ${CURLRESULT} | tr -d '\n')
    fi
    if [ "${CHECKMATCH}" == '' ]; then
        CHECKMATCH=$(grep -Eio '(lsc_private|HTTP/1.1 201 Created)'\
        <<< ${CURLRESULT} | tr -d '\n')
    fi    
    if [ ${VERBOSE} = 'ON' ]; then
        crawl_verbose "${1}" "${2}" "${3}" "${CURLRESULT}" "${CHECKMATCH}"
    fi    
    if [[ ${DEBUGURL} != "OFF" ]]; then
        debugurl_display "${1}" "${2}" "${3}" "${CURLRESULT}" "${CHECKMATCH}"
    fi
    case ${CHECKMATCH} in
        'CreatedSet-CookieSet-CookieSet-Cookie'|[Xx]-[Ll]ite[Ss]peed-[Cc]ache:\ miss|'X-LSADC-Cache: miss'|[Cc][Ff]-[Cc]ache-[Ss]tatus:\ MISS|[Xx]-[Qq][Cc]-[Cc]ache:\ miss)
            echo 'Caching'
            cachecount 'miss'
            protect_count 0
        ;;
        'HTTP/1.1 201 Created')
            if [ $(echo ${CURLRESULT} | grep -i 'Cookie' | wc -l ) != 0 ]; then
                if [[ ${DEBUGURL} != "OFF" ]]; then
                    echo "Set-Cookie found"
                fi    
                echo 'Caching'
                cachecount 'miss'
            else
                echo 'Already cached'
                cachecount 'hit'
            fi
            protect_count 0
        ;;
        [Xx]-[Ll]ite[Ss]peed-Cache:\ hit|'x-lsadc-cache: hit'|'x-lsadc-cache: hit,litemage'|'CF-Cache-Status: HIT'|[Cc][Ff]-[Cc]ache-[Ss]tatus:\ HIT)
            echo 'Already cached'
            cachecount 'hit'
            protect_count 0
        ;;
        'HTTP/1.1 201 Createdlsc_private')
            echo 'Caching'
            cachecount 'miss'
            protect_count 0
        ;;
        '400'|'401'|'403'|'404'|'407'|'500'|'502')
            echo "STATUS: ${CHECKMATCH}, can not cache"
            cachecount 'fail'
            protect_count 1
            if [ "${BLACKLIST}" = 'ON' ]; then
                addtoblacklist ${2}
            fi
        ;;        
        CF-Cache-Status:\ no-cache|[Cc][Ff]-[Cc]ache-[Ss]tatus:\ DYNAMIC|'CF-Cache-Status: DYNAMIC')
            echo 'No Cache page'
            cachecount 'no'
            protect_count 1
            ### To add 'no cache' page to black list, remove following lines' comment
            #if [ "${BLACKLIST}" = 'ON' ]; then
            #    addtoblacklist ${2}
            #fi
        ;;
        *)
            echo 'No Need To Cache'
            cachecount 'no'
        ;;
    esac
}

function runLoop() {
    for URL in ${URLLIST}; do
        local ONLIST='NO'
        if [ "${BLACKLIST}" = 'ON' ]; then 
            duplicateck ${URL} ${BLACKLSPATH}
            if [ ${?} -eq 0 ]; then
                ONLIST='YES'
                cachecount 'black'
            fi    
        fi   
        if [ "${ONLIST}" = 'NO' ]; then
            crawlreq "${1}" "${URL}" "${2}" 
            sleep ${SVALUE}
        fi    
    done
}

function validmap(){
    CURL_CMD="curl -I -w httpcode=%{http_code}"
    CURL_MAX_CONNECTION_TIMEOUT="-m 100"
    CURL_RETURN_CODE=0
    CURL_OUTPUT=$(${CURL_CMD} ${CURL_MAX_CONNECTION_TIMEOUT} ${SITEMAP} 2> /dev/null) || CURL_RETURN_CODE=$?
    if [ ${CURL_RETURN_CODE} -ne 0 ]; then
        echo "Curl connection failed with return code - ${CURL_RETURN_CODE}, exit"
        exit 1
    else
        HTTPCODE=$(echo "${CURL_OUTPUT}" | grep 'HTTP'| awk '{print $2}')
        if [ "${HTTPCODE}" != '200' ]; then
            echo "Curl operation/command failed due to server return code - ${HTTPCODE}, exit"
            exit 1
        fi
        echo "SiteMap connection success \n"
    fi
}

function checkcrawler() {
    TRYURL=$(echo ${URLLIST} | cut -d " " -f1)
    CRAWLRESULT=$(curl ${CURL_OPTS} -sI -X GET -H "${AGENTDESKTOP}" $TRYURL| grep -o "Precondition Required")
    if [ "${CRAWLRESULT}" = 'Precondition Required' ]; then
        help_message 1
    fi
}

function genrandom(){
    RANDOMSTR=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 16 ; echo '')
}

function getcookie() {
    for URL in ${URLLIST}; do
        local ONLIST='NO'
        if [ "${BLACKLIST}" = 'ON' ]; then 
            duplicateck ${URL} ${BLACKLSPATH}
            if [ ${?} -eq 1 ]; then
                break
            fi    
        fi
    done       
    COOKIESTRING=$(curl ${CURL_OPTS} -sILK -X GET ${URL} | grep 'Set-Cookie' | awk '{print $2}' | tr '\n' ' ')
    if [ "${COOKIESTRING}" = '' ]; then
        genrandom
        COOKIESTRING=$(curl ${CURL_OPTS} -sILK -X GET ${URL}?${RANDOMSTR} | grep 'Set-Cookie' | awk '{print $2}' | tr '\n' ' ')
    fi
    COOKIE="${COOKIESTRING}"
}

function debugurl() {
    if [ "${WITH_COOKIE}" = 'ON' ]; then
        getcookie
    fi    
    if [ "${WITH_MOBILE}" = 'ON' ]; then
        crawlreq "${AGENTMOBILE}" "${1}" "${COOKIE}"
    else
        crawlreq "${AGENTDESKTOP}" "${1}" "${COOKIE}"
    fi      
}

function storexml() {
    validmap
    if [ $(echo ${1} | grep '\.xml$'|wc -l) != 0 ]; then
        XML_URL=$(curl ${CURL_OPTS} -sk ${1}| grep '<loc>' | grep '\.xml' | sed -e 's/.*<loc>\(.*\)<\/loc>.*/\1/')
        XML_NUM=$(echo ${XML_URL} | grep '\.xml' | wc -l)
        if [ ${XML_NUM} -gt 0 ]; then
            for URL in $XML_URL; do
                XML_LIST=(${URL} "${XML_LIST[@]}")
            done
        else
            XML_LIST=(${1} "${XML_LIST[@]}")
        fi
    else
        echo "SITEMAP: $SITEMAP is not a valid xml"
        help_message 2
    fi
}

function maincrawl() { 
    checkcrawler
    echo "There are ${URLCOUNT} urls in this sitemap"
    if [ ${URLCOUNT} -gt 0 ]; then
        START_TIME="$(date -u +%s)"
        echo 'Starting to view with desktop agent...'
        if [ "${WITH_COOKIE}" = 'ON' ]; then
            getcookie
        fi
        cachecount ${URLCOUNT}    
        runLoop "${AGENTDESKTOP}" "${COOKIE}"
        if [ "${WITH_MOBILE}" = 'ON' ]; then
            echo 'Starting to view with mobile agent...'
            cachecount ${URLCOUNT}
            runLoop "${AGENTMOBILE}" "${COOKIE}"
        fi             
        END_TIME="$(date -u +%s)"
        ELAPSED="$((${END_TIME}-${START_TIME}))"
        echo "***Total of ${ELAPSED} seconds to finish process***"

    fi
}

function main(){
    if [ "${DEBUGURL}" != 'OFF' ]; then
        debugurl ${DEBUGURL}
    else
        for XMLURL in "${XML_LIST[@]}"; do
            echo "Prepare to crawl ${XMLURL} XML file"
            if [ "${CRAWLQS}" = 'ON' ]; then
                URLLIST=$(curl ${CURL_OPTS} --silent ${XMLURL} | sed -e 's/\/url/\n/g'| grep '<loc>' | \
                    sed -e 's/.*<loc>\(.*\)<\/loc>.*/\1/' | sed 's/<!\[CDATA\[//;s/]]>//' | \
                    grep -iPo '^((?!png|jpg|webp).)*$' | sort -u)
            else
                URLLIST=$(curl ${CURL_OPTS} --silent ${XMLURL} | sed -e 's/\/url/\n/g'| grep '<loc>' | \
                    sed -e 's/.*<loc>\(.*\)<\/loc>.*/\1/' | sed 's/<!\[CDATA\[//;s/]]>//;s/.*?.*//' | \
                    grep -iPo '^((?!png|jpg|webp).)*$' | sort -u)
            fi
            URLCOUNT=$(echo "${URLLIST}" | grep -c '[^[:space:]]')
            maincrawl
        done
        if [ "${REPORT}" != 'OFF' ]; then
            cachereport
        fi    
    fi    
}

while [ ! -z "${1}" ]; do
    case ${1} in
        -h | --help)
            help_message 2
        ;;
        -m | --with-mobile | --mobile)
            WITH_MOBILE='ON'
        ;;
        -c | --with-cookie | --cookie)
            WITH_COOKIE='ON'
        ;;        
        -i | --interval)  shift
            SVALUE=${1}
        ;;
        -g| --general-ua)
            AGENTDESKTOP='User-Agent: general_purpose'
        ;;
        -v | --verbose)
            VERBOSE='ON'
        ;;
        -b | --black-list)
            BLACKLIST='ON'
            if [ ! -e ${BLACKLSPATH} ]; then
                touch ${BLACKLSPATH}
            fi
        ;;
        -d | --debug-url) shift
            if [ "${1}" = '' ]; then
                help_message 2
            else
                DEBUGURL="${1}" 
                URLLIST="${1}"
                if [ ! -e ${CRAWLLOG} ]; then
                    touch ${CRAWLLOG}
                fi
            fi        
        ;;
        -qs | --crawl-qs)
            CRAWLQS='ON'           
        ;;    
        -r | --report)
            REPORT='ON'
        ;;    
        *)
            SITEMAP=${1}
            storexml ${SITEMAP}
        ;;
    esac
    shift
done
main

