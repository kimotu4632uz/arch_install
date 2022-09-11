#!/bin/bash -e

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

    echo ""
    echo "please finish connecting wifi."
    echo ""
    iwctl
  fi


  # set timezone
  echo "set timezone to $timezone..."
  timedatectl set-timezone "$timezone"
  timedatectl set-ntp true


  # install AUR helper (yay)
  su "$uname"
  cd $HOME
  git clone https://aur.archlinux.org/yay-bin.git
  cd yay-bin
  makepkg -si
  cd $HOME
  rm -rf yay-bin


  reboot
}

main "$@"

