# Drop plugin aliases with these names so this file's functions/aliases win.
# (zsh aliases shadow functions; deferred OMZ plugins load after the first source.)
() {
	local n
	for n in z y extract port myip pingmap weather uvi nai kai kla klap klaf \
		cat ll l la ls scan_image password_gen mdcd mdtmpcd kpf ksd kgpv ki fnm-on
	do
		unalias "$n" 2>/dev/null
	done
}

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

# open yazi either at the given directory or at the one zoxide suggests.
# On exit, cd into whatever directory yazi was in when you quit.
y() {
	local cwd
	cwd=$(mktemp)

	local target
	if [[ -n $1 ]]; then
		if [ -d "$1" ]; then
			target="$1"
		else
			target="$(zoxide query "$1")"
		fi
	fi

	yazi ${target:+"$target"} --cwd-file="$cwd"

	local dir
	dir=$(cat -- "$cwd")
	rm -f -- "$cwd"
	[[ -n $dir && $dir != "$PWD" ]] && builtin cd -- "$dir"
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
# (format list adapted from https://github.com/xvoland/Extract)
extract() {
	if [[ "$1" == "help" || "$1" == "-h" || -z "$1" ]]; then
		echo "${C_CYAN}📦 extract${C_NC}: Universal archive extractor (supports multiple files)."
		echo "Usage: ${C_YELLOW}extract <archive> [archive...]${C_NC}"
		return 0
	fi

	local file mnt rc=0
	for file in "$@"; do
		if [[ ! -f "$file" ]]; then
			echo "${C_RED}❌ '$file' is not a valid file.${C_NC}"
			rc=1
			continue
		fi

		echo "${C_CYAN}Extracting '$file'...${C_NC}"
		# Compound tar suffixes must precede their single-compression counterparts
		case "$file" in
			*.tar.lz4)   tar --use-compress-program=lz4 -xvf "$file" ;;
			*.tar.br)    tar --use-compress-program=brotli -xvf "$file" ;;
			*.tar.zst)   tar --use-compress-program=zstd -xvf "$file" ;;
			*.tar|*.tar.bz2|*.tar.gz|*.tar.xz|*.tbz2|*.tgz|*.txz|*.cbt)
			             tar -xvf "$file" ;;
			*.bz2)       bunzip2 "$file" ;;
			*.gz)        gunzip "$file" ;;
			*.xz)        unxz "$file" ;;
			*.lzma)      unlzma "$file" ;;
			*.lz4)       lz4 -d "$file" ;;
			*.zst)       zstd -d "$file" ;;
			*.Z)         uncompress "$file" ;;
			*.rar|*.cbr) unrar x -ad "$file" ;;
			*.zip|*.cbz|*.epub)
			             unzip "$file" ;;
			*.7z|*.apk|*.arj|*.cab|*.cb7|*.chm|*.deb|*.iso|*.lzh|*.msi|*.pkg|*.rpm|*.udf|*.wim|*.xar|*.vhd)
			             7z x "$file" ;;
			*.exe)       cabextract "$file" ;;
			*.cpio)      cpio -id <"$file" ;;
			*.ace|*.cba) unace x "$file" ;;
			*.zpaq)      zpaq x "$file" ;;
			*.arc)       arc e "$file" ;;
			*.appimage|*.AppImage)
			             "${file:A}" --appimage-extract ;;
			*.dmg)
				mnt=$(mktemp -d) && hdiutil attach "$file" -mountpoint "$mnt" &&
					echo "Mounted at ${C_YELLOW}$mnt${C_NC} (detach with: hdiutil detach \"$mnt\")"
				;;
			*)
				echo "${C_RED}❌ '$file' cannot be extracted via extract().${C_NC}"
				rc=1
				continue
				;;
		esac || { echo "${C_RED}❌ Failed to extract '$file'.${C_NC}"; rc=1; }
	done

	(( rc == 0 )) && echo "${C_GREEN}✅ Extraction complete!${C_NC}"
	return $rc
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
	local local_ip
	if [[ "$OSTYPE" == darwin* ]]; then
		local_ip=$(route -n get default 2>/dev/null | awk '/interface:/{print $2}' | xargs ipconfig getifaddr 2>/dev/null)
	else
		local_ip=$(ip -4 -o route get 1 2>/dev/null | awk '{print $7; exit}')
	fi
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

uvi() {
	uv venv --clear || return
	source .venv/bin/activate || return
	if [ -f "pyproject.toml" ]; then
		uv sync --all-extras --active --upgrade
	elif [ -f "requirements.txt" ]; then
		uv pip install -r requirements.txt
	elif [ -f "requirements-dev.txt" ]; then
		uv pip install -r requirements-dev.txt
	else
		echo "No requirements file found"
		return 1
	fi
}
nai() {
  helm template kubecost-nightly --repo https://kubecost.github.io/nightly-helm-chart kubecost \
  --set networkCosts.enabled=true \
  --set clusterController.enabled=true \
  --set global.platforms.cicd.skipSanityChecks=true \
    "$@" \
    --skip-tests | yq -r ".. | .image? | select(. != null)" | sort -u
}

