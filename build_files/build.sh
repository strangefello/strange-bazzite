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
## Custom native packages
declare -a custom_packages
custom_packages=( \
  "alsa-tools" 
  "alsamixergui" \
  "freeipa-client" \
  "freeipa-client-common" \
  "freeipa-client-epn" \
  "freeipa-client-samba" \
  "grubby" \
  "nvim" \
  "telnet" \
  "tftp" \
  "zsh" \
  "kdeconnectd" \
  "kde-connect-nautilus" \
  )
dnf install -y ${custom_packages[*]}

## Custom non-native packages
# Proxmox Backup Client
BASE_URI="http://download.proxmox.com/debian/pbs-client/dists"
DIST="trixie"
BRANCH="main"
ARCH="binary-amd64"
FILE="proxmox-backup-client-static_"
VERSION="4.2.8-1"
SUFFIX="_amd64.deb"
FILE_NAME="${FILE}${VERSION}${SUFFIX}"
URI="${BASE_URI}/${DIST}/${BRANCH}/${ARCH}/${FILE_NAME}"
TEST_MODE="FALSE"

curl -LkO "$URI"

ar x "${FILE_NAME}"
mkdir -p extracted && tar -xf data.tar.* -C extracted/


if [ "$TEST_MODE" == "TRUE" ]; then
  extracted/usr/bin/proxmox-backup-client version
else
  install -m 0755 extracted/usr/bin/proxmox-backup-client /usr/bin
  install -m 0755 extracted/usr/bin/pxar /usr/bin
  proxmox-backup-client version
  pxar help
fi

### end custom modifications


