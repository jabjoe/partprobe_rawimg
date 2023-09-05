#! /bin/bash

dev=$1
img=$2

if [ -z "$img" -o -z "$dev" ]
then
  echo "Requires <source-dev> <raw-img>"
  exit -1
fi

bytes=$(blockdev --getsize64 $dev)

echo "Image is $bytes bytes"

fallocate -l$bytes "$img"

loopdev=$(losetup -f)

echo "Using $loopdev"

losetup $loopdev "$img"

dd if="$dev" of="$img" bs=1M count=1

partprobe "$loopdev"
partprobe "$dev"

partitions=$(lsblk -f $dev | awk '{print $1,$2}' | grep ─)

dev_basename=$(basename $dev)

while read line
do
  read -ra pair <<< "$line"
  devpartname=${pair[0]}
  devpartname=${devpartname:2}
  echo "devpartname $devpartname"
  devpart="/dev/$devpartname"
  devpartname=${devpartname/$dev_basename/}
  devtype=${pair[1]}
  outpart="$loopdev$devpartname"
  if [ ! -e $outpart ]
  then
    outpart="$loopdev"p"$devpartname"
  fi
  echo "Cloning $devtype $devpart to $outpart"
  partclone.$devtype -C -b -d3 -s "$devpart" -o "$outpart"
done <<< "$partitions"

losetup -D $loopdev
