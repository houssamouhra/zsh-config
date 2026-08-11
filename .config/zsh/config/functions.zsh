# Colors
C_RED=$'\e[0;31m'
C_GREEN=$'\e[0;32m'
C_YELLOW=$'\e[0;33m'
C_CYAN=$'\e[0;36m'
C_NC=$'\e[0m'

# SSH Agent / Keychain
_ssh_agent_lazy() {
	if [[ -n "$SSH_AUTH_SOCK" && -S "$SSH_AUTH_SOCK" ]] &&
		ssh-add -l >/dev/null 2>&1; then
		echo "${C_GREEN}SSH agent already active${C_NC}"
		return 0
	fi

	[[ -f ~/.keychain/"$HOST"-sh ]] && source ~/.keychain/"$HOST"-sh
	eval "$(keychain --eval --quiet --nogui --timeout 480 ~/.ssh/id_ed25519)" &&
	echo "${C_GREEN}SSH agent started${C_NC}"
}

# zoxide integration
z() {
	unset -f z
	eval "$(zoxide init zsh)"
	z "$@"
}

# open yazi either at the given directory
# or at the one zoxide suggests
y() {
	if [[ -n $1 ]]; then
		if [ -d "$1" ]; then
			yazi "$1"
		else
			yazi "$(zoxide query "$1")"
		fi
	else
		yazi
	fi
}

# fnm lazy load
_fnm_lazy_load() {
	if [[ -f package.json ]]; then
		eval "$(fnm env)" 2>/dev/null || return
		add-zsh-hook -d chpwd _fnm_lazy_load
	fi
}
_fnm_lazy_load
add-zsh-hook -d chpwd _fnm_lazy_load 2>/dev/null
add-zsh-hook chpwd _fnm_lazy_load

# fnm manual activation
fnm-on() {
	eval "$(fnm env)" 2>/dev/null
	echo "${C_GREEN}Node activated${C_NC}"
}

# Extract one or more archive files based on their extension
extract() {
	if [[ "$1" == "help" || "$1" == "-h" || -z "$1" ]]; then
		echo "${C_CYAN}📦 extract${C_NC}: Universal archive extractor (supports multiple files)."
		echo "Usage: ${C_YELLOW}extract <archive> [archive...]${C_NC}"
		return 0
	fi

	for file in "$@"; do
		if [ -f "$file" ] ; then
			echo "${C_CYAN}Extracting '$file'...${C_NC}"
			case "$file" in
				*.tar.bz2)   tar xjf "$file"     ;;
				*.tar.gz)    tar xzf "$file"     ;;
				*.bz2)       bunzip2 "$file"     ;;
				*.rar)       unrar x "$file"     ;;
				*.gz)        gunzip "$file"      ;;
				*.tar)       tar xf "$file"      ;;
				*.tbz2)      tar xjf "$file"     ;;
				*.tgz)       tar xzf "$file"     ;;
				*.zip)       unzip "$file"       ;;
				*.Z)         uncompress "$file"  ;;
				*.7z)        7z x "$file"        ;;
				*)           echo "${C_RED}❌ '$file' cannot be extracted via extract().${C_NC}" ;;
			esac
		else
			echo "${C_RED}❌ '$file' is not a valid file.${C_NC}"
		fi
	done
	echo "${C_GREEN}✅ Extraction complete!${C_NC}"
}

# Inspect a port and optionally terminate the process using it
port() {
	if [[ "$1" == "help" || "$1" == "-h" || -z "$1" ]]; then
		echo "${C_CYAN}🔌 port${C_NC}: See what's running on a port and optionally kill it."
		echo "Usage: ${C_YELLOW}port <number> [kill]${C_NC}"
		echo "Examples:"
		echo "  port 8080       (Views processes on port 8080)"
		echo "  port 3000 kill  (Kills the process running on port 3000)"
		return 0
	fi

	local target_port=$1
	if [[ "$2" == "kill" ]]; then
		echo "${C_RED}Attempting to kill process on port $target_port...${C_NC}"
		local pid=$(lsof -t -i:"$target_port")
		if [[ -n "$pid" ]]; then
			kill -9 $pid
			echo "${C_GREEN}✅ Process $pid killed successfully.${C_NC}"
		else
			echo "${C_YELLOW}⚠️  No process found running on port $target_port.${C_NC}"
		fi
	else
		echo "${C_CYAN}Processes listening on port $target_port:${C_NC}"
		lsof -i :"$target_port" || echo "${C_YELLOW}No active processes on this port.${C_NC}"
	fi
}

