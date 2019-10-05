#! /bin/bash
for file in $( ls test | grep -E '^.*\.lua$')
do
    luac -o "test/"${file}"c" "test/"$file
    echo "[------"$file"------]"
    lua ylua.lua "test/"$file"c"
done

