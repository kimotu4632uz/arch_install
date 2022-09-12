#!/bin/bash -e

# check not runned by root
if [[ $(id -u) == "0" ]]; then
  echo "Error: please do not run script by root."
  exit 1
fi


# install github cli
sudo pacman -S --noconfirm github-cli
gh auth login --with-token < github_token.txt


# install depends
sudo pacman -S --noconfirm \
  xorg-server xorg-xmodmap \
  lightdm lightdm-webkit2-greeter \
  i3-gaps polybar rofi xss-lock feh \
  maim xclip \
  playerctl bluez bluez-utils pipewire{,-pulse,-alsa} wireplumber \
  gnome-keyring fcitx5-im fcitx5-mozc

yay -S --noconfirm i3lock-color


# lighdm greeter settings
sudo sed -i -e 's/^#greeter-session=.*/greeter-session=lightdm-webkit2-greeter/' /etc/lightdm/lightdm.conf


# enable lightdm
sudo systemctl enable lightdm


# clone dotfiles
cd $HOME
git clone https://github.com/kimotu4632uz/dotfiles.git
cd dotfiles
./setup.sh base fish neovim i3 alacritty audio
cd x11
./install.sh i3
cd $HOME


# install rofi theme
git clone --depth=1 https://github.com/adi1090x/rofi.git
cd rofi
chmod +x setup.sh
./setup.sh
cd $HOME
rm -rf rofi


# install fonts
sudo pacman -S --noconfirm noto-fonts{,-cjk,-emoji,-extra} ttf-font-awesome
gh release download -R "kimotu4632uz/RictyNF" -p "*.ttf"
mkdir .fonts
mv RictyNF-Regular.ttf .fonts/
fc-cache -fv


# install icons
yay -S --noconfirm tela-circle-icon-theme-git


# install command line tools
sudo pacman -S --noconfirm fish starship fd bat fzf neovim


# setup smart card
sudo pacman -S --noconfirm pcsc-tools libusb-compat
sudo systemctl enable pcscd


# install GUI apps
sudo pacman -S --noconfirm vivaldi browserpass-chromium alacritty thunar evince poppler-data xdg-user-dirs-gtk flatpak
flatpak install --noninteractive cider joplin


reboot

