#!/usr/bin/env bash

# chw.sh
# --------------
# Very simple tool to wrap chrooting into a build environment
#
# Author: Samuel Hart, 2011, <hartsn@gmail.com>
# https://bitbucket.org/criswell/chroot-wrap
#
# To the extent possible under law, the author(s) have dedicated all copyright
# and related and neighboring rights to this software to the public domain
# worldwide. This software is distributed without any warranty.
#
# You should have received a copy of the CC0 Public Domain Dedication along
# with this software. If not, see
# http://creativecommons.org/publicdomain/zero/1.0/

ALL_DIRS=$(cat <<EOF
proc
dev
dev/pts
sys
EOF
)

PROGNAME=${0##*/}

SRC_PROC=$$

MY_CWD=`pwd`

TMP_ROOT=/tmp/chw_work

trace() {
    DATESTAMP=$(date +'%Y-%m-%d %H:%M:%S %Z')
    echo "${DATESTAMP} : ${*}"
}

mount_all() {
    local CH_PATH=$(cat "${TMP_ROOT}/${1}.cfg")
    for DIR in $ALL_DIRS
    do
        mountpoint -q ${CH_PATH}/${DIR}
        if [ $? -eq 1 ] ; then
            trace "binding /${DIR} ${CH_PATH}/${DIR}"
            mount --bind /${DIR} ${CH_PATH}/${DIR}
            echo "${DIR}" >> "${TMP_ROOT}/${1}.mounts"
        fi
    done
}

umount_all() {
    local CH_PATH=$(cat "${TMP_ROOT}/${1}.cfg")
    REV_DIRS=$(sort -r "${TMP_ROOT}/${1}.mounts")
    for DIR in $REV_DIRS
    do
        trace "unmounting /${DIR} ${CH_PATH}/${DIR}"
        umount ${CH_PATH}/${DIR}
    done
    rm -f "${TMP_ROOT}/${1}.mounts"
}

clean_bashrc() {
    local CH_PATH=$(cat "${TMP_ROOT}/${1}.cfg")
    local TMP_FILE=`mktemp /tmp/chw-XXXXXX`
    sed '/## CHR_BEGIN/,/## CHR_END/d' ${CH_PATH}/root/.bashrc > ${TMP_FILE}
    cp -f ${TMP_FILE} ${CH_PATH}/root/.bashrc
    rm -f ${TMP_FILE}
}

make_bashrc() {
    clean_bashrc "${1}"

    local CH_PATH=$(cat "${TMP_ROOT}/${1}.cfg")

    echo "## CHR_BEGIN" >> ${CH_PATH}/root/.bashrc
    echo "PS1='\033[1;33m\](${CH_PATH})\033[0m\][\033[1;31m\]\u\033[0m\]@\033[1;31m\]\h\033[0m\] \033[1;31m\]\w\033[0m\]]\n# '" >> ${CH_PATH}/root/.bashrc
    echo "export PS1" >> ${CH_PATH}/root/.bashrc
    echo "## CHR_END" >> ${CH_PATH}/root/.bashrc
}

chw_addclient() {
    touch "${TMP_ROOT}/client_list"
    echo "${SRC_PROC}" >> "${TMP_ROOT}/client_list"

    touch "${TMP_ROOT}/${1}_clients"
    echo "${SRC_PROC}" >> "${TMP_ROOT}/${1}_clients"
}

chw_rmclient() {
    grep -v $SRC_PROC "${TMP_ROOT}/client_list" > "${TMP_ROOT}/client_list.new"
    rm -f "${TMP_ROOT}/client_list"
    mv "${TMP_ROOT}/client_list.new" "${TMP_ROOT}/client_list"

    grep -v $SRC_PROC "${TMP_ROOT}/${1}_clients" > "${TMP_ROOT}/${1}_client.new"
    rm -f "${TMP_ROOT}/${1}_clients"
    mv "${TMP_ROOT}/${1}_client.new" "${TMP_ROOT}/${1}_clients"
}

chw_setupwrap() {
    local CH_HASH=$1
    local CH_PATH=$2
    if [ ! -e "${TMP_ROOT}/${CH_HASH}.cfg" ]; then
        touch "${TMP_ROOT}/${CH_HASH}.cfg"
        echo "$CH_PATH" > "${TMP_ROOT}/${CH_HASH}.cfg"
    fi

    if [ ! -e "${TMP_ROOT}/${CH_HASH}.mounts" ]; then
        touch "${TMP_ROOT}/${CH_HASH}.mounts"
    fi
}

# Initializes the chw work environment if it is not there
chw_init() {
    if [ -d "$TMP_ROOT" ]; then
        if [ -L "$TMP_ROOT" ]; then
            # We don't play these sorts of shenanigans, nuke it..
            rm "$TMP_ROOT"
        else
            chw_addclient "${1}"

            chw_setupwrap "${1}" "${2}"
            mount_all "${1}"
            make_bashrc "${1}"
        fi
    else
        trace "First in- Making top-level chw work environment... ${TMP_ROOT}"
        mkdir -p "$TMP_ROOT"
        chw_addclient "${1}"

        chw_setupwrap "${1}" "${2}"
        mount_all "${1}"
        make_bashrc "${1}"
    fi
}

# Shutdown the chw work environment, if we're the last one out
chw_shutdown() {
    if [ -d "$TMP_ROOT" ]; then
        chw_rmclient "${1}"

        if [ $(wc -l "${TMP_ROOT}/${1}_clients" | cut -d ' ' -f1) -eq 0 ]; then
            trace "Last out of chroot, cleaning up chroot..."
            umount_all "${1}"
            clean_bashrc "${1}"
            rm -f "${TMP_ROOT}/${1}_clients"
            rm -f "${TMP_ROOT}/${1}.cfg"
        fi

        if [ $(wc -l "${TMP_ROOT}/client_list" | cut -d ' ' -f1) -eq 0 ]; then
            trace "Last out- cleaning up the chw work environment..."
            rm -f "${TMP_ROOT}/client_list"
            rmdir "${TMP_ROOT}"
        fi
    else
        trace "Something very bad has happened during shutdown, our chw work environment seems to be missing!"
    fi
}

usage()
{
    cat <<EOF

Usage: $PROGNAME CHROOT_PATH [OPTIONAL PARAMETERS PASSED TO CHROOT]
Where CHROOT_PATH is the path to a given chroot environment.

$PROGNAME will set up the proper mount points for the chroot, and chroot into
the environment.

$PROGNAME must be run as root.
EOF
}

# Must be run as root
if [ "$(id -u)" != "0" ]; then
    trace "This script must be run as root!"
    exit 1
fi

# Get our chroot path
if [ -n "$1" ]; then
    CHROOT_PATH=$1
    shift 1

    # Check on the chroot path
    if [ -d "$CHROOT_PATH" ]; then
            HASH_ID=$(echo "${CHROOT_PATH}" | shasum | cut -d ' ' -f1)

            chw_init ${HASH_ID} ${CHROOT_PATH}
            chroot ${CHROOT_PATH} ${*}
            chw_shutdown ${HASH_ID}
    else
        trace "The chroot path '${CHROOT_PATH}' does not exist or is not a directory!"
        exit 1
    fi
else
    trace "Missing chroot path!"
    usage
fi

# vim:set ai et sts=4 sw=4 tw=80:
