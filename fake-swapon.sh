#!/bin/bash
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

# @TODO Implement options to free swap.
#
# NOTE: To remove loop device based swap you need to do the following:
#
# >swapoff /dev/loop0
# >losetup -d /dev/loop0
#
# If you don't delete the loop device, the kernel will at some point remap the
# vm back into the table.
#

PATH=/usr/local/bin

PATH_BNAME="/usr/bin/basename"
PATH_GETOPT="/usr/bin/getopt"
PATH_CAT="/usr/bin/cat"
PATH_DD="/usr/bin/dd"
PATH_STAT="/usr/bin/stat"
PATH_SED="/usr/bin/sed"
PATH_TR="/usr/bin/tr"
PATH_UNAME="/usr/bin/uname"

PATH_MKSWAP="/usr/sbin/mkswap"
PATH_SWAPON="/usr/sbin/swapon"

# Loop device support (required for CoreOS)
#
PATH_LOSETUP="/usr/sbin/losetup"

# Swap directory
#
PATH_SWAPDIR="/root"


###### NO SERVICABLE PARTS BELOW ######
VERSION=2.0.0
PROGNAME=$(${PATH_BNAME} $0)

# reset internal vars (do not touch these here)
DEBUG=0
FORCEEXEC=0
ADDSWAP=0
LISTSWAP=0
REMOVESWAP=0

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
usage: ${PROGNAME} [options]

Add system virtual memory ("swap"). On file systems that don\'t support swap,
the loop device will be used to create "fake" swap. The "add" and "remove"
options refer only to swap managed by fake-swap.

OPTIONS:
   -a, --add-swap               Add swap to system virtual memory pool
   -i, --swap-id                Swap id (as returned by "fake-swap --list-swap")
   -l, --list-swap              List swap managed by fake-swap
   -r, --remove-swap            Remove swap managed by fake-swap from vm pool
   -d, --debug                  Turn debugging on (increases verbosity)
   -f, --force                  Execute without user prompt
   -h, --help                   Show this message
   -v, --version                Output version of this script

EOF
}

# support for old getopt (non-enhanced, only supports short param names)
#
function usage_old {
cat << EOF
usage: ${PROGNAME} [options] targetName

Add system virtual memory ("swap"). On file systems that don\'t support swap,
the loop device will be used to create "fake" swap. The "add" and "remove"
options refer only to swap managed by fake-swap.

OPTIONS:
   -a                           Add swap to system virtual memory pool
   -i                           Swap id (as returned by "fake-swap -l")
   -l                           List swap managed by fake-swap
   -r                           Remove swap managed by fake-swap from vm pool
   -d                           Turn debugging on (increases verbosity)
   -f                           Execute without user prompt
   -h                           Show this message
   -v                           Output version of this script

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
checkswap() {
  local array="$1"
  declare -g -A "$array"
  local resp rslt

  resp=$(${PATH_CAT} /proc/meminfo | ${PATH_SED} -En "s/^SwapTotal:[\ ]*([0-9]*)[\ ]*([a-zA-Z]{2,2})/\1@\2/p" )
  rslt=$?
  if [ ${rslt} -ne 0 ]; then
    eval "$array[SIZE]=unknown"
    eval "$array[UNIT]=unknown"
    return 1
  fi
  swaparray=(${resp//@/ })
  if [[ ${#swaparray[@]} -eq 2 ]] && [[ ${swaparray[0]} -gt 0 ]]; then
    eval "$array[SIZE]=${swaparray[0]}"
    eval "$array[UNIT]=${swaparray[1]}"
    return 0
  fi
}

# get list of our managed swap files
#
_getLoopSwap() {
  local array="$1"
  declare -g -A "$array"
  local device sizelimit offset autoclear roflag backfile
  local count=0
  local resp rslt
  while IFS=" " read -r device sizelimit offset autoclear roflag backfile; do
    if [[ $count -gt 0 ]]; then
      resp=$(echo ${backfile} | ${PATH_SED} -E "s:^${PATH_SWAPDIR}[/]?/swap\.(.*)$:\1:")
      rslt=$?
      if [[ -n "${resp}" ]] && [[ ${rslt} -eq 0 ]]; then
        (( _idx=count-1 ))
        eval "$array[${_idx},SWID]=${resp}"
        eval "$array[${_idx},FILE]=${backfile}"
        eval "$array[${_idx},LDEV]=${device}"
      fi
    fi
    (( count++ ))
  done <<< "$(${PATH_LOSETUP} --list)"
}

# add swap
#
addswap() {
  echo "$FUNCNAME: not impl";
}

# list swap
#
listswap() {
  echo "$FUNCNAME: not impl"
}

# remove swap
#
removeswap() {
  echo "$FUNCNAME: not impl"
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
  params="$(${PATH_GETOPT} --name "$PROGNAME" --long add-swap,swap-id:,list-swap,remove-swap,force,help,version,debug --options ai:lrfhvd -- "$@")"
else
  # Original getopt is available
  GETOPT_OLD=1
  PROGNAME=$(${PATH_BNAME} $0)
  params="$(${PATH_GETOPT} ai:lrfhvd "$@")"
fi

# check for invalid params passed; bail out if error is set.
if [ $? -ne 0 ]
then
  usage; exit 1;
fi

eval set -- "$params"
unset params

while [ $# -gt 0 ]; do
  case "$1" in
    -a | --add-swap)        cli_ADDSWAP=1; ADDSWAP=${cli_ADDSWAP};;
    -i | --swap-id)         cli_SWAPID="$2"; shift;;
    -l | --list-swap)       cli_LISTSWAP=1; LISTSWAP=${cli_LISTSWAP};;
    -r | --remove-swap)     cli_REMOVESWAP=1; REMOVESWAP=${cli_REMOVESWAP};;
    -d | --debug)           cli_DEBUG=1; DEBUG=${cli_DEBUG};;
    -f | --force)           cli_FORCEEXEC=1;;
    -v | --version)         version; exit;;
    -h | --help)            usage; exit;;
    --)                     shift; break;;
  esac
  shift
