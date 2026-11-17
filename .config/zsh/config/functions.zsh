# Personal shell helpers: tool integrations and small command-line utilities.

# ── Colors ────────────────────────────────────────────────────────────────────
# Plain escape codes: nothing to autoload at startup
typeset -g C_RED=$'\e[31m' C_GREEN=$'\e[32m' C_YELLOW=$'\e[33m' C_CYAN=$'\e[36m' C_NC=$'\e[0m'


# ── SSH agent / keychain ──────────────────────────────────────────────────────
# NOTE: nothing in this file calls it; call it from wherever you used it before.
_ssh_agent_lazy() {
	emulate -L zsh

	if [[ -S $SSH_AUTH_SOCK ]] && ssh-add -l &>/dev/null; then
		print -r -- "${C_GREEN}SSH agent already active${C_NC}"
		return 0
	fi

	(( $+commands[keychain] )) || {
		print -u2 -r -- "${C_RED}keychain not found${C_NC}"
		return 1
	}

	[[ -r $HOME/.keychain/${HOST}-sh ]] && source "$HOME/.keychain/${HOST}-sh"
	eval "$(keychain --eval --quiet --nogui --timeout 480 "$HOME/.ssh/id_ed25519")" &&
		print -r -- "${C_GREEN}SSH agent started${C_NC}"
}

# ── zoxide ────────────────────────────────────────────────────────────────────
# Lazy-loaded on first use of `z`
z() {
	unset -f z
	eval "$(zoxide init zsh)"
	z "$@"
}
 
# ── yazi ──────────────────────────────────────────────────────────────────────
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

# ── fnm (Node version manager) ────────────────────────────────────────────────
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
	if (( ! $+commands[fnm] )); then
		echo "${C_RED}fnm is required but not installed${C_NC}" >&2
		return 1
	fi
 
	eval "$(fnm env)" 2>/dev/null
	echo "${C_GREEN}Node activated${C_NC}"
}

# ── extract ───────────────────────────────────────────────────────────────────
# Extract one or more archive files based on their extension
# Source: https://github.com/xvoland/Extract/blob/master/extract.sh
extract() {
	# save IFS so it can be restored when the function ends
	SAVEIFS=$IFS
	IFS=$' \t\n'
	set +e # abort execution on errors
 
	if [ $# -eq 0 ]; then
		# display usage if no parameters given
		echo "Usage: ${C_YELLOW}extract${C_NC} <path/file_name>.<zip|rar|bz2|gz|tar|tbz2|tgz|Z|7z|xz|ex|tar.bz2|tar.gz|tar.xz|.zlib|.cso|.zst>"
		echo "       ${C_YELLOW}extract${C_NC} <path/file_name_1.ext> [path/file_name_2.ext] [path/file_name_3.ext]"
 
		return 1
	fi
 
	# handle every argument as a separate archive
	while [[ $# -gt 0 ]]; do
		n="$1"
		shift
 
		# === STDIN ===
		if [[ "$n" == "-" ]]; then
			if [ -z "$1" ]; then
				echo "${C_RED}Error: must provide extension after '-' (stdin mode)${C_NC}"
				return 1
			fi
			# the extension tells extract which tool to use
			ext="$1"
			shift
 
			# save stdin to a temp file, extract it, then clean up
			tmpfile=$(mktemp "/tmp/extract.stdin.XXXXXX.$ext")
			cat >"$tmpfile"
			echo "${C_CYAN}Saved stdin to temp file: $tmpfile${C_NC}"
			extract "$tmpfile"
			rm -f "$tmpfile"
			continue
		fi
 
		# === FILE CHECK ===
		if [ ! -f "$n" ]; then
			echo "${C_RED}'$n' - file doesn't exist${C_NC}"
			continue
		fi
 
		# announce which file is being extracted
		echo "${C_YELLOW}Extracting: $n${C_NC}"
 
		# pick the extraction tool based on the file extension
		case "${n%,}" in
		# tar archives (the compression is detected automatically)
		*.cbt | *.tar.bz2 | *.tar.gz | *.tar.xz | *.tbz2 | *.tgz | *.txz | *.tar)
			tar --auto-compress -xvf "$n"
			;;
		# single-file compressors and tar variants needing a specific program
		*.lzma) unlzma "$n" ;;
		# AppImage: unpack its contents without running the app
		*.appimage) ./"$n" --appimage-extract ;;
		*.tar.lz4) tar --use-compress-program=lz4 -xvf "$n" ;;
		*.lz4) lz4 -d "$n" ;;
		*.tar.br) tar --use-compress-program=brotli -xvf "$n" ;;
		*.bz2) bunzip2 "$n" ;;
		# rar, gzip, zip (including comic book and epub files) and compress
		*.cbr | *.rar) unrar x -ad "$n" ;;
		*.gz) gunzip "$n" ;;
		*.cbz | *.epub | *.zip) unzip "$n" ;;
		*.z) uncompress "$n" ;;
		# 7z handles many package, disk image and legacy archive formats
		*.7z | *.apk | *.arj | *.cab | *.cb7 | *.chm | *.deb | *.iso | *.lzh | *.msi | *.pkg | *.rpm | *.udf | *.wim | *.xar | *.vhd)
			7z x "$n"
			;;
		*.xz) unxz "$n" ;;
		# Windows executables and other legacy formats
		*.exe) cabextract "$n" ;;
		*.cpio) cpio -id <"$n" ;;
		*.cba | *.ace) unace x "$n" ;;
		*.zpaq) zpaq x "$n" ;;
		*.arc) arc e "$n" ;;
		# cso: convert to iso, extract it, then remove the original
		*.cso) ciso 0 "$n" "$n.iso" && extract "$n.iso" && rm -f "$n" ;;
		# zlib: strip the extension for the output file name
		*.zlib) zlib-flate -uncompress <"$n" >"${n%.*zlib}" && rm -f "$n" ;;
		# dmg: mount the disk image in a temp directory (macOS only)
		*.dmg)
			mnt_dir=$(mktemp -d)
			hdiutil mount "$n" -mountpoint "$mnt_dir"
			echo "${C_GREEN}Mounted at: $mnt_dir${C_NC}"
			;;
		# zstd archives
		*.tar.zst) tar -I zstd -xvf "$n" ;;
		*.zst) zstd -d "$n" ;;
		# anything else is not a supported format
		*)
			echo "${C_RED}extract: '$n' - unknown archive method${C_NC}"
			continue
			;;
		esac
	done
 
	# all arguments have been processed
	echo "${C_GREEN}Extraction complete!${C_NC}"
 
	# restore the original IFS
	IFS=$SAVEIFS
}

