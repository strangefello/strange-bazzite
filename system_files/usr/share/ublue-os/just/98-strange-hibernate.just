# vim: set ft=make

[group("system")]
swap ACTION="":
  #!/usr/bin/env bash
  source /usr/lib/ujust/ujust.sh
  OPTION="{{ ACTION }}

  SWAP_SUBVOL="/var/swap"
  SWAP_FILE="$SWAP_SUBVOL/swap"
  SWAP_SIZE_MULT="1.10625"
  MEM_KB=$(grep "MemTotal:" /proc/meminfo | awk '{print $2}')
  MEM_GB=$(( MEM_KB / 1000000 ))
  # ${number%.*} uses parameter expansion to round a float
  SWAP_SIZE=${$(( MEM_GB * SWAP_SIZE_MULT ))%.*}
  FSTAB_STRING="${SWAP_FILE} none swap defaults,nofail 0 0"


  enable_swap() {
  ## Enable SWAP, disable zram, enable hibernation
  ## https://docs.bazzite.gg/Advanced/swapfile/
  
  btrfs subvolume create "$SWAP_SUBVOL"
  semanage fcontext -a -t var_t "$SWAP_SUBVOL"
  restorecon "$SWAP_SUBVOL"

  btrfs filesystem mkswapfile --size "${MEM_GB}G" "$SWAP_FILE"
  semanage fcontext -a -t swapfile_t "$SWAP_FILE"
  restorecon "$SWAP_FILE"

  cp /etc/fstab /etc/fstab.bak-before_enable_swap
  echo "${FSTAB_STRING}" | tee -a /etc/fstab

  echo "" | tee /etc/systemd/zram-generator.conf

  printf "You must now restart your computer\n"
  }

  disable_swap() {
    cp /etc/fstab /etc/fstab.bak-before-disable_swap
    sed 's/$FSTAB_STRING//' /etc/fstab
    sudo cp /usr/etc/systemd/zram-generator.conf /etc/systemd/zram-generator.conf
    printf "You should restart your computer.  Once that works, run \"ujust swap delete\" to clean up the swapfile\n"
  }

  delete() {
    if [ $(grep "${FSTAB_STRING}" /etc/fstab) ]; then
      printf "SWAP is still enabled in fstab, cannot continue.  Disable swap/swap first\n"
      exit 1
    fi
    btrfs subvolume delete "$SWAP_SUBVOL" 
  }

  usage() {
    printf "Usage: ujust swap <action>\nenable\tEnable SWAP\ndisable\tDisable SWAP \(swapfile remains\)\ndelete\tDeletes swapfile\nhelp\tShow this message\n"
  }

  case "$OPTION" in
    enable|Enable)
      enable_swap
      ;;
    disable|Disable)
      disable_swap
      ;;
    delete|Delete)
      delete_swapfile
      ;;
    help)
      usage
      ;;
    *)
      printf "Empty or invalid <action>: %s\n" "$OPTION"
      usage
      ;;
  esac