done


# Root user!!
#
if [[ $EUID -ne 0 ]]; then
  echo "Superuser (root) privileges required." 1>&2
  echo
  exit 100
fi

# Rangle our vars
#
if [ -n "${cli_FORCEEXEC}" ]; then
  FORCEEXEC=${cli_FORCEEXEC};
fi

echo "Analyzing system for swap status..."

runos=""

unamestr=$(${PATH_UNAME})
case "${unamestr}" in
"Linux" )
  runos='linux'
  ;;
"FreeBSD" )
  runos='freebsd'
  ;;
"Darwin" )
  runos='osx'
  ;;
"SunOS" )
  runos='solaris'
  ;;
* )
  runos=${platform}
  ;;
esac

if [ "${runos}" != 'linux' ]; then
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

#
# Add swap
#

# -Default
if [[ ${ADDSWAP} -ne 0 ]]; then
  checkswap swapconfig
  if [ $? -ne 0 ]; then
    echo "ABORTING. Unable to determine swap status."
    echo
    exit 1
  fi
  if [[ ${#swapconfig[@]} -eq 2 ]] && [[ ${swapconfig[SIZE]} -gt 0 ]]; then
    echo "Swap has already been enabled. Detected: ${swapconfig[SIZE]} ${swapconfig[UNIT]}"
    if [[ "${FORCEEXEC}" -eq 0 ]]; then
      # prompt user for confirmation
      if [[ "no" == $(promptConfirm "Add additional swap?") ]]
      then
        echo "ABORTING. Nothing to do."
        exit 0
      fi
    fi
  fi

  if [[ "${osconfig[NAME]}" =~ "CoreOS" ]]; then
    echo
    echo "Creating swap using the loop device method..."
    swapfile="${PATH_SWAPDIR}/lpswap.1"
    swapdev=$(${PATH_LOSETUP} -f)
    # check if a swapfile already exists, if not, create it
    resp=$(${PATH_STAT} ${swapfile} &> /dev/null)
    rslt=$?
    if [[ ${rslt} -ne 0 ]]; then
      echo "No swapfile detected. Creating it..."
      ${PATH_DD} if=/dev/zero of=${swapfile} bs=1M count=1024
      if [ $? -ne 0 ]; then
        echo "ABORTING. Couldn't create swap file: ${swapfile}"
        echo
        exit 1
      fi
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
    swapfile="${PATH_SWAPDIR}/swap.1"
    swapdev=${swapfile}
    # check if a swapfile already exists, if not, create it
    resp=$(${PATH_STAT} ${swapfile} &> /dev/null)
    rslt=$?
    if [[ ${rslt} -ne 0 ]]; then
      echo "No swapfile detected. Creating it..."
      ${PATH_DD} if=/dev/zero of=${swapfile} bs=1M count=1024
      if [ $? -ne 0 ]; then
        echo "ABORTING. Couldn't create swap file: ${swapfile}"
        echo
        exit 1
      fi
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
  echo "REMEMBER 1: You will need to manually delete the swap file when done: ${swapfile}"
  echo "REMEMBER 2: You will need to re-run this script between reboots/shutdowns."
  echo

  # check if our work was a success
  checkswap swapconfig
  if [ $? -ne 0 ]; then
    echo "ABORTING. Unable to determine swap status."
    echo
    exit 1
  fi
  if [[ ${#swapconfig[@]} -eq 2 ]] && [[ ${swapconfig[SIZE]} -gt 0 ]]; then
    echo "Swap has been enabled. Detected: ${swapconfig[SIZE]} ${swapconfig[UNIT]}"
    echo
    exit 0
  fi
fi

# -Additional (-a with -s option)

#
# Remove swap
#

# -All swap

# -Specific swap (-r with -i option)

#
# List swap
#
if [[ ${LISTSWAP} -ne 0 ]]; then
  if [[ "${osconfig[NAME]}" =~ "CoreOS" ]]; then
    printf "Swap Id     File\n"
    _getLoopSwap swaplist
    for((i=0; i<${#swaplist[@]}; i+=3)); do
      printf "%-10s  %s (%s)\n" "${swaplist[$i,SWID]}" "${swaplist[$i,FILE]}" "${swaplist[$i,LDEV]}"
    done
  else
    echo 'ack'
  fi
  echo
  exit 0
fi
