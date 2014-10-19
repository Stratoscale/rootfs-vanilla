#!/bin/bash
CHROOT=$1
echo $CHROOT
shift
if [ "$CHROOT" == "" ]; then
    echo "invalid usage"
    exit 1
fi
mount -o bind /proc $CHROOT/proc
cp -a /dev/* $CHROOT/dev/
mount -o bind /sys $CHROOT/sys
chroot $CHROOT "$@"
RESULT=$?
umount $CHROOT/sys
umount $CHROOT/proc
exit $RESULT
