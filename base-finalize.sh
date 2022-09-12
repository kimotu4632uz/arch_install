#!/bin/bash -e

print_help() {
  echo "Usage: ${0##*/} [OPTIONS]"
  echo "please run this script by sudo."
  echo ""
  echo "OPTIONS:"
  echo "  -c <CONFIG> use CONFIG as config file"
}

main() {
  # check runned by root
  if [[ $(id -u) != "0" ]]; then
    echo "Error: please run script by sudo."
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


  local locale=$(yq '.system.locale' < "$config")
  local keymap=$(yq '.system.keymap' < "$config")
  local timezone=$(yq '.system.timezone' < "$config")

  local hostname=$(yq '.network.hostname' < "$config")
  local nettype=$(yq '.network.type' < "$config")

  local uname=$(yq '.username' < "$config")


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
  ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf


  # network settings
  echo "network settings..."
  cp conf/20-wired.network /etc/systemd/network/
  cp conf/25-wireless.network /etc/systemd/network/

  systemctl enable systemd-networkd
  systemctl start systemd-networkd

  if [[ "$nettype" == "wireless" ]]; then
    systemctl enable iwd
    systemctl start iwd

    echo ""
    echo "please finish connecting wifi."
    echo ""
    iwctl
  fi


  # set timezone
  echo "set timezone to $timezone..."
  timedatectl set-timezone "$timezone"
  timedatectl set-ntp true

  
  # copy pacman.conf
  cp conf/pacman.conf /etc/


  # install AUR helper (yay)
  cd /home/"$uname"
  su "$uname" -c 'git clone https://aur.archlinux.org/yay-bin.git'
  cd yay-bin
  su "$uname" -c makepkg
  yes | pacman -U yay-bin-*.zst
  cd $HOME
  rm -rf /home/"$uname"/yay-bin


  reboot
}

main "$@"

