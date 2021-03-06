#!/bin/sh
### need `brew install cwebp`
### curl -sf https://raw.githubusercontent.com/shimajima-eiji/Settings_Environment/main/for_Mac/file2webp.sh | sh -s -- (ディレクトリパス)
### .gitや.githubディレクトリなど、隠しファイルは対象にしない。

if [ -z "$(which cwebp)" ]
then
  echo "[Stop] not found 'cwebp'."
  exit 1
fi

# ディレクトリパスを引数に指定する
arg=$1
if [ ! -d "${arg}" ]
then
  echo "[Stop] arg isn't directory. ${arg}"
  exit 1
fi

count=0  # webpファイルを作った数をカウント
find_file () {
  arg="$1"

  # 変数がファイルならwebpに変換。
  if [ -f "${arg}" ]
  then

    # 拡張子がwebp以外のファイル　かつ　webpに変換されていない場合に変換
    if [ ! "${arg##*.}" = "webp" -a ! -f "${arg%.*}.webp" ]
    then
      cwebp "${arg}" -o "${arg%.*}.webp" 2>/dev/null
      
      # webp化に成功
      if [ "$?" -eq 0 ]
      then
      
        # webpの方のファイルサイズが小さい場合
        if [ "$(wc -c ${arg} | cut -d' ' -f1)" -gt "$(wc -c ${arg%.*}.webp | cut -d' ' -f1)" ]
        then
          echo "[COMPLETE] ($(pwd)/)${arg} -> ${arg%.*}.webp"
          count=$((count+1))

        # webpの方のファイルサイズが大きい場合
        else
          rm ${arg%.*}.webp
          echo "[Deleete] ($(pwd)/${arg%.*}.webp): size larged."
        fi
        
      # webp化に失敗
      else
        echo "[Skip] ($(pwd)/${arg}) can't convert."
      fi
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
echo "${count}"
