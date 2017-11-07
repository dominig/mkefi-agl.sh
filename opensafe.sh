#! /bin/bash
if [ `pwd` != $HOME ] ;then
  echo "Please cd $HOME before running this command"
  exit 1
fi
if [ `stat -fc%t:%T "$1"` != `stat -fc%t:%T "$1/.."` ]; then
    echo "$1 safe is already open"
    exit 1
fi
if [ "$#" -ne 1 ] || [ ! -d "$1" ]; then
    echo "Usage:"
    echo "opensafe.sh directory-relative-path-to-home"
    exit 1
fi

echo opening directory safe $1
encfs --idle=30 ~/.$1 ~/$1 
