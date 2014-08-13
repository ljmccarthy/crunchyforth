#! /bin/sh

echo CrunchyForth for Linux by Luke McCarthy

fail() {
  echo Failed to compile image.
  exit 1
}

echo Assembling...
nasm -f bin cf.linux.asm -o cf || fail
echo Image compiled successfully.
