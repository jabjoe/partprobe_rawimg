#! /bin/bash

img=$1
dev=$2

if [ -z "$img" -o -z "$dev" ]
then
  echo "Requires <raw-img> <target-dev>"
  exit -1
fi

loopdev=$(losetup -f)

losetup -P $loopdev "$img"

dd if="$img" of="$dev" bs=1M count=1

partprobe "$dev"
partprobe $loopdev
sleep 0.1
partitions=$(lsblk -f $loopdev | awk '{print $1,$2}' | grep ─)

while read line
do
  read -ra pair <<< "$line"

  devpart=${pair[0]}
  devpart="/dev/${devpart:2}"
  devtype=${pair[1]}
  part="${devpart/$loopdev/}"
  outpart=$dev$part
  if [ ! -e $outpart ]
  then
    outpart=$dev${part:1}
  fi
  partclone.$devtype -b -d -s "$devpart" -o "$outpart"
done <<< "$partitions"

losetup -D $loopdev
