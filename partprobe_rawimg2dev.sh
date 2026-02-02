#! /bin/bash

img=$1
dev=$2

if [ -z "$img" -o -z "$dev" ]
then
  echo "Requires <raw-img> <target-dev>"
  exit -1
fi

[ -n "$(which kpartx)" ] || { echo "No kpartx found."; exit -1; }

loopdev=/dev/mapper/$(kpartx -av "$img" | head -n1 | awk '{print $3}')
loopdev=${loopdev/p1/}

gdisk -l $loopdev | grep "MBR only"

if [ "$?" = "0" ]
then
    echo "MBR partition table"
    dd if="$img" of=$dev bs=1M count=1 conv=notrunc
else
    echo "GPT partition table"
    sgdisk --backup="$dev".table "$img"
    sgdisk --load-backup="$dev".table "$dev"

    [ "$?" = "0" ] || { echo "Partition table clone failed."; exit -1; }

    sgdisk -C "$dev" # Recompute CHS values in protective or hybrid MBR.
    sgdisk -e "$dev" # Move backup GPT data structures to the end of the disk.
fi


partprobe "$dev"

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

kpartx -d "$img"
