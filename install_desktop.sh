#!/bin/bash -e

# check not runned by root
if [[ $(id -u) == "0" ]]; then
  echo "Error: please do not run script by root."
  exit 1
fi


# install AUR helper (yay)
git clone https://aur.archlinux.org/yay-bin.git
cd yay-bin
makepkg -si
cd $HOME


# install github cli
yes | sudo pacman -S github-cli
gh auth login -p ssh --with-token < github_token.txt


# install depends
yes | sudo pacman -S xorg-server lightdm lightdm-webkit2-greeter i3-gaps polybar rofi xss-lock feh
yes | yay -S i3lock-color


# lighdm greeter settings
sudo sed -i -e 's/^#greeter-session=.*/greeter-session=lightdm-webkit2-greeter/' /etc/lightdm/lightdm.conf


# clone dotfiles
git clone https://github.com/kimotu4632uz/dotfiles.git
cd dotfiles
./setup.sh base fish i3 neovim alacritty
cd $HOME


# install fonts
yes | sudo pacman -S noto-fonts{,-cjk,-emoji,-extra} ttf-font-awesome
gh release download -R "kimotu4632uz/RictyNF" -p "*.ttf"
mkdir .fonts
mv RictyNF-Regular.ttf .fonts/
fc-cache -fv


# install other depends
yes | sudo pacman -S fish starship
yes | yay -S tela-circle-icon-theme-git


reboot

