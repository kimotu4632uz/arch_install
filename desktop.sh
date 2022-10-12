#!/bin/bash -e

PKGMGR="yay"
PKGMGR_ARG=("-S" "--noconfirm")

SCRIPT_NAME="${0##*/}"
SCRIPT_DIR="${0%/*}"

install_pkg() {
  $PKGMGR "${PKGMGR_ARG[@]}" "$@"
}

main() {
  # check not runned by root
  if [[ $(id -u) == "0" ]]; then
    echo "Error: please do not run script by root."
    exit 1
  fi


  # install github cli
  install_pkg github-cli
  gh auth login --with-token < github_token.txt


  # install depends
  install_pkg
    xorg-server \
    lightdm \
    lightdm-slick-greeter \
    numlockx \
    bluez \
    bluez-utils \
    gnome-keyring \
    fcitx5-im \
    fcitx5-mozc
 

  # lighdm greeter settings
  sudo sed -i -E 's/^#(greeter-session)=.*/\1=lightdm-slick-greeter/' /etc/lightdm/lightdm.conf
  sudo sed -i -E 's/^#(greeter-setup-script)=.*/\1=\/usr\/bin\/numlockx on/' /etc/lightdm/lightdm.conf

  # sudo sed -i -E 's/^(webkit_theme.*)=.*/\1= litarvan/' /etc/lightdm/lightdm-webkit2-greeter.conf


  # enable lightdm
  sudo systemctl enable lightdm


  # clone dotfiles
  cd $HOME
  git clone --recursive https://github.com/kimotu4632uz/dotfiles.git
  ./dotfiles/setup.sh -p base fish neovim i3 alacritty audio gtk rclone
  ./dotfiles/x11/install.sh i3


  # install rofi theme
  git clone --depth=1 https://github.com/adi1090x/rofi.git
  cd rofi
  chmod +x setup.sh
  ./setup.sh
  cd $HOME
  rm -rf rofi


  # install fonts
  install_pkg \
    noto-fonts \
    noto-fonts-cjk \
    noto-fonts-emoji \
    noto-fonts-extra \
    ttf-font-awesome

  gh release download -R "kimotu4632uz/RictyNF" -p "*.ttf"
  mkdir -p ~/.local/share/fonts
  mv RictyNF-Regular.ttf ~/.local/share/fonts/

  fc-cache -fv


  # set IME
  sudo tee -a /etc/environment << EOS > /dev/null
GTK_IM_MODULE=fcitx5
QT_IM_MODULE=fcitx5
XMODIFIERS=@im=fcitx5
EOS


  # setup smart card
  install_pkg \
    pcsc-tools \
    libusb-compat

  sudo systemctl enable pcscd


  # firewall
  install_pkg nftables
  sudo systemctl enable nftables


  # install command line tools
  install_pkg \
    man-db \
    pass \
    glances \
    neofetch \
    tty-clock-git


  # install GUI apps
  install_pkg \
    vivaldi \
    browserpass-chromium \
    thunar \
    gvfs \
    thunar-archive-plugin \
    file-roller \
    thunar-media-tags-plugin \
    thunar-volman \
    evince \
    poppler-data \
    eog \
    xdg-user-dirs-gtk \
    flatpak

  flatpak install --noninteractive cider joplin


  # Thunar settings
  xfconf-query -c thunar -p /last-location-bar -n -t string -s ThunarLocationButtons


  # finally set locale
  sudo localectl set-locale ja_JP.UTF-8


  sudo reboot
}

main "$@"

