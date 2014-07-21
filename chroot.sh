#!/bin/bash
CHROOT=$1
echo $CHROOT
shift
if [ "$CHROOT" == "" ]; then
    echo "invalid usage"
    exit 1
fi
mount -o bind /proc $CHROOT/proc
mount -o bind /dev $CHROOT/dev
mount -o bind /sys $CHROOT/sys
chroot $CHROOT "$@"
RESULT=$?
umount $CHROOT/sys
umount $CHROOT/dev
umount $CHROOT/proc
exit $RESULT
