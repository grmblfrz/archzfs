#!/bin/bash

cat <<-EOF > "${TARGET_DIR}/usr/local/bin/${BASE_CONFIG_SCRIPT}"
    echo '${FQDN}' > /etc/hostname
    /usr/bin/ln -s /usr/share/zoneinfo/${TIMEZONE} /etc/localtime
    echo 'KEYMAP=${KEYMAP}' > /etc/vconsole.conf
    /usr/bin/sed -i 's/#${LANGUAGE}/${LANGUAGE}/' /etc/locale.gen
    /usr/bin/locale-gen
    /usr/bin/mkinitcpio -p linux
    /usr/bin/usermod --password ${PASSWORD} root

    # https://wiki.archlinux.org/index.php/Network_Configuration#Device_names
    /usr/bin/ln -s /dev/null /etc/udev/rules.d/80-net-setup-link.rules
    /usr/bin/ln -s '/usr/lib/systemd/system/dhcpcd@.service' '/etc/systemd/system/multi-user.target.wants/dhcpcd@eth0.service'

    # Configure ssh
    sed -e '/^#PermitRootLogin prohibit-password$/c PermitRootLogin yes' \
        -e '/^#UseDNS no$/c UseDNS no' \
        -i /etc/ssh/sshd_config

    /usr/bin/systemctl enable sshd.service

EOF
