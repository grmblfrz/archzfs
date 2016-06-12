#!/bin/bash

export TARGET_DIR='/mnt'

export RUNNER_SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Additional packages to install after base and base-devel
export PACKAGES="gptfdisk openssh syslinux parted lsscsi rsync vim git tmux htop tree python2 archzfs-lts"


chroot_fs_config_root() {
    export DISK='/dev/vda'
    export ROOT_PARTITION="${DISK}1"

    echo "==> clearing partition table on ${DISK}"
    /usr/bin/sgdisk --zap ${DISK}

    echo "==> destroying magic strings and signatures on ${DISK}"
    /usr/bin/dd if=/dev/zero of=${DISK} bs=512 count=2048
    /usr/bin/wipefs --all ${DISK}

    echo "==> creating root partition on ${DISK}"
    /usr/bin/sgdisk --new=1:0:0 ${DISK}

    echo "==> setting ${DISK} bootable"
    /usr/bin/sgdisk ${DISK} --attributes=1:set:2

    echo "==> The disk "
    /usr/bin/sgdisk -p ${DISK}

    echo "==> The disk should be bootable"
    /usr/bin/sgdisk -A=1:show ${DISK}

    echo '==> creating /root filesystem (ext4)'
    /usr/bin/mkfs.ext4 -F -m 0 -q -L root ${ROOT_PARTITION}

    echo "==> mounting ${ROOT_PARTITION} to ${TARGET_DIR}"
    /usr/bin/mount -o noatime,errors=remount-ro ${ROOT_PARTITION} ${TARGET_DIR}
}


setup_exit() {
    echo '==> installation complete!'
    # /usr/bin/sleep 10
    # /usr/bin/umount /mnt/repo
    # /usr/bin/umount /mnt/var/cache/pacman/pkg
    # /usr/bin/umount ${TARGET_DIR}
    # /usr/bin/umount /var/cache/pacman/pkg
    # /usr/bin/umount /repo
    # /usr/bin/systemctl reboot
}
