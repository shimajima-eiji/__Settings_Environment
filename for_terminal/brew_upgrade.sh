#!/bin/sh

: <<README
# brew_upgrade.sh
## 概要
インストールされていない場合はスキップする
なお、インストールは以下

#``
# Mac
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Linux
/bin/sh -c "$(curl -fsSL https://raw.githubusercontent.com/Linuxbrew/install/master/install.sh)"
#``

## READMEバージョン
2022.02.21

README

if [ ! "$(type -t __check_setup_develop_code)" = "function" ]
then
  curl -sf https://raw.githubusercontent.com/shimajima-eiji/__Operation-Maintenance/main/for_Development/setup_develop-code.sh >./setup_develop-code.sh
  source ./setup_develop-code.sh
  rm ./setup_develop-code.sh
fi

__start $0

# brewが使えない場合はやらない
if [ -z "$(which brew)" ]
then
  __skip "Not found brew."
  __end $0
fi

# 入力内容がパスとして有効でなければやらない
if [ -n "$1" ]
then
  dirname "$1" >/dev/null
  if [ "$?" -ne 0 ]
  then
    __skip "Can't create path: [$1]"
    __end $0
  fi
fi

log_file="${1:-~/logs/brew_upgrade.log}"
mkdir -p $(dirname ${log_file})
brew upgrade >${log_file}
message="[$(__green Complate)] brew upgrade. [$(date)]"
echo "${message}" | tee -a "${log_file}"

__end $0
