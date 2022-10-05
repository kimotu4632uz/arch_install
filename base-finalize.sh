#!/bin/bash -e

print_help() {
  echo "Usage: ${0##*/} [OPTIONS]"
  echo "please run this script by user."
  echo ""
  echo "OPTIONS:"
  echo "  -c <CONFIG> use CONFIG as config file"
}

main() {
  # check runned by root
  if [[ $(id -u) == "0" ]]; then
    echo "Error: please do notrun script by sudo."
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
  sudo sh -c 'echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen'
  if [[ ! -z "$locale" ]] && [[ "$locale" != "null" ]]; then
    sudo sh -c "echo $locale UTF-8 >> /etc/locale.gen"
  fi

  sudo locale-gen


  # set locale
  echo "set locale to en_US.UTF-8..."
  sudo localectl set-locale en_US.UTF-8


  echo "set keymap to $keymap..."
  sudo localectl set-keymap "$keymap"


  # set hostname
  echo "set hostname to $hostname..."
  sudo hostnamectl set-hostname "$hostname"


  # DNS settings
  echo "DNS settings..."
  sudo systemctl enable systemd-resolved
  sudo systemctl start systemd-resolved
  sudo ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf


  # network settings
  echo "network settings..."
  sudo cp conf/20-wired.network /etc/systemd/network/
  sudo cp conf/25-wireless.network /etc/systemd/network/

  sudo systemctl enable systemd-networkd
  sudo systemctl start systemd-networkd

  if [[ "$nettype" == "wireless" ]]; then
    sudo systemctl enable iwd
    sudo systemctl start iwd

    echo ""
    echo "please finish connecting wifi."
    echo ""
    sudo iwctl
  fi


  # set timezone
  echo "set timezone to $timezone..."
  sudo timedatectl set-timezone "$timezone"
  sudo timedatectl set-ntp true

  
  # copy pacman.conf
  sudo cp conf/pacman.conf /etc/


  # install AUR helper (yay)
  cd $HOME
  git clone https://aur.archlinux.org/yay-bin.git
  cd yay-bin
  makepkg -si
  cd $HOME
  rm -rf yay-bin


  sudo reboot
}

main "$@"

