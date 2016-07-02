# ZFSonLinux stable version
zol_version="0.6.5.7"

# The ZOL source hashes are from zfsonlinux.org
zfs_src_hash="4a9e271bb9a6af8d564e4d5800e4fff36224f1697b923a7253659bdda80dc590"
spl_src_hash="dc8690e407183eeb7a6af0e7692d6e0a1cd323d51dd1aa492522c421b1924ea0"
zfs_bash_completion_hash="b60214f70ffffb62ffe489cbfabd2e069d14ed2a391fac0e36f914238394b540"
zfs_initcpio_install_hash="dd8901295349da729e23ec5d1da57d49d31f3d4ea2f9ab20398469e9e371c504"
zfs_initcpio_hook_hash="5f749dbe3b853c5b569d5050b50226b53961cf1fa2cfc5cea0ecc3df75885d2f"

# Notification address
email="jeezusjr@gmail.com"

# Repository path and name
repo_name="archzfs"
repo_name_test="archzfs-testing"
repo_basepath="/data/pacman/repo"

# SSH login address (can use ssh config Hosts)
remote_login="webfaction"

# The signing key to use to sign packages
gpg_sign_key='0EE7A126'

chroot_path="/opt/chroot/x86_64/$(whoami)"

# Package backup directory
package_backup_dir="/data/pacman/repo/archive_archzfs"

export archiso_url="https://mirrors.kernel.org/archlinux/iso/2016.05.01/archlinux-2016.05.01-dual.iso"
export archiso_sha="1ce0bbedb9fb77facda61cb8d4df763159745b18"
