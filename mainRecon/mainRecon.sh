#!/bin/bash

# Colours
red="\e[31m"
green="\e[32m"
yellow="\e[33m"
end="\e[0m"

# Banner
echo -e $yellow"
                  _                 
 ._ _   _. o ._  |_)  _   _  _  ._  
 | | | (_| | | | | \ (/_ (_ (_) | |

By_l34r00t | {v1.0}
@leapintos | leandro@leandropintos.com
"$end

# Usage
Usage() {
    echo -e "$green
Usage: ./mainRecon.sh [-p/--program] hackerone [-f/--file] targets.txt
	"$end
    exit 1
}

# Bot Telegram
bot_token=$token
chat_ID=$chat_ID
url="https://api.telegram.org/bot$bot_token/sendMessage"

# Function
get_subdomains() {
    echo -e $red"[+]"$end $bold"Get Subdomains"$end
    folder=$program-$(date '-I')
    mkdir $folder && cd $folder

    findomain -q -f /mainData/$file -r -u findomain_domains.txt
    cat /mainData/$file | assetfinder --subs-only >>assetfinder_domains.txt
    amass enum -df /mainData/$file -passive -o ammas_passive_domains.txt
    subfinder -dL /mainData/$file -o subfinder_domains.txt
    sort -u *_domains.txt -o subdomains.txt
    cat subdomains.txt | rev | cut -d . -f 1-3 | rev | sort -u | tee root_subdomains.txt
    cat *.txt | sort -u >domains.txt
    find . -type f -not -name 'domains.txt' -delete
}

get_alive() {
    echo -e $red"[+]"$end $bold"Get Alive"$end

    cat domains.txt | httprobe -c 50 -t 3000 >alive.txt
    cat alive.txt | python -c "import sys; import json; print (json.dumps({'domains':list(sys.stdin)}))" >alive.json

    result="cat alive.txt"
    message="[ + ] mainRecon Alert:
    [ --> ] alive.txt for: $program 
    $($result)"
    curl --silent --output /dev/null -F chat_id="$chat_ID" -F "text=$message" $url -X POST
}

get_waybackurl() {
    echo -e $red"[+]"$end $bold"Get Waybackurl"$end

    mkdir waybackdata

    cat alive.txt | waybackurls >waybackdata/waybackurls.txt
    cat waybackdata/waybackurls.txt | sort -u | unfurl --unique keys >waybackdata/paramlist.txt
    cat waybackdata/waybackurls.txt | sort -u | grep -P "\w+\.js(\?|$)" | sort -u >waybackdata/jsurls.txt
    cat waybackdata/waybackurls.txt | sort -u | grep -P "\w+\.php(\?|$)" | sort -u >waybackdata/phpurls.txt
    cat waybackdata/waybackurls.txt | sort -u | grep -P "\w+\.aspx(\?|$)" | sort -u >waybackdata/aspxurls.txt
    cat waybackdata/waybackurls.txt | sort -u | grep -P "\w+\.jsp(\?|$)" | sort -u >waybackdata/jspurls.txt
    cat waybackdata/waybackurls.txt | sort -u | grep url= >waybackdata/open_url.txt
    cat waybackdata/waybackurls.txt | sort -u | grep redirect= >waybackdata/open_redirect.txt
    cat waybackdata/waybackurls.txt | sort -u | grep dest= >waybackdata/open_dest.txt
    cat waybackdata/waybackurls.txt | sort -u | grep path= >waybackdata/open_path.txt
    cat waybackdata/waybackurls.txt | sort -u | grep data= >waybackdata/open_data.txt
    cat waybackdata/waybackurls.txt | sort -u | grep domain= >waybackdata/open_domain.txt
    cat waybackdata/waybackurls.txt | sort -u | grep site= >waybackdata/open_site.txt
    cat waybackdata/waybackurls.txt | sort -u | grep dir= >waybackdata/open_dir.txt
    cat waybackdata/waybackurls.txt | sort -u | grep document= >waybackdata/document.txt
    cat waybackdata/waybackurls.txt | sort -u | grep root= >waybackdata/open_root.txt
    cat waybackdata/waybackurls.txt | sort -u | grep path= >waybackdata/open_path.txt
    cat waybackdata/waybackurls.txt | sort -u | grep folder= >waybackdata/open_folder.txt
    cat waybackdata/waybackurls.txt | sort -u | grep port= >waybackdata/open_port.txt
    cat waybackdata/waybackurls.txt | sort -u | grep result= >waybackdata/open_result.txt

    find waybackdata/ -size 0 -delete
}

get_aquatone() {
    echo -e $red"[+]"$end $bold"Get Aquatone"$end
    current_path=$(pwd)
    cat alive.txt | aquatone -silent --ports xlarge -out $current_path/aquatone/ -scan-timeout 500 -screenshot-timeout 50000 -http-timeout 6000
}

get_js() {
    echo -e $red"[+]"$end $bold"Get JS"$end

    mkdir jslinks

    cat alive.txt | subjs >>jslinks/all_jslinks.txt
}

get_tokens() {
    echo -e $red"[+]"$end $bold"Get Tokens"$end

    mkdir tokens

    cat alive.txt waybackdata/jsurls.txt jslinks/all_jslinks.txt >tokens/all_js_urls.txt
    sort -u tokens/all_js_urls.txt -o tokens/all_js_urls.txt
    cat tokens/all_js_urls.txt | python3 /tools/new-zile/zile.py --request >>tokens/all_tokens.txt
    sort -u tokens/all_tokens.txt -o tokens/all_tokens.txt
}

get_endpoints() {
    echo -e $red"[+]"$end $bold"Get Endpoints"$end

    mkdir endpoints

    for link in $(cat jslinks/all_jslinks.txt); do
        links_file=$(echo $link | sed -E 's/[\.|\/|:]+/_/g').txt
        python3 /tools/LinkFinder/linkfinder.py -i $link -o cli >>endpoints/$links_file
    done
}

get_paramspider() {
    echo -e $red"[+]"$end $bold"Get ParamSpider"$end

    mkdir paramspider

    for targets in $(cat /mainData/targets.txt); do
        targets_file=$(echo $targets | sed -E 's/[\.|\/|:]+/_/g')
        python3 /tools/ParamSpider/paramspider.py --domain $targets --exclude woff,css,js,png,svg,php,jpg --output paramspider/"$targets_file"_paramspider.txt
    done
}

get_paths() {
    echo -e $red"[+]"$end $bold"Get Paths"$end
    current_path=$(pwd)
    mkdir dirsearch

    for host in $(cat alive.txt); do
        dirsearch_file=$(echo $host | sed -E 's/[\.|\/|:]+/_/g').txt
        python3 /tools/dirsearch/dirsearch.py -E -t 50 --plain-text dirsearch/$dirsearch_file -u $host | grep Target && tput sgr0
    done

    grep -R '200' dirsearch/ >dirsearch/status200.txt 2>/dev/null
    grep -R '301' dirsearch/ >dirsearch/status301.txt 2>/dev/null
    grep -R '302' dirsearch/ >dirsearch/status301.txt 2>/dev/null
    grep -R '400' dirsearch/ >dirsearch/status400.txt 2>/dev/null
    grep -R '401' dirsearch/ >dirsearch/status401.txt 2>/dev/null
    grep -R '403' dirsearch/ >dirsearch/status403.txt 2>/dev/null
    grep -R '404' dirsearch/ >dirsearch/status404.txt 2>/dev/null
    grep -R '405' dirsearch/ >dirsearch/status405.txt 2>/dev/null
    grep -R '500' dirsearch/ >dirsearch/status500.txt 2>/dev/null
    grep -R '503' dirsearch/ >dirsearch/status503.txt 2>/dev/null

    find dirsearch/ -size 0 -delete
}

get_message() {
    echo -e $red"[+]"$end $bold"Get Message"$end

    message="[ + ] mainRecon Alert:
    [ --> ] Recon Completed for $program #happyhacking"

    curl --silent --output /dev/null -F chat_id="$chat_ID" -F "text=$message" $url -X POST
}

program=False
file=False

list=(
    get_subdomains
    get_alive
    get_waybackurl
    get_aquatone
    get_js
    get_tokens
    get_endpoints
    get_paramspider
    get_paths
    get_message
)

while [ -n "$1" ]; do
    case "$1" in
    -p | --program)
        program=$2
        shift
        ;;
    -f | --file)
        file=$2
        shift
        ;;
    *)
        echo -e $red"[-]"$end "Unknown Option: $1"
        Usage
        ;;
    esac
    shift
done

[[ $program == "False" ]] && [[ $file == "False" ]] && {
    echo -e $red"[-]"$end "Argument: -p/--program & -f/--file is Required"
    Usage
}
(
    get_subdomains
    get_alive
    get_waybackurl
    get_aquatone
    get_js
    get_tokens
    get_endpoints
    get_paramspider
    get_paths
    get_message
)