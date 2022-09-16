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
  lightdm lightdm-webkit2-greeter lightdm-webkit-theme-litarvan \
  bluez bluez-utils \
  gnome-keyring fcitx5-im fcitx5-mozc



# lighdm greeter settings
sudo sed -i -e 's/^#greeter-session=.*/greeter-session=lightdm-webkit2-greeter/' /etc/lightdm/lightdm.conf
sudo sed -i -E 's/^(webkit_theme.*)=.*/\1= litarvan/' /etc/lightdm/lightdm-webkit2-greeter.conf


# enable lightdm
sudo systemctl enable lightdm


# clone dotfiles
cd $HOME
git clone https://github.com/kimotu4632uz/dotfiles.git
./dotfiles/setup.sh -p base fish neovim i3 alacritty audio gtk rclone
./dotfiles/x11/install.sh i3


# set IME
sudo cat << EOS >> /etc/environment
GTK_IM_MODULE=fcitx5
QT_IM_MODULE=fcitx5
XMODIFIERS=@im=fcitx5
EOS

# enable services
systemctl --user enable mpd
systemctl --user enable mpDris2


# load keymap
xmodmap ~/.Xmodmap


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


# install command line tools
sudo pacman -S --noconfirm pass glances tty-clock neofetch


# setup smart card
sudo pacman -S --noconfirm pcsc-tools libusb-compat
sudo systemctl enable pcscd


# install GUI apps
sudo pacman -S --noconfirm vivaldi browserpass-chromium thunar evince poppler-data eog xdg-user-dirs-gtk flatpak
flatpak install --noninteractive cider joplin


# Thunar settings
xfconf-query -c thunar -p /last-locaion-bar -n -t string -s ThunarLocationButtons


# finally set locale
localectl set-locale ja_JP.UTF-8


reboot

