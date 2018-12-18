#!/bin/bash -e
cd "$(dirname "$0")"

test -e ./scripting/compiled || mkdir ./scripting/compiled

sourcefile=csgo-remote.sp

smxfile="`echo $sourcefile | sed -e 's/\.sp$/\.smx/'`"
echo -e "\nCompiling $sourcefile ..."
./scripting/spcomp ./scripting/$sourcefile -o./scripting/compiled/$smxfile

cp ./scripting/compiled/$smxfile ./plugins/$smxfile
