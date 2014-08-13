#! /bin/sh

echo CrunchyForth by Luke McCarthy

fail() {
  echo Failed to compile image.
  exit 1
}

echo Assembling...
nasm -f bin cf.native.asm -o cf.img || fail
echo Image compiled successfully.
