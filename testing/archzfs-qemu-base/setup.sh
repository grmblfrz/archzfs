#!/usr/bin/env bash

export SETUP_SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

export FQDN='test.archzfs.test'
export KEYMAP='us'
export LANGUAGE='en_US.UTF-8'
export PASSWORD=$(/usr/bin/openssl passwd -crypt 'azfstest')
export TIMEZONE='UTC'

export BASE_CONFIG_SCRIPT='arch-base-config.sh'
export BASE_FS_ROOT_CONFIG_SCRIPT='arch-root-fs-config.sh'


chroot_pacman_pacstrap() {
    echo '==> bootstrapping the base installation'
    /usr/bin/pacstrap -c ${TARGET_DIR} base base-devel
}


chroot_pacman_config() {
    echo "==> Setting archiso pacman mirror"
    /usr/bin/cp mirrorlist /etc/pacman.d/mirrorlist

    # # setup pacman repositories in the archiso
    # echo '==> Installing local pacman package repositories'
    # printf "\n%s\n%s\n" "[archzfs]" "Server = file:///repo/\$repo/\$arch" >> /etc/pacman.conf
    # dirmngr < /dev/null
    # pacman-key -r 0EE7A126
    # if [[ $? -ne 0 ]]; then
        # exit 1
    # fi
    # pacman-key --lsign-key 0EE7A126
    # pacman -Sy

    echo '==> Installing archzfs repo into chroot'
    printf "\n%s\n%s\n" "[archzfs]" "Server = file:///repo/\$repo/\$arch" >> /mnt/etc/pacman.conf
    /usr/bin/arch-chroot ${TARGET_DIR} dirmngr < /dev/null
    /usr/bin/arch-chroot ${TARGET_DIR} pacman-key -r 0EE7A126
    if [[ $? != 0 ]]; then
        exit 1
    fi
    /usr/bin/arch-chroot ${TARGET_DIR} pacman-key --lsign-key 0EE7A126

    # Install the required packages in the image
    /usr/bin/arch-chroot ${TARGET_DIR} pacman -Sy --noconfirm ${PACKAGES}
    if [[ $? != 0 ]]; then
        exit 1
    fi

}


chroot_bootloader() {
    # Setup the boot loader
    /usr/bin/arch-chroot ${TARGET_DIR} /usr/bin/syslinux-install_update -i -a -m
    /usr/bin/sed -i 's/sda3/vda1/' "${TARGET_DIR}/boot/syslinux/syslinux.cfg"
    /usr/bin/sed -i 's/TIMEOUT 50/TIMEOUT 10/' "${TARGET_DIR}/boot/syslinux/syslinux.cfg"
}


chroot_file_copy() {
    echo '==> Setting base image pacman mirror'
    /usr/bin/cp /etc/pacman.d/mirrorlist ${TARGET_DIR}/etc/pacman.d/mirrorlist

    echo '==> generating the filesystem table'
    /usr/bin/genfstab -p ${TARGET_DIR} >> "${TARGET_DIR}/etc/fstab"

    echo '==> Create arch-base-config.sh'
    /usr/bin/install --mode=0755 /dev/null "${TARGET_DIR}/usr/local/bin/${BASE_CONFIG_SCRIPT}"
    /usr/bin/install --mode=0755 /dev/null "${TARGET_DIR}/usr/local/bin/${BASE_FS_ROOT_CONFIG_SCRIPT}"

    # http://comments.gmane.org/gmane.linux.arch.general/48739
    echo '==> adding workaround for shutdown race condition'
    /usr/bin/install --mode=0644 poweroff.timer "${TARGET_DIR}/etc/systemd/system/poweroff.timer"

}


chroot_setup() {
    # Configures timezones and language stuffs
    local bs=""
    if [[ -f "${RUNNER_SCRIPT_DIR}/${BASE_CONFIG_SCRIPT}" ]]; then
        bs="${RUNNER_SCRIPT_DIR}/${BASE_CONFIG_SCRIPT}"
    else
        bs="${SETUP_SCRIPT_DIR}/${BASE_CONFIG_SCRIPT}"
    fi
    eval "${bs}"

    # Special filesystem configure script
    eval "${RUNNER_SCRIPT_DIR}/${BASE_FS_ROOT_CONFIG_SCRIPT}"

    echo '==> entering chroot and configuring system'
    /usr/bin/arch-chroot ${TARGET_DIR} ${BASE_CONFIG_SCRIPT}
    rm "${TARGET_DIR}${BASE_CONFIG_SCRIPT}"
}


archiso_config_nfs() {
    echo "==> create NFS mount points"
    /usr/bin/mkdir -p /mnt/var/cache/pacman/pkg
    /usr/bin/mkdir -p /repo
    /usr/bin/mkdir -p /mnt/repo

    echo "==> Setting the package cache (nfs mount)"
    mount -t nfs4 -o rsize=32768,wsize=32768,timeo=3 10.0.2.2:/var/cache/pacman/pkg /var/cache/pacman/pkg
    mount -t nfs4 -o rsize=32768,wsize=32768,timeo=3 10.0.2.2:/var/cache/pacman/pkg /mnt/var/cache/pacman/pkg

    echo "==> Mounting the AUR package repo"
    mount -t nfs4 -o rsize=32768,wsize=32768,timeo=3 10.0.2.2:/mnt/data/pacman/repo /repo
    mount -t nfs4 -o rsize=32768,wsize=32768,timeo=3 10.0.2.2:/mnt/data/pacman/repo /mnt/repo
}


# Hook for handling nfs mounts
archiso_fs_config_nfs

# Hook for handling root filesystem
chroot_fs_config_root

# Install base packages into the chroot
chroot_pacman_pacstrap

# Configure pacman inside the chroot
chroot_pacman_config

# Create work scripts in the chroot
chroot_file_copy

# Run configure scripts in chroot
chroot_setup

# Run exit hook
setup_exit
