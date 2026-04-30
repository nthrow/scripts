#!/usr/bin/env bash

if [ -z "$(type -p unzip)" ] || [ -z "$(type -p wget)" ]; then
  echo "This script requires both unzip and wget to already be installed."
  exit 1
fi

if [ "$#" -gt 1 ]; then
  echo "Only one argument supported, specifying install location."
  exit 1
else
#  instLoc=$1 # You can also hardcode that by changing the value of this variable.
  instLoc="/opt/nat/apps/brave"
fi

function getRemVer() {
  perpage=100
  pagelimit=1
  repopage="https://api.github.com/repos/brave/brave-browser/releases?per_page=${perpage}&page="
  page=$(mktemp)

  wget -q -O $page "${repopage}${i}"
  version="$(grep -Eo -e 'name":\s"Release v([0-9]+?\.[0-9]+?\.[0-9]+?)"' \
    -e '"prerelease": \w+?\b' < $page | \
    grep -A 1 'name' | \
    grep -B 1 'false' | \
    grep -Eo '([0-9]+?\.[0-9]+?\.[0-9]+?)')"
  for i in $(echo ${version}); do
    grep -Eo "brave-browser-${i}-linux-amd64.zip" < $page 1>/dev/null && echo $i && break
  done

  rm $page
}

function getLocVer() {
  if [ "$(ls -A ${instLoc})" ]; then
    echo "`${instLoc}/brave --version |awk '{print $3}' |cut -d\. -f2,3,4`"
  else
    echo 0
  fi
}

function main() {
  if [ ! -d $instLoc ]; then
    read -p "Installation location does not exist.  Should I create it for you? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      mkdir -p $instLoc
    else
      echo "Exiting as install location does not exist and the user does not wish to create it."
      exit 0
    fi
  fi

  locVer=$(getLocVer)
  remVer=$(getRemVer)

  if [ "$(printf '%s\n' "$remVer" "$locVer" | sort -V | head -n1)" = "$remVer" ]; then
    echo "Your Brave Browser is up to date!"
    exit 0
  else
    read -p "There is an update for Brave Browser available. Should I install that? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      echo "Updating Brave Browser.  Your previous session will be gracefully closed..."
      release="https://github.com/brave/brave-browser/releases/download/"
      tmpLoc="/tmp/brave-browser-${remVer}-linux-amd64.zip"
      wget -q -nc "${release}v${remVer}/brave-browser-${remVer}-linux-amd64.zip" -O ${tmpLoc}
      pkill -HUP --oldest brave
      unzip -q -o $tmpLoc -d $instLoc
      nohup $instLoc/brave &>/dev/null &
      rm $tmpLoc
      exit 0
    fi
  fi
}

main
