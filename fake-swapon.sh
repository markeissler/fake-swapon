#!/bin/bash
#
# Create and enable a swap file on Linux.
#

# check if swap is enabled
#
checkswap() {
  local array="$1"
  declare -g -A "$array"

  resp=$(/usr/bin/cat /proc/meminfo | sed -En "s/^SwapTotal:[\ ]*([0-9]*)[\ ]*([a-zA-Z]{2,2})/\1@\2/p" )
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

# Root user!!
#
if [[ $EUID -ne 0 ]]; then
  echo "Superuser (root) privileges required." 1>&2
  echo
  exit 100
fi

echo "Apply swap file hack..."

runos=""

unamestr=$(uname)
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

# check if swap is already enabled
# resp=$(/usr/bin/cat /proc/meminfo | sed -En "s/^SwapTotal:[\ ]*([0-9]*)[\ ]*([a-zA-Z]{2,2})/\1@\2/p" )
# rslt=$?
# if [ ${rslt} -ne 0 ]; then
#   echo "ABORTING. Unable to determine swap status."
#   echo
#   exit 1
# fi
# swaparray=(${resp//@/ })
# if [[ ${#swaparray[@]} -eq 2 ]] && [[ ${swaparray[0]} -gt 0 ]]; then
#   echo "ABORTING. Swap has already been enabled. Detected: ${swaparray[0]} ${swaparray[1]}"
#   echo "Nothing to do."
#   echo
#   exit 0
# fi

checkswap swapconfig
if [ $? -ne 0 ]; then
  echo "ABORTING. Unable to determine swap status."
  echo
  exit 1
fi
if [[ ${#swapconfig[@]} -eq 2 ]] && [[ ${swapconfig[0]} -gt 0 ]]; then
  echo "ABORTING. Swap has already been enabled. Detected: ${swapconfig[0]} ${swapconfig[1]}"
  echo "Nothing to do."
  echo
  exit 0
fi

if [[ "${osconfig[NAME]}" =~ "CoreOS" ]]; then
  echo "Creating swap using the loop device method..."
  echo "Freeing loop device."
  swapfile="/root/swap.1"
  swapdev=$(/usr/sbin/losetup -f)
  # check if a swapfile already exists, if not, create it
  resp=$(/usr/bin/stat ${swapfile} &> /dev/null)
  rslt=$?
  if [[ ${rslt} -ne 0 ]]; then
    echo "No swapfile detected. Creating it..."
    /usr/bin/dd if=/dev/zero of=${swapfile} bs=1M count=1024
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
  /usr/sbin/losetup ${swapdev} ${swapfile}
  echo "Formatting swap file."
  /usr/sbin/mkswap ${swapdev}
  echo "Enabling swap."
  /usr/sbin/swapon ${swapdev}
elif [[ "${osconfig[NAME]}" =~ "CentOS" ]]; then
  echo "Creating swap using the file system method..."
  swapfile="/root/swap.1"
  swapdev=${swapfile}
  # check if a swapfile already exists, if not, create it
  resp=$(/usr/bin/stat ${swapfile} &> /dev/null)
  rslt=$?
  if [[ ${rslt} -ne 0 ]]; then
    echo "No swapfile detected. Creating it..."
    /usr/bin/dd if=/dev/zero of=${swapfile} bs=1M count=1024
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
  /usr/sbin/mkswap ${swapdev}
  echo "Enabling swap."
  /usr/sbin/swapon ${swapdev}
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
if [[ ${#swapconfig[@]} -eq 2 ]] && [[ ${swapconfig[0]} -gt 0 ]]; then
  echo "Swap has been enabled. Detected: ${swapconfig[0]} ${swapconfig[1]}"
  echo
  exit 0
fi

echo "All done."
