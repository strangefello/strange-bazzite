#!/bin/bash

set -ouex pipefail

# Copy the contents of system_files/ of the git repo to /
cp -avf "/ctx/system_files"/. /

### Install packages

# Packages can be installed from any enabled yum repo on the image.
# RPMfusion repos are available by default in ublue main images
# List of rpmfusion packages can be found here:
# https://mirrors.rpmfusion.org/mirrorlist?path=free/fedora/updates/43/x86_64/repoview/index.html&protocol=https&redirect=1

# this installs a package from fedora repos
dnf5 install -y tmux

# Use a COPR Example:
#
# dnf5 -y copr enable ublue-os/staging
# dnf5 -y install package
# Disable COPRs so they don't end up enabled on the final image:
# dnf5 -y copr disable ublue-os/staging

#### Example for enabling a System Unit File

systemctl enable podman.socket

### Begin custom modifications
## Add my custom packages
declare -a custom_packages
custom_packages=("alsa-tools" "alsamixergui" "freeipa-client" "freeipa-client-common" "freeipa-client-epn" "freeipa-client-samba" "grubby" "nvim" "telnet" "tftp" "zsh")
dnf install -y ${custom_packages[*]}

## Enable SWAP, disable zram, enable hibernation
## https://docs.bazzite.gg/Advanced/swapfile/
SWAP_SUBVOL="/var/swap"
SWAP_FILE="$SWAP_SUBVOL/swap"
SWAP_SIZE_MULT="1.10625"
MEM_KB=$(grep "MemTotal:" /proc/meminfo | awk '{print $2}')
MEM_GB=$(( MEM_KB / 1000000 ))
# ${number%.*} uses parameter expansion to round a float
SWAP_SIZE=${$(( MEM_GB * SWAP_SIZE_MULT ))%.*}

btrfs subvolume create "$SWAP_SUBVOL"
semanage fcontext -a -t var_t "$SWAP_SUBVOL"
restorecon "$SWAP_SUBVOL"

btrfs filesystem mkswapfile --size "${MEM_GB}G" "$SWAP_FILE"
semanage fcontext -a -t swapfile_t "$SWAP_FILE"
restorecon "$SWAP_FILE"

cp /etc/fstab /etc/fstab.bak
echo "${$SWAP_FILE} none swap defaults,nofail 0 0" | tee -a /etc/fstab

echo "" | tee /etc/systemd/zram-generator.conf

### end custom modifications


