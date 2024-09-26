Usage
=====

Get a RAW disk image of disk:

    sudo ./partprobe_dev2rawimg.sh /dev/mmcblk0 my_disk.img


Write RAW disk image to disk:

    sudo partprobe_rawimg2dev.sh my_disk.img /dev/mmcblk0
