# Colors
autoload -Uz colors && colors

C_RED=${fg[red]}
C_GREEN=${fg[green]}
C_YELLOW=${fg[yellow]}
C_CYAN=${fg[cyan]}
C_NC=${reset_color}

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

# Extract one or more archive files based on their extension (thanks to: https://github.com/xvoland/Extract)
extract() {
	SAVEIFS=$IFS
	IFS=$' \t\n'
	set +e # abort execution on errors

	if [ $# -eq 0 ]; then
		# display usage if no parameters given
		echo "Usage: ${C_YELLOW}extract${C_NC} <path/file_name>.<zip|rar|bz2|gz|tar|tbz2|tgz|Z|7z|xz|ex|tar.bz2|tar.gz|tar.xz|.zlib|.cso|.zst>"
		echo "       ${C_YELLOW}extract${C_NC} <path/file_name_1.ext> [path/file_name_2.ext] [path/file_name_3.ext]"

		return 1
	fi

	while [[ $# -gt 0 ]]; do
		n="$1"
		shift

		# === STDIN ===
		if [[ "$n" == "-" ]]; then
			if [ -z "$1" ]; then
				echo "Error: must provide extension after '-' (stdin mode)"
				return 1
			fi
			ext="$1"
			shift

			tmpfile=$(mktemp "/tmp/extract.stdin.XXXXXX.$ext")
			cat >"$tmpfile"
			echo "Saved stdin to temp file: $tmpfile"
			extract "$tmpfile"
			rm -f "$tmpfile"
			continue
		fi

		# === FILE CHECK ===
		if [ ! -f "$n" ]; then
			echo "'$n' - file doesn't exist"
			continue
		fi

		case "${n%,}" in
		*.cbt | *.tar.bz2 | *.tar.gz | *.tar.xz | *.tbz2 | *.tgz | *.txz | *.tar)
			tar --auto-compress -xvf "$n"
			;;
		*.lzma) unlzma "$n" ;;
		*.appimage) ./"$n" --appimage-extract ;;
		*.tar.lz4) tar --use-compress-program=lz4 -xvf "$n" ;;
		*.lz4) lz4 -d "$n" ;;
		*.tar.br) tar --use-compress-program=brotli -xvf "$n" ;;
		*.bz2) bunzip2 "$n" ;;
		*.cbr | *.rar) unrar x -ad "$n" ;;
		*.gz) gunzip "$n" ;;
		*.cbz | *.epub | *.zip) unzip "$n" ;;
		*.z) uncompress "$n" ;;
		*.7z | *.apk | *.arj | *.cab | *.cb7 | *.chm | *.deb | *.iso | *.lzh | *.msi | *.pkg | *.rpm | *.udf | *.wim | *.xar | *.vhd)
			7z x "$n"
			;;
		*.xz) unxz "$n" ;;
		*.exe) cabextract "$n" ;;
		*.cpio) cpio -id <"$n" ;;
		*.cba | *.ace) unace x "$n" ;;
		*.zpaq) zpaq x "$n" ;;
		*.arc) arc e "$n" ;;
		*.cso) ciso 0 "$n" "$n.iso" && extract "$n.iso" && rm -f "$n" ;;
		*.zlib) zlib-flate -uncompress <"$n" >"${n%.*zlib}" && rm -f "$n" ;;
		*.dmg)
			mnt_dir=$(mktemp -d)
			hdiutil mount "$n" -mountpoint "$mnt_dir"
			echo "Mounted at: $mnt_dir"
			;;
		*.tar.zst) tar -I zstd -xvf "$n" ;;
		*.zst) zstd -d "$n" ;;
		*)
			echo "${C_RED}❌ '$n' cannot be extracted via extract().${C_NC}"
			echo "${C_RED}❌ '$n' is not a valid file.${C_NC}"
			continue
			;;
		esac
	done
	echo "${C_GREEN}✅ Extraction complete!${C_NC}"

	IFS=$SAVEIFS
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
