#!/usr/bin/env bash
#
# STEmacsModelines:
# -*- Shell-Unix-Generic -*-
#
# Create and enable a swap file on Linux.
#

# Copyright (c) 2014 Mark Eissler, mark@mixtur.com

# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

PATH=/usr/local/bin

PATH_BNAME="/usr/bin/basename"
PATH_GETOPT="/usr/bin/getopt"
PATH_CAT="/usr/bin/cat"
PATH_DD="/usr/bin/dd"
PATH_LS="/bin/ls"
PATH_CHMOD="/usr/bin/chmod"
PATH_MKDIR="/usr/bin/mkdir"
PATH_RM="/usr/bin/rm"
PATH_STAT="/usr/bin/stat"
PATH_SED="/usr/bin/sed"
PATH_TR="/usr/bin/tr"
PATH_UNAME="/usr/bin/uname"
PATH_EXPR="/usr/bin/expr"
PATH_AWK="/usr/bin/awk"

PATH_MKSWAP="/usr/sbin/mkswap"
PATH_SWAPON="/usr/sbin/swapon"
PATH_SWAPOFF="/usr/sbin/swapoff"

# Loop device support (required for CoreOS)
#
PATH_LOSETUP="/usr/sbin/losetup"

# Swap directory
#
PATH_SWAPDIR="/root/swap"


###### NO SERVICABLE PARTS BELOW ######
VERSION=2.0.1
PROGNAME=$(${PATH_BNAME} $0)

# reset internal vars (do not touch these here)
DEBUG=0
FORCEEXEC=0
GETOPT_OLD=0
ADDSWAP=0
LISTSWAP=0
REMOVESWAP=0
SWAPIDLEN=6
SWAPSIZE=-1
EMPTYSTR=""

# min bash required
VERS_BASH_MAJOR=4
VERS_BASH_MINOR=2
VERS_BASH_PATCH=0

# defaults
DEF_SWAPSIZE=1024

# check for minimum bash
if [[ ${BASH_VERSINFO[0]} < ${VERS_BASH_MAJOR} ||
  ${BASH_VERSINFO[1]} < ${VERS_BASH_MINOR} ||
  ${BASH_VERSINFO[2]} < ${VERS_BASH_PATCH} ]]; then
  echo -n "${PROGNAME} requires at least BASH ${VERS_BASH_MAJOR}.${VERS_BASH_MINOR}.${VERS_BASH_PATCH}!"
  echo " (I seem to be running in BASH ${BASH_VERSINFO[0]}.${BASH_VERSINFO[1]}.${BASH_VERSINFO[2]})"
  echo
  exit 100
fi

#
# FUNCTIONS
#

# if basename is not installed
#
basename() {
  if [ -z "${1}" ]; then
    echo ""; return 1
  fi

  # resp=$(echo "${1}" | sed -E "s:^(.*/)*(.*)$:\2:;s:^(.*)(\..*)$:\1:")
  resp=$(echo "${1}" | sed -E "s:^([\/]?.*\/)*(.*)\..*$:\2:")
  rslt=$?
  if [[ -n "${resp}" ]] && [[ ${rslt} -eq 0 ]]; then
    echo ${resp}; return 0
  else
    echo ""; return 1
  fi
}

function usage {
  if [ ${GETOPT_OLD} -eq 1 ]; then
    usage_old
  else
    usage_new
  fi
}

function usage_new {
${PATH_CAT} << EOF
usage: ${PROGNAME} [--debug] -l
       ${PROGNAME} [--debug] [--force] --addswap [--swap-size <swapsize>]
       ${PROGNAME} [--debug] [--force] --remove-swap [--swap-id <swapid>]

Add system virtual memory ("swap"). On file systems that don\'t support swap,
the loop device will be used to create "fake" swap. The "add" and "remove"
options refer only to swap managed by fake-swap.

OPTIONS:
   -a, --add-swap               Add swap to system virtual memory pool
   -i, --swap-id                Swap id (as returned by "fake-swap --list-swap")
   -l, --list-swap              List swap managed by fake-swap
   -r, --remove-swap            Remove swap managed by fake-swap from vm pool
   -s, --swap-size              Size (MB) of swap to add (use with --add-swap)
   -d, --debug                  Turn debugging on (increases verbosity)
   -f, --force                  Execute without user prompt
   -h, --help                   Show this message
   -v, --version                Output version of this script

Adding swap:
  ${PROGNAME} [--debug] [--force] --addswap [--swap-size <swapsize>]

Optionally specify swap size (in MB) with the --swap-size flag. Otherwise,
the default value (${DEF_SWAPSIZE}) will be used. Do not append units to the
specified value.

Removing swap:
  ${PROGNAME} [--debug] [--force] --remove-swap [--swap-id <swapid>]

Optionally specify swap id with the --swap-id option to specifically unwire and
remove a single swap file. Otherwise, all managed swap files will be unwired and
removed.

NOTE: The --remove-swap option will continue without user prompting if only a
single swap file is found or if multiple files are found and they are all
unwired. If multiple files are found and enabled swap is greater than 0MB, the
user will be prompted to continue unless the --force option has been enabled.


EOF
}

