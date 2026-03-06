#!/bin/bash
set -x -e

for cwcoin in cw_{core,evm,monero}
do
    if [[ "x$1" == "xasync" ]];
    then
        bash -c "cd $cwcoin; flutter pub get; dart run build_runner build --delete-conflicting-outputs; cd .." &
    else
        cd $cwcoin; flutter pub get; dart run build_runner build --delete-conflicting-outputs; cd ..
    fi
done

flutter pub get
dart run build_runner build --delete-conflicting-outputs