# kubecost all images
kai() {
  helm template kubecost-ga --repo https://kubecost.github.io/kubecost kubecost \
    "$@" \
    --skip-tests | yq -r ".. | .image? | select(. != null)" | sort -u
}
kla() {
  if [[ -n $(kubectl get pods -l app=aggregator -o name 2>/dev/null) ]]; then
    kubectl logs -l app=aggregator -c aggregator --tail=-1
  else
    kubectl logs -l app=cost-analyzer -c aggregator --tail=-1
  fi
}
klap() {
  if [[ -n $(kubectl get pods -l app=aggregator -o name 2>/dev/null) ]]; then
    kubectl logs -l app=aggregator -c aggregator --previous
  else
    kubectl logs -l app=cost-analyzer -c aggregator --previous
  fi
}
klaf() {
  if [[ -n $(kubectl get pods -l app=aggregator -o name 2>/dev/null) ]]; then
    kubectl logs -l app=aggregator -c aggregator --tail=-1 --follow
  else
    kubectl logs -l app=cost-analyzer -c aggregator --tail=-1 --follow
  fi
}
cat() {
  if (( $+commands[bat] )) && [[ -t 1 && $# -gt 0 && "$1" != -* ]]; then
    bat --plain --paging=never "$@"
  else
    command cat "$@"
  fi
}
if [ "$(command -v eza)" ]; then
  alias ll='eza -l --color always --icons -a -s type'
  alias l='eza --color always --icons -a -s type'
  alias la='eza -l --color always --icons -a -s type'
  alias ls='eza -G  --color auto --icons -a -s type'
fi
scan_image() {
    emulate -L zsh

    local image="$1"
    local image_type="${2:-unknown}"

    if [[ -z "$image" ]]; then
      echo "Usage: scan_image <image> [image_type]" >&2
      return 2
    fi

    echo "Scanning $image_type image: $image"

    local tmpdir raw temp_result temp_combined
    tmpdir=$(mktemp -d) || return 1
    {
      raw="$tmpdir/trivy.json"
      temp_result="$tmpdir/result.json"
      temp_combined="$tmpdir/combined.json"

      command trivy image --quiet --format json --exit-code 0 --ignore-unfixed \
        --severity CRITICAL,HIGH,MEDIUM,LOW "$image" > "$raw" || return

      # command jq -M: aliases.zsh forces jq -C, which writes ANSI into .json files
      command jq -M --arg img "$image" --arg type "$image_type" '
        {
          "image": $img,
          "type": $type,
          "base_vulnerabilities": (
            [
              (.Results // [])[] |
              select(.Class == "os-pkgs") |
              .Vulnerabilities // []
            ] | flatten |
            group_by(.Severity) |
            map({
              severity: .[0].Severity,
              count: length,
              vulnerabilities: map({
                id: .VulnerabilityID,
                package: .PkgName,
                version: .InstalledVersion
              })
            })
          ),
          "binary_vulnerabilities": (
            [
              (.Results // [])[] |
              select(.Class == "lang-pkgs") |
              .Vulnerabilities // []
            ] | flatten |
            group_by(.Severity) |
            map({
              severity: .[0].Severity,
              count: length,
              vulnerabilities: map({
                id: .VulnerabilityID,
                package: .PkgName,
                version: .InstalledVersion
              })
            })
          )
        }' "$raw" > "$temp_result" || {
          echo "Error: failed to parse trivy JSON for $image" >&2
          return 1
        }

      [[ -f scan_results.json ]] || echo "[]" > scan_results.json

      command jq -M -s '.[0] + [.[1]]' scan_results.json "$temp_result" > "$temp_combined" || return
      mv "$temp_combined" scan_results.json && echo "Scan results updated in scan_results.json"
    } always {
      rm -rf -- "$tmpdir"
    }
  }
password_gen() {
	local str
	while true; do
		str=$(LC_ALL=C tr -dc 'a-zA-Z0-9_' < /dev/urandom | head -c 16)
		if [[ "$str" == *_* && "$str" != _* && "$str" != *_ ]]; then
			echo "$str"
			break
		fi
	done
}
### Make a directory and cd into it, parents included.
###   mkcd ~/src/new/project
### https://github.com/mattmc3/zephyr/blob/main/functions/mkcd
mdcd() {
  emulate -L zsh

  [[ -n "${1:-}" ]] || { print -ru2 -- "mkcd: expecting a directory argument"; return 1 }
  mkdir -p -- "$1" && builtin cd -- "$1"
}
mdtmpcd() {
  emulate -L zsh

  # The template is spelled out because GNU and BSD mktemp disagree about -t.
  local dir tmp=${${TMPDIR:-/tmp}%/}
  dir=$(mktemp -d "$tmp/${1:-tmp}.XXXXXXXX") || return 1
  builtin cd -- "$dir" && print -r -- "$PWD"
}

if (( $+commands[kubectl] && $+commands[kubectl-images] )); then
  alias ki="kubectl images"
fi

if [[ -f ~/git/utils-python/orchestrator-info-rich.py ]]; then
  alias orch="~/git/utils-python/orchestrator-info-rich.py"
fi

if [[ -f ~/git/utils-python/epoch-converter.py ]]; then
  alias ep="~/git/utils-python/epoch-converter.py"
fi

if [ "$commands[kubectx]" ]; then
  alias kn='kubens'
  alias kx='kubectx'
fi

pypi_lookup() {
  curl -fsS "https://pypi.org/pypi/${1:?usage: pypi_lookup <package>}/json" | jq -r .info.version
}
