#! /bin/bash
if [ `pwd` != $HOME ] ;then
  echo "Please cd $HOME before running this command"
  exit 1
fi
if [ `stat -fc%t:%T "$1"` = `stat -fc%t:%T "$1/.."` ]; then
    echo "$1 safe is already close"
    exit 1
fi
if [ "$#" -ne 1 ] || [ ! -d "$1" ]; then
    echo "Usage:"
    echo "closesafe.sh directory-relative-path-to-home"
    exit 1
fi
echo deconnecting safe $1
fusermount -u ~/$1
echo !!! file created in $1  dir will NOT be encrypted from now
echo     use opensafe.sh to reactivate safe
