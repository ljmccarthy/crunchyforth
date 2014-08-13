#! /bin/sh

. ./build.native.sh
echo Writing Disk...
dd if=cf.img of=/dev/fd0 || fail
echo Done.
