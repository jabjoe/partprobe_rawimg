#! /bin/bash

dev=$1
img=$2

if [ -z "$img" -o -z "$dev" ]
then
  echo "Requires <source-dev> <raw-img>"
  exit -1
fi

[ -n "$(which sgdisk)" ] || { echo "No sgdisk found."; exit -1; }
[ -n "$(which sgdisk)" ] || { echo "No sgdisk found."; exit -1; }
[ -n "$(which gdisk)" ] || { echo "No gdisk found."; exit -1; }
[ -n "$(which kpartx)" ] || { echo "No kpartx found."; exit -1; }

bytes=$(blockdev --getsize64 $dev)

# Round up to the nearest gigabyte
bytes=$(echo $bytes | python -c "print(round(float(input())/(1024 * 1024 * 1024))*(1024 * 1024 * 1024))")

echo "Image is $bytes bytes"

rm -rf "$img"
fallocate -l$bytes "$img"

gdisk -l $dev | grep "MBR only"

if [ "$?" = "0" ]
then
    echo "MBR partition table"
    dd if=$dev of="$img" bs=1M count=1 conv=notrunc
else
    echo "GPT partition table"
    sgdisk --backup="$img".table "$dev"
    sgdisk --load-backup="$img".table "$img"

    [ "$?" = "0" ] || { echo "Partition table clone failed."; exit -1; }

    sgdisk -C "$img" # Recompute CHS values in protective or hybrid MBR.
    sgdisk -e "$img" # Move backup GPT data structures to the end of the disk.
fi
sync

echo "Setup loopback"
loopdev=/dev/mapper/$(kpartx -av "$img" | head -n1 | awk '{print $3}')
loopdev=${loopdev/p1/}

echo "Using $loopdev"
partprobe "$dev"

sleep 1 # Should wait partitions rather flat wait, but for now....

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
    [ -e $outpart ] || { echo "No partition $devpartname"; exit -1; }
  fi
  echo "Cloning $devtype $devpart to $outpart"
  partclone.$devtype -C -b -d3 -s "$devpart" -o "$outpart"
done <<< "$partitions"

kpartx -d "$img"