# support for old getopt (non-enhanced, only supports short param names)
#
function usage_old {
cat << EOF
usage: ${PROGNAME} [-d] -l
       ${PROGNAME} [-d] [-f] -a [-s <swapsize>]
       ${PROGNAME} [-d] [-f] -r [-i <swapid>]

Add system virtual memory ("swap"). On file systems that don\'t support swap,
the loop device will be used to create "fake" swap. The "add" and "remove"
options refer only to swap managed by fake-swap.

OPTIONS:
   -a                           Add swap to system virtual memory pool
   -i                           Swap id (as returned by "fake-swap -l")
   -l                           List swap managed by fake-swap
   -r                           Remove swap managed by fake-swap from vm pool
   -s                           Size (MB) of swap to add (use with -a)
   -d                           Turn debugging on (increases verbosity)
   -f                           Execute without user prompt
   -h                           Show this message
   -v                           Output version of this script

Adding swap:
  ${PROGNAME} [-d] [-f] -a [-s <swapsize>]

Optionally specify swap size (in MB) with the -s (swap size) flag. Otherwise,
the default value (${DEF_SWAPSIZE}) will be used. Do not append units to the
specified value.

Removing swap:
  ${PROGNAME} [-d] [-f] -r [-i <swapid>]

Optionally specify swap id with the -i (swap-id) option to specifically unwire
and remove a single swap file. Otherwise, all managed swap files will be unwired
and removed.

NOTE: The -r (remove-swap) option will continue without user prompting if only a
single swap file is found or if multiple files are found and they are all
unwired. If multiple files are found and enabled swap is greater than 0MB, the
user will be prompted to continue unless the -f (force) option has been enabled.

EOF
}

function promptHelp {
${PATH_CAT} << EOF
For help, run "${PROGNAME}" with the -h flag or without any options.

EOF
}

function version {
  echo ${PROGNAME} ${VERSION};
}

# promptConfirm()
#
# Confirm a user action. Input case insensitive.
#
# Returns "yes" or "no" (default).
#
function promptConfirm() {
  read -p "$1 ([y]es or [N]o): "
  case $(echo $REPLY | ${PATH_TR} '[A-Z]' '[a-z]') in
    y|yes) echo "yes" ;;
    *)     echo "no" ;;
  esac
}

# check if swap is enabled
#