# Display local, public, and approximate geolocation information for your IP
myip() {
	if [[ "$1" == "help" || "$1" == "-h" ]]; then
		echo "${C_CYAN}🌐 myip${C_NC}: Fetches your networking info."
		echo "Usage: ${C_YELLOW}myip${C_NC}"
		return 0
	fi

	echo "${C_CYAN}Fetching IP details...${C_NC}"
	local local_ip=$(route -n get default 2>/dev/null | grep 'interface:' | awk '{print $2}' | xargs ipconfig getifaddr 2>/dev/null)
	[[ -z "$local_ip" ]] && local_ip="127.0.0.1"
	local public_ip=$(curl -s https://ifconfig.me)
	local geo_info=$(curl -s "https://ipinfo.io/${public_ip}/city")
	local country_info=$(curl -s "https://ipinfo.io/${public_ip}/country")

	echo "🏠 ${C_YELLOW}Local IP:${C_NC}  $local_ip"
	echo "🌍 ${C_YELLOW}Public IP:${C_NC} $public_ip"
	echo "📍 ${C_YELLOW}Location:${C_NC}  $geo_info, $country_info"
}

# Measure HTTP request timing and connection latency for a URL
pingmap() {
	if [[ "$1" == "help" || "$1" == "-h" || -z "$1" ]]; then
		echo "${C_CYAN}📍 pingmap${C_NC}: Detailed connection latency breakdown."
		echo "Usage: ${C_YELLOW}pingmap <url> ${C_NC}"
		echo "Example: pingmap google.com"
		return 0
	fi

	local url="$1"

	# Prepend https:// when the URL has no scheme
	[[ "$url" != http* ]] && url="https://$url"

	echo "${C_CYAN}Mapping network route to: $url${C_NC}"
	echo "----------------------------------------"
	curl -w "  HTTP Status   : %{http_code}\n  DNS Lookup    : %{time_namelookup}s\n  TCP Connect   : %{time_connect}s\n  TLS Handshake : %{time_appconnect}s\n  Pre-Transfer  : %{time_pretransfer}s\n  First Byte    : %{time_starttransfer}s\n----------------------------------------\n  ${C_GREEN}Total Time    : %{time_total}s${C_NC}\n\n" -o /dev/null -s "$url"
}

# Fetch terminal weather and forecast information with optional display formats
weather() {
	if [[ "$1" == "help" || "$1" == "-h" ]]; then
		echo "${C_CYAN}☁️  weather${C_NC}: Advanced terminal weather and forecast."
		echo "Usage: ${C_YELLOW}weather [options] [location]${C_NC}"
		echo ""
		echo "Options:"
		echo "  ${C_YELLOW}-s, --short${C_NC}    Single-line compact format (Temp & Condition)"
		echo "  ${C_YELLOW}-o, --oneline${C_NC}  Rich single-line format (Temp, Wind, Humidity)"
		echo "  ${C_YELLOW}-f, --forecast${C_NC} Detailed visual graph forecast"
		echo "  ${C_YELLOW}-m, --moon${C_NC}    Show current moon phase"
		echo ""
		echo "Examples:"
		echo "  weather London          (Default 3-day text forecast)"
		echo "  weather -o New York     (One-line rich weather)"
		echo "  weather -f              (Detailed forecast for your current IP)"
		return 0
	fi

	local format=""
	local args=()

	for arg in "$@"; do
		case "$arg" in
			-s|--short) format="?format=3" ;;
			-o|--oneline) format="?format=4" ;;
			-f|--forecast) format="?format=v2" ;;
			-m|--moon) format="?Moon" ;;
			-*)
				echo "${C_RED}❌ Unknown option: $arg${C_NC}"
				echo "Run ${C_YELLOW}weather -h${C_NC} for usage."
				return 1
				;;
			*) args+=("$arg") ;;
		esac
	done

	local loc="${args[*]}"
	loc="${loc// /+}"

	echo "${C_CYAN}Fetching weather data...${C_NC}"
	curl -s "https://wttr.in/${loc}${format}"
}