# ── port ──────────────────────────────────────────────────────────────────────
# port <number> [kill [signal]]: see what is LISTENING on a port, optionally kill it
port() {
	emulate -L zsh

	if [[ -z $1 || $1 == (help|-h|--help) ]]; then
		print -r -- "${C_CYAN}🔌 port${C_NC}: See what's listening on a port and optionally kill it."
		print -r -- "Usage: ${C_YELLOW}port <number> [kill [signal]]${C_NC}"
		print -r -- "Examples:"
		print -r -- "  port 8080          (show the process listening on 8080)"
		print -r -- "  port 3000 kill     (send TERM to it)"
		print -r -- "  port 3000 kill 9   (send KILL to it)"
		return 0
	fi

	local target_port=$1
	[[ $target_port == <1-65535> ]] || {
		print -u2 -r -- "${C_RED}❌ '$target_port' is not a valid port${C_NC}"
		return 1
	}
	(( $+commands[lsof] )) || {
		print -u2 -r -- "${C_RED}❌ lsof not found${C_NC}"
		return 1
	}

	# Listeners only: `lsof -i :PORT` would also match clients (e.g. your browser)
	if [[ $2 == kill ]]; then
		local -a pids=(${(f)"$(lsof -nP -t -iTCP:"$target_port" -sTCP:LISTEN 2>/dev/null)"})
		if (( $#pids )); then
			if kill -"${3:-TERM}" $pids; then
				print -r -- "${C_GREEN}✅ Sent ${3:-TERM} to: ${(j:, :)pids}${C_NC}"
			else
				print -u2 -r -- "${C_RED}❌ Could not kill ${(j:, :)pids} (try sudo?)${C_NC}"
				return 1
			fi
		else
			print -r -- "${C_YELLOW}⚠️  Nothing is listening on port $target_port${C_NC}"
		fi
	else
		print -r -- "${C_CYAN}Processes listening on port $target_port:${C_NC}"
		lsof -nP -iTCP:"$target_port" -sTCP:LISTEN ||
			print -r -- "${C_YELLOW}No active listeners on this port.${C_NC}"
	fi
}

# ── myip ──────────────────────────────────────────────────────────────────────
# Local, public and approximate location info for your IP
myip() {
	emulate -L zsh

	if [[ $1 == (help|-h|--help) ]]; then
		print -r -- "${C_CYAN}🌐 myip${C_NC}: Fetches your networking info."
		print -r -- "Usage: ${C_YELLOW}myip${C_NC}"
		return 0
	fi

	print -r -- "${C_CYAN}Fetching IP details...${C_NC}"

	local local_ip iface info public_ip city country

	if [[ $OSTYPE == darwin* ]]; then
		iface=$(route -n get default 2>/dev/null | awk '/interface:/ {print $2}')
		[[ -n $iface ]] && local_ip=$(ipconfig getifaddr "$iface" 2>/dev/null)
	else
		local_ip=$(ip -4 route get 1.1.1.1 2>/dev/null |
			awk '{for (i = 1; i < NF; i++) if ($i == "src") { print $(i + 1); exit }}')
	fi
	: ${local_ip:=127.0.0.1}

	# One request instead of three
	info=$(curl -fsS -m 5 https://ipinfo.io/json 2>/dev/null) || {
		print -u2 -r -- "${C_RED}❌ Could not reach ipinfo.io${C_NC}"
		print -r -- "🏠 ${C_YELLOW}Local IP:${C_NC}  $local_ip"
		return 1
	}

	[[ $info =~ '"ip": *"([^"]*)"' ]]      && public_ip=$match[1]
	[[ $info =~ '"city": *"([^"]*)"' ]]    && city=$match[1]
	[[ $info =~ '"country": *"([^"]*)"' ]] && country=$match[1]

	print -r -- "🏠 ${C_YELLOW}Local IP:${C_NC}  $local_ip"
	print -r -- "🌍 ${C_YELLOW}Public IP:${C_NC} ${public_ip:-unknown}"
	print -r -- "📍 ${C_YELLOW}Location:${C_NC}  ${city:-unknown}, ${country:-unknown}"
}

# ── pingmap ───────────────────────────────────────────────────────────────────
# Detailed HTTP timing breakdown for a URL
pingmap() {
	emulate -L zsh

	if [[ -z $1 || $1 == (help|-h|--help) ]]; then
		print -r -- "${C_CYAN}📍 pingmap${C_NC}: Detailed connection latency breakdown."
		print -r -- "Usage: ${C_YELLOW}pingmap <url>${C_NC}"
		print -r -- "Example: pingmap google.com"
		return 0
	fi

	local url=$1

	# Add https:// only when there is no scheme (a bare "httpbin.org" has none)
	[[ $url == http://* || $url == https://* ]] || url="https://$url"

	print -r -- "${C_CYAN}Mapping network route to: $url${C_NC}"
	print -r -- "----------------------------------------"
	curl -sS -m 15 -o /dev/null -w "  HTTP Status   : %{http_code}\n  DNS Lookup    : %{time_namelookup}s\n  TCP Connect   : %{time_connect}s\n  TLS Handshake : %{time_appconnect}s\n  Pre-Transfer  : %{time_pretransfer}s\n  First Byte    : %{time_starttransfer}s\n----------------------------------------\n  ${C_GREEN}Total Time    : %{time_total}s${C_NC}\n\n" -- "$url"
}

# ── weather ───────────────────────────────────────────────────────────────────
# Terminal weather and forecast via wttr.in
weather() {
	emulate -L zsh

	if [[ $1 == (help|-h|--help) ]]; then
		print -r -- "${C_CYAN}☁️  weather${C_NC}: Terminal weather and forecast."
		print -r -- "Usage: ${C_YELLOW}weather [options] [location]${C_NC}"
		print -r -- ""
		print -r -- "Options:"
		print -r -- "  ${C_YELLOW}-s, --short${C_NC}     Single-line compact format (temp & condition)"
		print -r -- "  ${C_YELLOW}-o, --oneline${C_NC}   Rich single-line format (temp, wind, humidity)"
		print -r -- "  ${C_YELLOW}-f, --forecast${C_NC}  Detailed visual forecast"
		print -r -- "  ${C_YELLOW}-m, --moon${C_NC}      Show the current moon phase"
		print -r -- ""
		print -r -- "Examples:"
		print -r -- "  weather London          (default 3-day text forecast)"
		print -r -- "  weather -o New York     (one-line rich weather)"
		print -r -- "  weather -f              (detailed forecast for your current IP)"
		return 0
	fi

	local arg format loc
	local -i moon=0
	local -a args=()

	for arg in "$@"; do
		case $arg in
			-s|--short)    format="?format=3" ;;
			-o|--oneline)  format="?format=4" ;;
			-f|--forecast) format="?format=v2" ;;
			-m|--moon)     moon=1 ;;
			-*)
				print -u2 -r -- "${C_RED}❌ Unknown option: $arg${C_NC}"
				print -u2 -r -- "Run ${C_YELLOW}weather -h${C_NC} for usage."
				return 1 ;;
			*) args+=("$arg") ;;
		esac
	done

	# wttr.in serves the moon phase as a path (wttr.in/Moon), not a query
	if (( moon )); then
		loc=Moon
		format=
	else
		loc=${(j:+:)args}
	fi

	print -r -- "${C_CYAN}Fetching weather data...${C_NC}"
	curl -fsS -m 10 -- "https://wttr.in/${loc}${format}"
}