# checkSwap()
#
# Get configured swap size and reporting units. The referenced swapconfig array
#   will be updated.
#
# @param { arrayref } [optional] Reference to an existing swapconfig array
#
checkSwap() {
  local __swapconfig="gSwapConfig"
  if [ -n "${1}" ]; then
    __swapconfig=${1}
  fi
  declare -g -A "$__swapconfig"

  local swaparray
  local resp rslt

  # init array
  eval "$__swapconfig[SRECCNT]=1"
  eval "$__swapconfig[SRECSIZ]=2"
  eval "$__swapconfig[SRECOFF]=3"
  eval "$__swapconfig[SIZE]=0"
  eval "$__swapconfig[UNIT]=M"

  resp=$(${PATH_CAT} /proc/meminfo | ${PATH_SED} -En "s/^SwapTotal:[\ ]*([0-9]*)[\ ]*([a-zA-Z]{2,2})/\1@\2/p" )
  rslt=$?
  if [ ${rslt} -ne 0 ]; then
    return 1
  fi
  swaparray=(${resp//@/ })
  if [[ ${#swaparray[@]} -eq 2 ]] && [[ ${swaparray[0]} -gt 0 ]]; then
    eval "$__swapconfig[SIZE]=${swaparray[0]}"
    eval "$__swapconfig[UNIT]=${swaparray[1]}"
    return 0
  fi
}

# getSwapList()
#
# Get a list of our managed swap. The referenced swaplist array will be updated.
#
# @param { arrayref } [optional] Reference to an existing swaplist array
#
getSwapList() {
  local __swaplist="gSwapList"
  if [ -n "${1}" ]; then
    __swaplist=${1}
  fi
  declare -g -A "$__swaplist"

  local swapfile
  local lpdevice sizelimit offset autoclear roflag backfile
  local swdevice type size used prio
  local count=0
  local lcount scount
  local resp rslt
  local styparray
  local __wdev __type __size_i __size_i

  # init array
  eval "$__swaplist[SRECCNT]=${count}"
  eval "$__swaplist[SRECSIZ]=8"
  eval "$__swaplist[SRECOFF]=3"

  # suppress empty swapdir listing errors, check to see iif we have any swap at
  # all; if not, just bail out now!
  resp=$({ ${PATH_LS} -d1 ${PATH_SWAPDIR}/*; } 2>&1)
  rslt=$?
  if [[ rslt -ne 0 ]]; then
    if [ "${DEBUG}" -ne 0 ]; then
      echo "DEBUG:  swapdir: ERROR, is it empty?"
    fi
    return 1
  fi

  # get swap device and file information
  while IFS=" " read -r filesize swapfile; do
    resp=$(echo ${swapfile} | ${PATH_SED} -Ee "/(lp.swap|wd.swap)/!d" -e "s:^/root/swap[/]?/(wd.swap|lp.swap).(.*)$:\2@\1:")
    if [ "${DEBUG}" -ne 0 ]; then
      echo "DEBUG: swapfile: $swapfile"
      echo "DEBUG: id found: $resp"
    fi
    rslt=$?
    if [[ -n "${resp}" ]] && [[ ${rslt} -eq 0 ]]; then

      # split SWID and STYP into an array, fix STYPE
      styparray=(${resp//@/ })
      if [[ ${#styparray[@]} -eq 2 ]] && [[ ! -z ${styparray[0]} ]] && [[ ! -z ${styparray[1]} ]]; then
        if [[ "${styparray[1]}" = "lp.swap" ]]; then
          styparray[1]="loop"
        elif [[ "${styparray[1]}" = "wd.swap" ]]; then
          styparray[1]="fsys"
        fi
      else
        styparray[0]="unk"
        styparray[1]="unk"
      fi

      if [ "${DEBUG}" -ne 0 ]; then
        echo "DEBUG: swaptype: ${styparray[1]}"
        echo "DEBUG:     swid: ${styparray[0]}"
      fi

      (( count++ ))
      (( _idx=count-1 ))

      # SRECCNT: number of swap records
      # SRECSIZ: number of fields in each swap record
      # SRECOFF: offset from header records
      eval "$__swaplist[SRECCNT]=${count}"
      eval "$__swaplist[${_idx},SWID]=${styparray[0]}"
      eval "$__swaplist[${_idx},STYP]=${styparray[1]}"
      eval "$__swaplist[${_idx},FILE]=${swapfile}"
      eval "$__swaplist[${_idx},WIRE]=0"
      eval "$__swaplist[${_idx},WDEV]=${EMPTYSTR}"
      eval "$__swaplist[${_idx},SIZE]=${EMPTYSTR}"
      eval "$__swaplist[${_idx},USED]=${EMPTYSTR}"
      eval "$__swaplist[${_idx},TYPE]=${EMPTYSTR}"

      # retrieve loop device information
      if [[ "${styparray[1]}" = "loop" ]]; then
        lcount=0
        while IFS=" " read -r lpdevice sizelimit offset autoclear roflag backfile; do
          if [[ $(( lcount++ )) -lt 1 ]]; then
            continue
          fi
          if [[ "${swapfile}" = "${backfile}" ]]; then
            eval "$__swaplist[${_idx},WDEV]=${lpdevice}"
          fi
          (( lcount++ ))
        done <<< "$(${PATH_LOSETUP} --list)"
      else
        eval "$__swaplist[${_idx},WDEV]=${swapfile}"
      fi

      # get swap size information
      scount=0
      while IFS=" " read -r swdevice type size used prio; do
        if [[ $(( scount++ )) -lt 1 ]]; then
          continue
        fi

        # need to translate wdev value for local use, on loop devices, the
        # swdevice will point to /dev/loopX; on fsys devices, the swdevice
        # will point to the backing file.
        __wdev="\${${__swaplist}[${_idx},WDEV]}"
        __wdev=$(eval "${PATH_EXPR} \"${__wdev}\"")

        if [[ "${__wdev}" = "${swdevice}" ]]; then
          eval "$__swaplist[${_idx},SIZE]=${size}"
          eval "$__swaplist[${_idx},USED]=${used}"
          eval "$__swaplist[${_idx},TYPE]=${type}"
        fi
        (( scount++ ))
      done <<< "$(${PATH_SWAPON} --show)"

      # need to translate type value for local use, assume swap is wired if
      # type is not empty.
      __type="\${${__swaplist}[${_idx},TYPE]}"
      __type=$(eval "${PATH_EXPR} \"${__type}\"")

      if [[ -n "${__type}" ]]; then
        eval "$__swaplist[${_idx},WIRE]=1"
      else
        # calculate size of unwired swap from file size
        #
        # NOTE: We have to use awk and printf here since bash doesn't support
        # floating point numbers. We convert to int for bash comparisons.
        #
        __size_f=$(${PATH_AWK} "BEGIN {printf \"%.1f\", ${filesize}/1024}")
        __size_i=${__size_f%%.[0-9]*}
        if [[ ${__size_i} -lt 1025 ]]; then
          # print without floating point unless it is greater than 0
          if [[ ${__size_f##[0-9]*.} -gt 0 ]]; then
            eval "$__swaplist[${_idx},SIZE]=${__size_f}M"
          else
            eval "$__swaplist[${_idx},SIZE]=${__size_i}M"
          fi
        else
          __size_f=$(${PATH_AWK} "BEGIN {printf \"%.1f\", ${__size_f}/1024}")
          __size_i=${__size_f%%.[0-9]*}
          # print without floating point unless it is greater than 0
          if [[ ${__size_f##[0-9]*.} -gt 0 ]]; then
            eval "$__swaplist[${_idx},SIZE]=${__size_f}G"
          else
            eval "$__swaplist[${_idx},SIZE]=${__size_i}G"
          fi
        fi
      fi
    fi
  done <<< "$(${PATH_LS} -s -d1 ${PATH_SWAPDIR}/*)"
}

# getUniqStr()
#
# Get a random string.
#
# @param { int } Length of string to generate.
#
# @return { string } Generated string.
#
getUniqStr() {
  local uniqstr
  local length=5

  if [ -n "${1}" ]; then
    length=${1}
  fi

  dict="abcdefghijkmnopqrstuvxyz123456789"

  for i in $(eval echo {1..$length}); do
    rand=$(( $RANDOM%${#dict} ))
    uniqstr="${uniqstr}${dict:$rand:1}"
  done

  echo $uniqstr
}

# getUniqSWID()
#
# Get a unique swap id string. This is a recursive function.
#
# @param { arrayref } [optional] Reference to an existing swaplist array
# @param { string } [optional] Swapid to check and regenerate if not unique
#
# @return { string } Generated string.
#
getUniqSWID() {
  local __swaplist="gSwapList"
  if [ -n "${1}" ]; then
    __swaplist=${1}
  fi
  declare -g -A "$__swaplist"

  local checkswid=${2}
  local collision=1
  local __sreccnt
  local __swid

  if [ ${#__swaplist} -eq 0 ]; then
    getSwapList $__swaplist
  fi

  if [ -z "${checkswid}" ]; then
    checkswid=$(getUniqStr ${SWAPIDLEN})
  fi

  __sreccnt="\${${__swaplist}[SRECCNT]}"
  __sreccnt=$(eval "${PATH_EXPR} \"${__sreccnt}\"")

  while [[ $collision -eq 1 ]]; do
    for((i=0; i<${__sreccnt}; i++)); do

      __swid="\${${__swaplist}[$i,SWID]}"
      __swid=$(eval "${PATH_EXPR} \"${__swid}\"")

      if [[ "${__swid}" = "${checkswid}" ]]; then
        checkswid=$(getUniqSWID $__swaplist $checkswid)
      fi
    done
    collision=0
  done

  echo $checkswid
}

# addSwap()
#
# Add swap to the system.
#
# @param { int } [ optional ] Size of swap file in megabytes (-1 for default)
# @param { arrayref } [optional] Reference to an existing swapconfig array
# @param { arrayref } [optional] Reference to an existing swaplist array
#
addSwap() {
  # swapsize vars
  local __swapsize=${DEF_SWAPSIZE}
  if [ -n "${1}" ] && [ ${1} -gt ${__swapsize} ]; then
    __swapsize=${1}
  fi

  # swapconfig vars
  local __swapconfig="gSwapConfig"
  if [ -n "${2}" ]; then
    __swapconfig=${2}
  fi
  declare -g -A "$__swapconfig"

  local __swapconfig_reccnt
  local __swapconfig_size
  local __swapconfig_unit

  # swaplist vars
  local __swaplist="gSwapList"
  if [ -n "${3}" ]; then
    __swaplist=$3}
  fi
  declare -g -A "$__swaplist"

  local __sreccnt

  # other local vars...
  local swapid_new

  # let's go!
  #
  checkSwap $__swapconfig
  if [ $? -ne 0 ]; then
    echo "ABORTING. Unable to determine swap status."
    echo
    exit 1
  fi

  # translate to local vars
  __swapconfig_reccnt="\${${__swapconfig}[SRECCNT]}"
  __swapconfig_reccnt=$(eval "${PATH_EXPR} \"${__swapconfig_reccnt}\"")

  __swapconfig_size="\${${__swapconfig}[SIZE]}"
  __swapconfig_size=$(eval "${PATH_EXPR} \"${__swapconfig_size}\"")

  __swapconfig_unit="\${${__swapconfig}[UNIT]}"
  __swapconfig_unit=$(eval "${PATH_EXPR} \"${__swapconfig_unit}\"")

  if [[ ${__swapconfig_reccnt} -eq 1 ]] && [[ ${__swapconfig_size} -gt 0 ]]; then
    echo "Swap has already been enabled. Detected: ${__swapconfig_size} ${__swapconfig_unit}"
    if [[ "${FORCEEXEC}" -eq 0 ]]; then
      # prompt user for confirmation
      if [[ "no" == $(promptConfirm "Add additional swap?") ]]
      then
        echo "ABORTING. Nothing to do."
        exit 0
      fi
    fi
  fi

  # make the swap directory
  resp=$({ ${PATH_MKDIR} -p "${PATH_SWAPDIR}"; } 2>&1)
  rslt=$?
  if [ $? -ne 0 ]; then
    echo "ABORTING. Unable to create swap directory."
    echo
    exit 1
  else
    resp=$({ ${PATH_CHMOD} 0700 "${PATH_SWAPDIR}"; } 2>&1)
    rslt=$?
    if [ $? -ne 0 ]; then
      echo "ABORTING. Unable to adjust permissions on swap directory."
      echo
      exit
    fi
  fi

  # avoid collisions in name space, grab list of existing swap
  getSwapList $__swaplist

  # translate to local vars
  __sreccnt="\${${__swaplist}[SRECCNT]}"
  __sreccnt=$(eval "${PATH_EXPR} \"${__sreccnt}\"")

  if [ "${DEBUG}" -ne 0 ]; then
    echo "DEBUG:  sreccnt: ${__sreccnt}"
  fi
  swapid_new=$(getUniqSWID $__swaplist)
  if [ "${DEBUG}" -ne 0 ]; then
    echo "DEBUG: swapid_n: ${swapid_new}"
  fi

  if [[ "${osconfig[NAME]}" =~ "CoreOS" ]]; then
    echo
    echo "Creating swap using the loop device method..."
    swapfile="${PATH_SWAPDIR}/lp.swap.${swapid_new}"
    swapdev=$(${PATH_LOSETUP} -f)
    # check if a swapfile already exists, if not, create it
    resp=$(${PATH_STAT} ${swapfile} &> /dev/null)
    rslt=$?
    if [[ ${rslt} -ne 0 ]]; then
      echo "No swapfile detected. Creating it..."
      ${PATH_DD} if=/dev/zero of=${swapfile} bs=1M count=${__swapsize}
      if [ $? -ne 0 ]; then
        echo "ABORTING. Couldn't create swap file: ${swapfile}"
        echo
        exit 1
      fi
      # fix permissions
      ${PATH_CHMOD} 0600 ${swapfile}
      echo "Swap file created at ${swapfile}"
    else
      echo "Found a swap file at ${swapfile}"
    fi
    echo "Connecting swap to loop device."
    ${PATH_LOSETUP} ${swapdev} ${swapfile}
    echo "Formatting swap file."
    ${PATH_MKSWAP} ${swapdev} &> /dev/null
    echo "Enabling swap."
    ${PATH_SWAPON} ${swapdev}
  elif [[ "${osconfig[NAME]}" =~ "CentOS" ]]; then
    echo
    echo "Creating swap using the file system method..."
    swapfile="${PATH_SWAPDIR}/wd.swap.${swapid_new}"
    swapdev=${swapfile}
    # check if a swapfile already exists, if not, create it
    resp=$(${PATH_STAT} ${swapfile} &> /dev/null)
    rslt=$?
    if [[ ${rslt} -ne 0 ]]; then
      echo "No swapfile detected. Creating it..."
      ${PATH_DD} if=/dev/zero of=${swapfile} bs=1M count=${__swapsize}
      if [ $? -ne 0 ]; then
        echo "ABORTING. Couldn't create swap file: ${swapfile}"
        echo
        exit 1
      fi
      # fix permissions
      ${PATH_CHMOD} 0600 ${swapfile}
      echo "Swap file created at ${swapfile}"
    else
      echo "Found a swap file at ${swapfile}"
    fi
    echo "Formatting swap file."
    ${PATH_MKSWAP} ${swapdev} &> /dev/null
    echo "Enabling swap."
    ${PATH_SWAPON} ${swapdev}
  else
    echo "ABORTING. Swap creation strategy not implemented for this OS."
    echo
    exit 1
  fi

  echo
  echo "REMEMBER 1: You will need to remove the swap file when done: ${swapfile}"
  echo "REMEMBER 2: You will need to re-run this script between reboots/shutdowns."
  echo

  # check if our work was a success
  local __swapconfig_size_old=${__swapconfig_size}
  checkSwap $__swapconfig
  if [ $? -ne 0 ]; then
    echo "ABORTING. Unable to determine swap status."
    echo
    exit 1
  fi

  # translate to local vars
  __swapconfig_reccnt="\${${__swapconfig}[SRECCNT]}"
  __swapconfig_reccnt=$(eval "${PATH_EXPR} \"${__swapconfig_reccnt}\"")

  __swapconfig_size="\${${__swapconfig}[SIZE]}"
  __swapconfig_size=$(eval "${PATH_EXPR} \"${__swapconfig_size}\"")

  __swapconfig_unit="\${${__swapconfig}[UNIT]}"
  __swapconfig_unit=$(eval "${PATH_EXPR} \"${__swapconfig_unit}\"")

  if [[ ${__swapconfig_reccnt} -eq 1 ]]; then
    if [[ ${__swapconfig_size} -gt ${__swapconfig_size_old} ]]; then
      echo "Swap has been updated. Detected: ${__swapconfig_size} ${__swapconfig_unit}"
      echo
      exit 0
    else
      echo "Swap has NOT been updated. Detected: ${__swapconfig_size} ${__swapconfig_unit}"
      echo
      exit 1
    fi
  fi
}

# removeSwap()
#
# Remove swap from the system.
#
# @param { string } [ optional ] Id of swap file to remove
# @param { arrayref } [optional] Reference to an existing swapconfig array
# @param { arrayref } [optional] Reference to an existing swaplist array
#
removeSwap() {
  # swapsize vars
  local __swapid_target=""
  if [ -n "${1}" ] && [ ${#1} -eq ${SWAPIDLEN} ]; then
    __swapid_target=${1}
  fi
  local __swapid_target_found=0

  # swapconfig vars
  local __swapconfig="gSwapConfig"
  if [ -n "${2}" ]; then
    __swapconfig=${2}
  fi
  declare -g -A "$__swapconfig"

  local __swapconfig_reccnt
  local __swapconfig_size
  local __swapconfig_unit

  # swaplist vars
  local __swaplist="gSwapList"
  if [ -n "${3}" ]; then
    __swaplist=$3}
  fi
  declare -g -A "$__swaplist"

  local __swaplist_reccnt
  local __swaplist_item_file
  local __swaplist_item_stype
  local __swaplist_item_wdev
  local __swaplist_item_wire

  # let's go!
  #
  checkSwap $__swapconfig
  if [ $? -ne 0 ]; then
    echo "ABORTING. Unable to determine swap status."
    echo
    exit 1
  fi

  # translate to local vars
  __swapconfig_reccnt="\${${__swapconfig}[SRECCNT]}"
  __swapconfig_reccnt=$(eval "${PATH_EXPR} \"${__swapconfig_reccnt}\"")

  __swapconfig_size="\${${__swapconfig}[SIZE]}"
  __swapconfig_size=$(eval "${PATH_EXPR} \"${__swapconfig_size}\"")

  __swapconfig_unit="\${${__swapconfig}[UNIT]}"
  __swapconfig_unit=$(eval "${PATH_EXPR} \"${__swapconfig_unit}\"")

  # grab swap list
  getSwapList $__swaplist

  # translate to local vars
  __swaplist_reccnt="\${${__swaplist}[SRECCNT]}"
  __swaplist_reccnt=$(eval "${PATH_EXPR} \"${__swaplist_reccnt}\"")

  if [ -z "${__swapid_target}" ]; then
    if [[ ${__swaplist_reccnt} -gt 1 ]] && [[ ${__swapconfig_size} -gt 0 ]]; then
      echo "Multiple swap files have been found. Some may be wired."
      echo "Swap has been enabled. Detected: ${__swapconfig_size} ${__swapconfig_unit}"
      if [[ "${FORCEEXEC}" -eq 0 ]]; then
        # prompt user for confirmation
        if [[ "no" == $(promptConfirm "Remove all managed swap?") ]]
        then
          echo "ABORTING. Nothing to do."
          exit 0
        fi
      fi
    fi
  fi

  # iterate over our swaplist array and remove target (__swapid_target) or all
  # managed swaps found if no target specified.
  for((i=0; i<${__swaplist_reccnt}; i++)); do
    __swaplist_item_swid="\${${__swaplist}[${i},SWID]}"
    __swaplist_item_swid=$(eval "${PATH_EXPR} \"${__swaplist_item_swid}\"")

    __swaplist_item_file="\${${__swaplist}[${i},FILE]}"
    __swaplist_item_file=$(eval "${PATH_EXPR} \"${__swaplist_item_file}\"")

    __swaplist_item_stype="\${${__swaplist}[${i},STYP]}"
    __swaplist_item_stype=$(eval "${PATH_EXPR} \"${__swaplist_item_stype}\"")

    __swaplist_item_wdev="\${${__swaplist}[${i},WDEV]}"
    __swaplist_item_wdev=$(eval "${PATH_EXPR} \"${__swaplist_item_wdev}\"")

    __swaplist_item_wire="\${${__swaplist}[${i},WIRE]}"
    __swaplist_item_wire=$(eval "${PATH_EXPR} \"${__swaplist_item_wire}\"")

    # if __swapid_target AND __swaplist_item_swid is match, then remove and break!
    if [[ -n "${__swapid_target}" && "${__swapid_target}" = "${__swaplist_item_swid}" ]]; then
      __swapid_target_found=1
    fi

    #
    # To remove loop device based swap you need to do the following:
    #
    # >swapoff /dev/loop0
    # >losetup -d /dev/loop0
    #
    # If you don't delete the loop device, the kernel will at some point remap
    # the vm back into the table.
    #

    if [ -z "${__swapid_target}" ] || [ ${__swapid_target_found} -eq 1 ]; then

      if [[ "${__swaplist_item_stype}" = "loop" ]]; then
        echo "Removing swap (loop): ${__swaplist_item_swid}"
        # >swapoff /dev/loop0
        # >losetup -d /dev/loop0
        # remove file
        echo "Found a swap file at ${__swaplist_item_file}"

        if [[ "${__swaplist_item_wire}" -eq 1 ]]; then
          echo "Disabling swap."
          ${PATH_SWAPOFF} ${__swaplist_item_wdev}
          echo "Disconnecting loop device."
          ${PATH_LOSETUP} -d ${__swaplist_item_wdev}
        else
          echo "Swap is unwired."
        fi

        echo "Removing swap file."
        ${PATH_RM} ${__swaplist_item_file} &> /dev/null
        echo "Swap has been unwired and removed."
        echo
      elif [[ "${__swaplist_item_stype}" = "fsys" ]]; then
        echo "Removing swap (fsys): ${__swaplist_item_swid}"
        # >swapoff /dev/wd.swap.abcde
        # remove file
        echo "Found a swap file at ${__swaplist_item_file}"

        if [[ "${__swaplist_item_wire}" -eq 1 ]]; then
          echo "Disabling swap."
          ${PATH_SWAPOFF} ${__swaplist_item_wdev}
        else
          echo "Swap is unwired."
        fi

        echo "Removing swap file."
        ${PATH_RM} ${__swaplist_item_file} &> /dev/null
        echo "Swap has been unwired and removed."
        echo
      fi
    fi
  done

  if [ -n "${__swapid_target}" ] && [ ${__swapid_target_found} -eq 0 ]; then
    echo
    echo "WARNING. No swap found with id specified: ${__swapid_target}"
    echo
  fi

  # update swapconfig, if we removed wired swap, compare updated size with
  # the old size.

  # check if our work was a success
  local __swapconfig_size_old=${__swapconfig_size}
  checkSwap $__swapconfig
  if [ $? -ne 0 ]; then
    echo "ABORTING. Unable to determine swap status."
    echo
    exit 1
  fi

  # translate to local vars
  __swapconfig_reccnt="\${${__swapconfig}[SRECCNT]}"
  __swapconfig_reccnt=$(eval "${PATH_EXPR} \"${__swapconfig_reccnt}\"")

  __swapconfig_size="\${${__swapconfig}[SIZE]}"
  __swapconfig_size=$(eval "${PATH_EXPR} \"${__swapconfig_size}\"")

  __swapconfig_unit="\${${__swapconfig}[UNIT]}"
  __swapconfig_unit=$(eval "${PATH_EXPR} \"${__swapconfig_unit}\"")

  if [[ ${__swapconfig_reccnt} -eq 1 ]]; then
    if [[ ${__swapconfig_size} -lt ${__swapconfig_size_old} ]]; then
      echo "Swap has been updated. Detected: ${__swapconfig_size} ${__swapconfig_unit}"
      echo
      exit 0
    else
      echo "Swap has NOT been updated. Detected: ${__swapconfig_size} ${__swapconfig_unit}"
      echo
      exit 1
    fi
  fi
}

# list swap
#
listswap() {
  swaplist="swaplist"
  getSwapList $swaplist

  printf "\n? Swap Id     Type                  Size    Used\n"

  for((i=0; i<${swaplist[SRECCNT]}; i++)); do
    swaptype="${swaplist[$i,TYPE]}"
    if [[ "${swaplist[$i,STYP]}" = "loop" ]]; then
      swaptype="${swaptype} (loop)"
    elif [[ "${swaplist[$i,STYP]}" = "fsys" ]]; then
      swaptype="${swaptype} (fsys)"
    fi
    swapwire=""
    if [[ ${swaplist[$i,WIRE]} -eq 0 ]]; then
      swapwire="*"
      # trim leading space
      swaptype=${swaptype##[[:space:]]}
    fi
    swapsize="${swaplist[$i,SIZE]}"
    if [[ -z "${swapsize}" ]]; then
      swapsize="??"
    fi
    swapused="${swaplist[$i,USED]}"
    if [[ -z "${swapused}" ]]; then
      swapused="??"
    fi
    printf "%-1s %-10s  %-20s  %-6s  %-6s\n" "${swapwire}" "${swaplist[$i,SWID]}" "${swaptype}" "${swapsize}" "${swapused}"
  done

  if [[ ${swaplist[SRECCNT]} -gt 0 ]]; then
    echo; echo "--"
    echo "* preceding Swap Id denotes unwired swap"
  fi

  echo
}

# parse a config file with KEY=VAL definitions, return array in variable
# supplied by caller.
#
readconfig() {
  local array="$1"
  local key val
  local IFS='='
  declare -g -A "$array"
  while read reply; do
    # assume comments may not be indented
    [[ $reply == [^#]*[^$IFS]${IFS}[^$IFS]* ]] && {
      read key val <<< "$reply"
      [[ -n $key ]] || continue
      eval "$array[$key]=${val}"
    }
  done
}

# parse cli parameters
#
# Our options:
#   --add-swap, a
#   --swap-id, i
#   --list-swap, l
#   --remove-swap, r
#   --swap-size, s
#   --debug, d
#   --force, f
#   --help, h
#   --version, v
#
params=""
${PATH_GETOPT} -T > /dev/null
if [ $? -eq 4 ]; then
  # GNU enhanced getopt is available
  PROGNAME=$(${PATH_BNAME} $0)
  params="$(${PATH_GETOPT} --name "$PROGNAME" --long add-swap,swap-id:,list-swap,remove-swap,swap-size:,force,help,version,debug --options ai:lrs:fhvd -- "$@")"
else
  # Original getopt is available
  GETOPT_OLD=1
  PROGNAME=$(${PATH_BNAME} $0)
  params="$(${PATH_GETOPT} ai:lrs:fhvd "$@")"
fi

# check for invalid params passed; bail out if error is set.
if [ $? -ne 0 ]
then
  usage; exit 1;
fi

eval set -- "$params"
unset params
params_count=$#

while [ $# -gt 0 ]; do
  case "$1" in
    -a | --add-swap)
      if [[ ${REMOVESWAP} -ne 0 ]]; then
        if [ "${DEBUG}" -ne 0 ]; then
          echo "-a option specified simultaneously with -r option";
        fi
        usage;
        exit 1;
      fi
      cli_ADDSWAP=1; ADDSWAP=${cli_ADDSWAP};
      ;;
    -i | --swap-id)
      if [[ ${REMOVESWAP} -ne 1 || ${ADDSWAP} -eq 1 ]]; then
        if [ "${DEBUG}" -ne 0 ]; then
          echo "-i option without -r option";
        fi
        usage;
        exit 1;
      fi
      cli_SWAPID="$2";
      shift;
      ;;
    -l | --list-swap)
      if [[ ( ${params_count} -eq 3 && ${DEBUG} -eq 0 ) || ( ${params_count} -gt 3 ) ]]; then
        if [ "${DEBUG}" -ne 0 ]; then
          echo "-l option with additional options";
        fi
        usage;
        exit 1;
      fi
      cli_LISTSWAP=1; LISTSWAP=${cli_LISTSWAP};
      ;;
    -r | --remove-swap)
      if [[ ${ADDSWAP} -ne 0 ]]; then
        if [ "${DEBUG}" -ne 0 ]; then
          echo "-r option specified simultaneously with -a option";
        fi
        usage;
        exit 1;
      fi
      cli_REMOVESWAP=1; REMOVESWAP=${cli_REMOVESWAP};
      ;;
    -s | --swap-size)
      if [[ ${ADDSWAP} -ne 1 || ${REMOVESWAP} -eq 1 ]]; then
        if [ "${DEBUG}" -ne 0 ]; then
          echo "-s option without -a option";
        fi
        usage;
        exit 1;
      fi
      cli_SWAPSIZE="$2";
      shift;
      ;;
    -d | --debug)
      cli_DEBUG=1; DEBUG=${cli_DEBUG};
      ;;
    -f | --force)
      cli_FORCEEXEC=1; FORCEEXEC=${cli_FORCEEXEC};
      ;;
    -v | --version)
      version;
      exit;
      ;;
    -h | --help)
      usage;
      exit;
      ;;
    --)
      shift;
      break;
      ;;
  esac
  shift
done

# Grab final argument and abort (our arguments must be accompanied by flags!)
shift $((OPTIND-1))
if [ -n "${1}" ]; then
  echo
  echo "ABORTING. Found an orphaned argument. Did you forget an option flag?"
  echo
  usage
  exit 1
fi


# Root user!!
#
if [[ $EUID -ne 0 ]]; then
  echo
  echo "Superuser (root) privileges required." 1>&2
  echo
  exit 100
fi

# bail out if user hasn't specified any options
if [[ ${params_count} -eq 1 ]]; then
  echo
  echo "ABORTING. You have not specified any actionable options."
  echo
  usage;
  exit;
fi

# bail out if user has specified debug without any other options
if [[ ${DEBUG} -eq 1 && ${params_count} -eq 2 ]]; then
  echo
  echo "ABORTING. You cannot specify the -d option on its own."
  echo
  usage;
  exit;
fi

# is the -s flag specified without the -a flag?
if [ ! -z "${cli_SWAPSIZE}" ] && [ -z "${cli_ADDSWAP}" ]; then
  echo
  echo "ABORTING. You must specify the -a option with the -s option."
  echo
  usage;
  exit;
fi

# is the -i flag specified without the -r flag?
if [ ! -z "${cli_SWAPID}" ] && [ -z "${cli_REMOVESWAP}" ]; then
  echo
  echo "ABORTING. You must specify the -r option with the -i option."
  echo
  usage;
  exit;
fi

# Rangle our vars
#
if [ -n "${cli_SWAPID}" ]; then
  if [[ ${#cli_SWAPID} -eq ${SWAPIDLEN} ]]; then
    SWAPID=${cli_SWAPID}
    if [ "${DEBUG}" -ne 0 ]; then
      echo "DEBUG:   swapid: ${SWAPID}"
    fi
  else
    echo
    echo "ABORTING. Invalid swap id specified: \"${cli_SWAPID}\""
    echo
    usage
    exit 1
  fi
fi

if [ -n "${cli_SWAPSIZE}" ]; then
  if [[ ${cli_SWAPSIZE} =~ ^-?[0-9]+$ ]]; then
    SWAPSIZE=${cli_SWAPSIZE}
    if [ "${DEBUG}" -ne 0 ]; then
      echo "DEBUG: swapsize: ${SWAPSIZE}"
    fi
    if [[ ${SWAPSIZE} -lt 1024 ]]; then
      echo
      echo "WARNING: Minimum swap size is 1024. Specified swap size ignored."
      echo
    fi
  else
    echo
    echo "ABORTING. Invalid swap size specified: \"${cli_SWAPSIZE}\""
    echo
    usage
    exit 1
  fi
fi

# check system compatibility
#
echo "Analyzing system for fake-swap status..."

runos="unknown"

unamestr=$(${PATH_UNAME})
case "${unamestr}" in
"Linux" )
  runos="linux"
  ;;
"FreeBSD" )
  runos="freebsd"
  ;;
"Darwin" )
  runos="osx"
  ;;
"SunOS" )
  runos="solaris"
  ;;
* )
  ;;
esac

if [ "${runos}" != "linux" ]; then
  echo "ABORTING. Target OS doesn't appear to be Linux."
  echo
  exit 1
fi

# we are on linux, so which distro?
if [ ! -e /etc/os-release ]; then
  echo "ABORTING. Unable to determine Linux variant."
  echo
  exit 1
fi
readconfig osconfig < "/etc/os-release"
if [[ "${osconfig[NAME]}" = "" ]] || [[ "${osconfig[VERSION]}" = "" ]]; then
  echo "ABORTING. Unable to determine Linux variant."
  echo "The /etc/os-release file may be incomplete."
  echo
  exit 1
fi

echo "Detected Linux variant: ${osconfig[NAME]} [${osconfig[VERSION]}]"


##
## All checks done. DO IT!
##

#
# Add swap
#

if [[ ${ADDSWAP} -ne 0 ]] && [[ ${SWAPSIZE} -gt 0 ]]; then
  #
  # -Add specific sized swap (-a with -s option)
  #
  addSwap ${SWAPSIZE}

  exit 0
elif [[ ${ADDSWAP} -ne 0 ]]; then
  #
  # -Add default sized swap
  #
  addSwap

  exit 0
fi

#
# Remove swap
#

if [[ ${REMOVESWAP} -ne 0 ]] && [[ -n "${SWAPID}" ]]; then
  #
  # -Remove specific swap (-r with -i option)
  #
  removeSwap ${SWAPID}

  exit 0
elif [[ ${REMOVESWAP} -ne 0 ]]; then
  #
  # -Remove all swap
  #
  removeSwap

  exit 0
fi

#
# List swap
#
if [[ ${LISTSWAP} -ne 0 ]]; then
  listswap

  exit 0
fi
