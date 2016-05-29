#!/bin/bash


args=("$@")
script_name=$(basename $0)
script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"


if ! source ${script_dir}/../lib.sh; then
    echo "!! ERROR !! -- Could not load lib.sh!"
    exit 155
fi
source_safe "${script_dir}/../conf.sh"


ssh_cmd="/USr/sbin/ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o ConnectTimeout=3 -p 2222"
ssh_pass="sshpass -p azfstest"
ssh="${ssh_pass} ${ssh_cmd}"
test_pkg_workdir="archzfs"
archiso_basename=$(basename ${archiso_url})
base_image_basename="archzfs-base-archiso-${archiso_basename:10:-9}"


export packer_work_dir="${script_dir}/packer_work"
export base_image_output_dir="${packer_work_dir}"


run_cmd_show_and_capture_output "find ${script_dir} -iname '*archzfs-base-*' -printf \"%P\\n\" | sort -r | head -n 1"
if [[ ${run_cmd_output} == "" ]]; then
    export base_image_name="${base_image_basename}-build-$(date +%Y.%m.%d).qcow2"
else
    export base_image_name="${run_cmd_output}"
fi


export base_image_path="${script_dir}/${base_image_name}"
export work_image_randname="${base_image_name%.qcow2}_${RANDOM}.qcow2"
export PACKER_CACHE_DIR="packer_cache"


usage() {
    echo "${script_name} - A test script for archzfs"
    echo
    echo "Usage: ${script_name} [options] [mode] [command [command option] [...]"
    echo
    echo "Options:"
    echo
    echo "    -h:    Show help information."
    echo "    -n:    Dryrun; Output commands, but don't do anything."
    echo "    -d:    Show debug info."
    echo "    -R:    Re-use existing archzfs test packages."
    echo
    echo "Modes:"
    echo
    for ml in "${mode_list[@]}"; do
        mn=$(echo ${ml} | cut -f2 -d:)
        md=$(echo ${ml} | cut -f3 -d:)
        echo -e "    ${mn}    ${md}"
    done
    echo
    echo "Commands:"
    echo
    echo "    base   Build the base image."
    echo "    test   Build test packages."
    exit 155
}


generate_mode_list "${script_dir}/../src/kernels"


if [[ $# -lt 1 ]]; then
    usage
fi


for (( a = 0; a < $#; a++ )); do
    if [[ ${args[$a]} == "base" ]]; then
        commands+=("base")
    elif [[ ${args[$a]} == "test" ]]; then
        commands+=("test")
    elif [[ ${args[$a]} == "-R" ]]; then
        commands+=("reuse")
    elif [[ ${args[$a]} == "-n" ]]; then
        dry_run=1
    elif [[ ${args[$a]} == "-d" ]]; then
        debug_flag=1
    elif [[ ${args[$a]} == "-h" ]]; then
        usage
    else
        check_mode "${args[$a]}"
        debug "have mode '${mode}'"
    fi
done


if [[ ${debug_flag} -eq 1 ]]; then
    debug "Current environment:"
    ( set -o posix ; set | grep -v "\(LESS*\|LS_*\)")
    echo
fi


build_test_packages() {
    msg "Building test packages for target ${mode}"
    run_cmd "${script_dir}/../build.sh -h | tee ${script_dir}/testoutput.txt"
}


copy_latest_packages() {
    msg2 "Creating package arch directories"
    run_cmd "[[ -d ${test_pkg_workdir} ]] && rm -rf ${test_pkg_workdir}"
    run_cmd "mkdir -p ${test_pkg_workdir}/{x64,x32}"
    run_cmd 'find ../../ -type f -name "'"*$AZT_PKG_TYPE"'*x86_64.pkg.tar.xz" -printf "%C@ %p\n" | sort -rn | head -n 4 | awk "{ print \$2 }" | xargs -i cp {} "'"${test_pkg_workdir}"'/x64/"'
    if ls ${test_pkg_workdir}/x64/ | wc -w ]]; then
        error "No packages found in ${test_pkg_workdir}/x64/"
        exit 1
    fi
}


if have_command "base"; then
    msg "Building arch base image"

    if [[ -d "${packer_work_dir}/output-qemu" ]]; then
        msg2 "Deleting '${packer_work_dir}/output-qemu' because it should not exist"
        run_cmd "rm -rf ${packer_work_dir}/output-qemu"
    fi

    if [[ ! -d "${packer_work_dir}" ]]; then
        msg2 "Creating '${packer_work_dir}' because it does not exist"
        run_cmd "mkdir ${packer_work_dir}"
    fi

    if [[ ! -f "${packer_work_dir}/mirrorlist" ]]; then
        msg2 "Generating pacman mirrorlist"
        run_cmd "/usr/bin/reflector -c US -l 5 -f 5 --sort rate 2>&1 > ${packer_work_dir}/mirrorlist"
    fi

    msg2 "Using packer to build the base image ..."

    # Uncomment to enable packer debug
    # export PACKER_LOG=1

    run_cmd "check_symlink '${script_dir}/arch-zfs-base/setup-test-image.sh' '${packer_work_dir}/setup-test-image.sh'"
    run_cmd "check_symlink '${script_dir}/poweroff.timer' '${packer_work_dir}/poweroff.timer'"
    run_cmd "cd ${packer_work_dir} && packer-io build -debug ${script_dir}/arch-zfs-base/arch-zfs-base.json"

    msg "Moving the compiled base image"
    run_cmd "mv -f ${base_image_output_dir}/output-qemu/packer-qemu ${base_image_path}"
fi


if have_command "test";  then
    msg "Testing package target '${mode}'"

    if ! have_command "reuse"; then
        msg2 "Building test packages"
        build_test_packages
    fi

    msg2 "Copying test packages"
    copy_latest_packages

    msg2 "Cloning ${base_image_path}"
    run_cmd "cp ${base_image_path} ${work_image_randname}"

    msg "Booting VM clone..."
    cmd="qemu-system-x86_64 -enable-kvm "
    cmd+="-m 4096 -smp 2 -redir tcp:2222::22 -drive "
    cmd+="file=${work_image_randname},if=virtio"
    run_cmd "${cmd}" &

    if [[ -z "${debug_flag}" ]]; then
        msg "Waiting for SSH..."
        while :; do
            run_cmd "${ssh} root@localhost echo &> /dev/null"
            if [[ ${run_cmd_return} -eq 0 ]]; then
                break
            fi
        done
    fi

    msg2 "Copying the latest packages to the VM"
    copy_latest_packages
    run_cmd "rsync -vrthP -e '${ssh}' archzfs/x64/ root@localhost:"
    run_cmd "${ssh} root@localhost pacman -U --noconfirm '*.pkg.tar.xz'"

    # msg2 "Cloning ZFS test suite"
    # run_cmd "${ssh} root@localhost git clone https://github.com/zfsonlinux/zfs-test.git /usr/src/zfs-test"
    # run_cmd "${ssh} root@localhost chown -R zfs-tests: /usr/src/zfs-test/"

    # msg2 "Building ZFS test suite"
    # run_cmd "${ssh} root@localhost 'cd /usr/src/zfs-test && ./autogen.sh && ./configure'"
    # run_cmd "${ssh} root@localhost 'cd /usr/src/zfs-test && ./autogen.sh && ./configure && make test'"

    # msg2 "Cause I'm housin"
    # run_cmd "${ssh} root@localhost systemctl poweroff &> /dev/null"

    # wait
fi
