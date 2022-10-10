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
  lightdm lightdm-slick-greeter numlockx \
  bluez bluez-utils \
  gnome-keyring fcitx5-im fcitx5-mozc



# lighdm greeter settings
sudo sed -i -E 's/^#(greeter-session)=.*/\1=lightdm-slick-greeter/' /etc/lightdm/lightdm.conf
sudo sed -i -E 's/^#(greeter-setup-script)=.*/\1=\/usr\/bin\/numlockx on/' /etc/lightdm/lightdm.conf

# sudo sed -i -E 's/^(webkit_theme.*)=.*/\1= litarvan/' /etc/lightdm/lightdm-webkit2-greeter.conf


# enable lightdm
sudo systemctl enable lightdm


# clone dotfiles
cd $HOME
git clone https://github.com/kimotu4632uz/dotfiles.git
./dotfiles/setup.sh -p base fish neovim i3 alacritty audio gtk rclone
./dotfiles/x11/install.sh i3


# set IME
sudo tee -a /etc/environment << EOS > /dev/null
GTK_IM_MODULE=fcitx5
QT_IM_MODULE=fcitx5
XMODIFIERS=@im=fcitx5
EOS


# enable services
systemctl --user enable mpd
systemctl --user enable mpDris2


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
mkdir -p ~/.local/share/fonts
mv RictyNF-Regular.ttf ~/.local/share/fonts/
fc-cache -fv


# install command line tools
sudo pacman -S --noconfirm pass glances neofetch
yay -S --noconfirm tty-clock-git


# setup smart card
sudo pacman -S --noconfirm pcsc-tools libusb-compat
sudo systemctl enable pcscd


# install GUI apps
sudo pacman -S --noconfirm vivaldi browserpass-chromium thunar gvfs thunar-archive-plugin file-roller thunar-media-tags-plugin thunar-volman evince poppler-data eog xdg-user-dirs-gtk flatpak
flatpak install --noninteractive cider joplin


# Thunar settings
xfconf-query -c thunar -p /last-locaion-bar -n -t string -s ThunarLocationButtons


# power manager
sudo pacman -S --noconfirm xfce4-power-manager
xfconf-query --create -c xfce4-session -p /general/LockCommand -t string -s "~/.config/i3/script/lock.sh"


# finally set locale
localectl set-locale ja_JP.UTF-8


sudo reboot

