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
  "qemu-guest-agent"
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

## Selected apps from Bazzite-dx
#mishmash from bazzite-dx 20-install-apps.sh
dnf5 install -y \
    android-tools \
    bcc \
    bpftop \
    bpftrace \
    flatpak-builder \
    ccache \
    nicstat \
    numactl \
    podman-machine \
    podman-tui \
    python3-ramalama \
    qemu-kvm \
    restic \
    rclone \
    sysprof \
    tiptop \
    zsh

dnf5 install --enable-repo="copr:copr.fedorainfracloud.org:ublue-os:packages" -y \
    ublue-setup-services

#VSCode
dnf5 config-manager addrepo --set=baseurl="https://packages.microsoft.com/yumrepos/vscode" --id="vscode"
dnf5 config-manager setopt vscode.enabled=0
# FIXME: gpgcheck is broken for vscode due to it using `asc` for checking
# seems to be broken on newer rpm security policies.
dnf5 config-manager setopt vscode.gpgcheck=0
dnf5 install --nogpgcheck --enable-repo="vscode" -y code
#Docker
docker_pkgs=(
    containerd.io
    docker-buildx-plugin
    docker-ce
    docker-ce-cli
    docker-compose-plugin
)
dnf5 config-manager addrepo --from-repofile="https://download.docker.com/linux/fedora/docker-ce.repo"
dnf5 config-manager setopt docker-ce-stable.enabled=0
dnf5 install -y --enable-repo="docker-ce-stable" "${docker_pkgs[@]}" || {
    # Use test packages if docker pkgs is not available for f42
    if (($(lsb_release -sr) == 42)); then
        echo "::info::Missing docker packages in f42, falling back to test repos..."
        dnf5 install -y --enablerepo="docker-ce-test" "${docker_pkgs[@]}"
    fi
}
# From bazzite-dx 40-services.sh
#!/usr/bin/env bash
set -xeuo pipefail

systemctl enable docker.socket
systemctl enable podman.socket
systemctl enable ublue-system-setup.service
systemctl --global enable ublue-user-setup.service

# From bazzite-dx build.sh - redone to use build.sh.d
CONTEXT_PATH="$(realpath "$(dirname "$0")/..")" # should return /run/context
BUILD_SCRIPTS_PATH="$(realpath "$(dirname $0)/build.sh.d")"
MAJOR_VERSION_NUMBER="$(sh -c '. /usr/lib/os-release ; echo $VERSION_ID')"
SCRIPTS_PATH="$(realpath "$(dirname "$0")/scripts")"
export CONTEXT_PATH
export SCRIPTS_PATH
export MAJOR_VERSION_NUMBER

run_buildscripts_for() {
	WHAT=$1
	shift
	# Complex "find" expression here since there might not be any overrides
	# Allows us to numerically sort scripts by stuff like "01-packages.sh" or whatever
	# CUSTOM_NAME is required if we dont need or want the automatic name
	find "${BUILD_SCRIPTS_PATH}/$WHAT" -maxdepth 1 -iname "*-*.sh" -type f -print0 | sort --zero-terminated --sort=human-numeric | while IFS= read -r -d $'\0' script ; do
		if [ "${CUSTOM_NAME}" != "" ] ; then
			WHAT=$CUSTOM_NAME
		fi
		printf "::group:: ===$WHAT-%s===\n" "$(basename "$script")"
		"$(realpath $script)"
		printf "::endgroup::\n"
	done
}

copy_systemfiles_for() {
	WHAT=$1
	shift
	DISPLAY_NAME=$WHAT
	if [ "${CUSTOM_NAME}" != "" ] ; then
		DISPLAY_NAME=$CUSTOM_NAME
	fi
	printf "::group:: ===%s-file-copying===\n" "${DISPLAY_NAME}"
	cp -avf "${CONTEXT_PATH}/$WHAT/." /
	printf "::endgroup::\n"
}

CUSTOM_NAME="base"
copy_systemfiles_for files
run_buildscripts_for .
CUSTOM_NAME=

### end custom modifications


