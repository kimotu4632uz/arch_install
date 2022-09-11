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


	local esp=$(yq '.partition.efi' < "$config")
	local root=$(yq '.partition.root' < "$config")

	local locale=$(yq '.system.locale' < "$config")
	local keymap=$(yq '.system.keymap' < "$config")
	local timezone=$(yq '.system.timezone' < "$config")

	local hostname=$(yq '.network.hostname' < "$config")
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
  mkdir /mnt/boot
	echo "mount $esp to /mnt/boot..."
  mount "$esp" /mnt/boot


  # update mirror
	echo "update mirror..."
	echo ""
  reflector --country 'Japan' --age 24 --protocol https --sort rate --save /etc/pacman.d/mirrorlist


  # check cpu
  local ucode=$(cpu_test)

	local iwd=""
	if [[ "$nettype" == "wireless" ]]; then
		iwd="iwd"
	fi

  # install package
	echo "install packages to /mnt..."
	echo ""
  pacstrap /mnt base base-devel git linux linux-firmware "$ucode" "$iwd" vim

  
  # generate fstab
	echo "write fstab to /mnt/etc/fstab..."
  genfstab -U /mnt >> /mnt/etc/fstab


	# link resolv.conf for systemd-resolved
	ln -sf /run/systemd/resolve/stub-resolv.conf /mnt/etc/resolv.conf


  # enter chroot
	echo "enter chroot..."
  arch-chroot /mnt


  # install bootloader
	echo "install bootloader to /boot..."
  bootctl --path=/boot install


  # write boot entry
	echo "write boot config..."
  local partuuid=$(blkid -s PARTUUID -o value "$root")
  local entry="/boot/loader/entries/arch.conf"

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
  local loader_conf="/boot/loader/loader.conf"

  cat << EOS > "$loader_conf"
default arch
timeout 3
EOS


  # generate locale
	echo "generate locale..."
  echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
	if [[ ! -z "$locale" ]] && [[ "$locale" != "null" ]]; then
		echo "$locale UTF-8" >> /etc/locale.gen
	fi

	locale-gen


	# set locale
	echo "set locale to en_US.UTF-8..."
	localectl set-locale en_US.UTF-8

	echo "set keymap to $keymap..."
	localectl set-keymap "$keymap"


	# set hostname
	echo "set hostname to $hostname..."
	hostnamectl set-hostname "$hostname"


	# DNS settings
	echo "DNS settings..."
  systemctl enable systemd-resolved
  systemctl start systemd-resolved


	# network settings
	echo "network settings..."
	cat << EOS > /etc/systemd/network/20-wired.network
[Match]
Name=e*

[Network]
DHCP=yes
EOS

	cat << EOS > /etc/systemd/network/25-wireless.network
[Match]
Name=wl*

[Network]
DHCP=yes
EOS

  systemctl enable systemd-networkd
  systemctl start systemd-networkd

	if [[ "$nettype" == "wireless" ]]; then
	  systemctl enable iwd
	  systemctl start iwd
	fi


	# set timezone
	echo "set timezone to $timezone..."
	timedatectl set-timezone "$timezone"
	timedatectl set-ntp true
	

	# add normal user
	echo "add user $uname..."
  useradd -m -G wheel "$uname"


	# update sudoers
	sed -e '/%wheel ALL=(ALL:ALL) ALL/s/^# //' /etc/sudoers | EDITOR=tee visudo >/dev/null

	# passwd
	echo "enter password for root"
  passwd
	echo "enter password for $uname"
	passwd "$uname"


	reboot
}

main "$@"

