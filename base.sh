#!/bin/bash -e

cpu_test() {
  proc=$(cat /proc/cpuinfo | grep -m1 vendor_id | cut -f 2 -d ' ')

  if [[ "$proc" == "GenuineIntel" ]]; then
    echo "intel-ucode"
  elif [[ "$proc" == "AuthenticAMD" ]]; then
    echo "amd-ucode"
  fi
}

print_help() {
  echo "Usage: ${0##*/} [OPTIONS]"
  echo ""
  echo "OPTIONS:"
  echo "  -c <CONFIG> use CONFIG as config file"
}

main() {
  # check runned by root
  if [[ $(id -u) != "0" ]]; then
    echo "Error: please run script by root."
    exit 1
  fi


  # check depends
  if ! pacman -Q go-yq &> /dev/null; then
    echo "Error: go-yq is not installed"
    exit 1
  fi


  # parse arg
  local config="config.yaml"

  while getopts c:h OPT; do
    case $OPT in
      c)
        config="${OPTARG}"
        ;;
      h)
        print_help
        exit 0
        ;;
      \?)
        exit 1
        ;;
    esac
  done


  local esp=$(yq '.partition.efi.full' < "$config")
  local root=$(yq '.partition.root' < "$config")

  local nettype=$(yq '.network.type' < "$config")

  local uname=$(yq '.username' < "$config")


  # check /mnt is used
  if mount | grep /mnt &> /dev/null; then
    echo "Error: /mnt is used. please unmount /mnt."
    exit 1
  fi

  # mount partition
  echo "mount $root to /mnt..."
  mount "$root" /mnt
  mkdir -p /mnt/boot
  echo "mount $esp to /mnt/boot..."
  mount "$esp" /mnt/boot


  # update mirror
  echo "update mirror..."
  echo ""
  reflector --country 'Japan' --age 24 --protocol https --sort rate --save /etc/pacman.d/mirrorlist


  # install packages
  local pkgs=("base" "base-devel" "git" "linux" "linux-firmware" "vim" "go-yq")
  local ucode=$(cpu_test)

  if [[ ! -z "$ucode" ]]; then
    pkgs+=("$ucode")
  fi

  if [[ "$nettype" == "wireless" ]]; then
    pkgs+=("iwd")
  fi

  # install package
  echo "install packages to /mnt..."
  echo ""
  pacstrap /mnt "${pkgs[@]}"

  
  # generate fstab
  echo "write fstab to /mnt/etc/fstab..."
  genfstab -U /mnt >> /mnt/etc/fstab


  # enter chroot
  local exectg="arch-chroot /mnt"


  # install bootloader
  echo "install bootloader to /boot..."
  $exectg bootctl --path=/boot install


  # write boot entry
  echo "write boot config..."
  local partuuid=$(blkid -s PARTUUID -o value "$root")
  local entry="/mnt/boot/loader/entries/arch.conf"

  mkdir -p "${entry%/*}"

  cat << EOS > "$entry"
title   Arch Linux
linux   /vmlinuz-linux
EOS

  if [[ ! -z "$ucode" ]]; then
    echo "initrd  /$ucode.img" >> "$entry"
  fi

  cat << EOS >> "$entry"
initrd  /initramfs-linux.img
options root=PARTUUID=$partuuid rw
EOS


  # write loader conf
  local loader_conf="/mnt/boot/loader/loader.conf"

  cat << EOS > "$loader_conf"
default arch
timeout 3
EOS


  # add normal user
  echo "add user $uname..."
  $exectg useradd -m -G wheel "$uname"


  # update sudoers
  $exectg sh -c "sed -e '/%wheel ALL=(ALL:ALL) ALL/s/^# //' /etc/sudoers | EDITOR=tee visudo >/dev/null"


  # passwd
  echo "enter password for root"
  $exectg passwd
  echo "enter password for $uname"
  $exectg passwd "$uname"


  # copy files to /root
  cp -r ../arch_install /mnt/home/"$uname"/
  $exectg chown -R "$uname":"$uname" /home/"$uname"/arch_install

  reboot
}

main "$@"

