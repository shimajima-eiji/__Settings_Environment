#!/bin/sh
### need `apt install translate-shell`
### curl -sf https://raw.githubusercontent.com/shimajima-eiji/Settings_Environment/main/for_WSL/translate.sh | sh -s "(変換したいファイルパス)"
### .gitや.githubディレクトリなど、隠しファイルは対象にしない。

# transコマンドが使えなければやらない
if [ -z "$(which trans)" ]
then
  echo "[Stop] not found 'trans(translate-shell)'"
  exit 1
fi

# ディレクトリパスを引数に指定されていない場合はやらない
arg=$1
if ! [ -d "${arg}" -o -f "${arg}" ]
then
  echo "[Stop] Require arg. or arg isn't file or directory. ${arg}"
  exit 1
fi

# API制限を回避する
wait () {
  # FYI:
  # - https://qiita.com/eggplants/items/f3de713add0bb4f0548f
  # - https://webbibouroku.com/Blog/Article/linux-rand
  sleep "$(($(od -An -tu2 -N2 /dev/urandom | tr -d ' ')%5))"
}

# [Hint] 変換したファイルや行数が知りたい場合は、ファイル行数からカウントすべき
run () {
  echo  # メッセージを見やすくするため、改行する
  arg=$1

  # バイナリファイルは変換できないのでスキップ
  if [ -n "$(file --mime ${arg} | grep 'charset=binary')" ]
  then
    echo "[Skip] File is binary: ${arg}"
    return 1
  fi

  # ファイル名が「_」から始まる場合は対象にしない
  if [ "$(basename "${arg}" | cut -c1 )" = "_" ]
  then
    echo "[Skip] Filename is exclude pattern[_]: ${arg}"
    return 1
  fi

  # 対象ファイルが、過去に変換のために作成したものである場合はスキップ
  if [ -n "$(echo ${arg} | grep '_en.md')" -o -n "$(echo ${arg} | grep '_ja.md')" ]
  then
    echo "[Skip] translated file: ${arg}"
    echo "[Hint] '(name)_ja.md' and '(name)_en.md' is translate file."
    return 1
  fi

  #  既に変換済みのファイルの場合はスキップする（更新時は変換ファイルを手動削除すること）
  transen_file="${arg%.*}_en.md"
  transja_file="${arg%.*}_ja.md"
  if [ -f "${transen_file}" -o -f "${transja_file}" ]
  then
    echo "[Skip] Already translate: ${transen_file} or ${transja_file}"
    echo "[Hint] Case: updated ${arg}. 'rm (${transen_file} or ${transja_file})' after push."
    return 1
  fi

  # 言語検出。ファイルの一行目を取得する。
  # ここでは基本的に日本語に変換するが、入力が日本語だったり、言語を検出できない場合は英語にする
  target="ja"
  source="en"
  result="$(trans -b :${target} "$(head -n 1 "${arg}")" 2>/dev/null)"
  transfile="${transja_file}"

  if [ "$(head -n 1 "${arg}")" = "${result}" -o -n "$(echo "${result}" | grep 'Did you mean: ')" ]
  then
    target="en"
    source="ja"
    
    transfile="${transen_file}"
  fi

  # ファイルから全ての行を抽出して変換する。
  echo
  echo "[INFO] Run translate(${target}): ${arg} -> ${transfile}"

  row_count=0
  echo >curl_gas.log
  while read line
  do
    row_count=$((row_count+1))
    if [ -n "${line}" ]
    then
    
      # jqコマンドが使えるならGASに問い合わせてみる
      source ~/.env  # GAS_TRANSLATE_ENDPOINTを呼び出す
      if [ "$(which jq)" -a -n "${GAS_TRANSLATE_ENDPOINT}" ]
      then
        curl -L "${GAS_TRANSLATE_ENDPOINT}?text=${line}&source=${source}&target=${target}" >>curl_gas.log 2>/dev/null
        if [ "$(cat curl_gas.log | jq .result)" = "true" ]
        then
          translate_line="$(cat curl_gas.log | jq .translate)"
          echo "${translate_line}" >>${transfile}
          echo "[TRANSLATE PROGRESS] ${row_count}: ${line} -> ${translate_line}"

        # curlに失敗した場合は、当初案通りtranslate-shellを使う
        else
          translate_line="$(trans -b :${target} "${line}" 2>/dev/null)"
          echo "${translate_line}" >>${transfile}
          echo "[TRANSLATE PROGRESS] ${row_count}: ${line} -> ${translate_line}"
          wait  # API制限に引っかかるので、待機時間を入れる
        fi

      # jqが使えない場合は、当初案通りtranslate-shellを使う
      else
        translate_line="$(trans -b :${target} "${line}" 2>/dev/null)"
        echo "${translate_line}" >>${transfile}
        echo "[TRANSLATE PROGRESS] ${row_count}: ${line} -> ${translate_line}"
        wait  # API制限に引っかかるので、待機時間を入れる
      fi

    else
      echo >>${transfile}
      echo "[TRANSLATE PROGRESS]"
    fi
  done <"${arg}"

  echo "[COMPLETE] Done ${arg} -> ${transfile}"
  echo
  return 0
}

count=0  # 変換したファイル数をカウント
find_file () {
  arg="$1"

  # 変数がファイルなら変換処理
  if [ -f "${arg}" ]
  then
    run "${arg}"

    if [ $? -eq 0 ]
    then
      count=$((count+1))
    fi

  # 変数がファイル以外ならディレクトリを移動してサーチする
  else
    cd "${arg}"

    for path in *
    do
      find_file "${path}"
    done
    cd ..
    echo
  fi
}

find_file "${arg}"
echo "[COMPLETE] translate files:"
echo ${count}