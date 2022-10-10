#!/bin/bash -e

MOK_PREFIX=/root/.mok

config="config.yaml"

esp_dev=$(yq '.partition.efi.dev' < "$config")
esp_part=$(yq '.partition.efi.part' < "$config")

# check runned by root
if [[ $(id -u) == "0" ]]; then
  echo "Error: please do not run script by root."
  exit 1
fi


# install depends
sudo pacman -S --noconfirm sbsigntools mokutil
yay -S --noconfirm shim-signed

cd $HOME
git clone https://github.com/kimotu4632uz/secure-boot-kit.git
cd secure-boot-kit
makepkg -si --noconfirm
cd $HOME
rm -rf secure-boot-kit


# copy systemd-bootx64 as grubx64.efi
sudo cp /boot/EFI/systemd/{systemd-bootx64.efi,grubx64.efi}


# copy shim binary
sudo cp /usr/share/shim-signed/shimx64.efi /boot/EFI/systemd/
sudo cp /usr/share/shim-signed/mmx64.efi /boot/EFI/systemd/


# generate MOK
sudo mkdir -p "$MOK_PREFIX"
sudo openssl req -newkey rsa:4096 -nodes -keyout "$MOK_PREFIX/MOK.key" -new -x509 -sha256 -days 3650 -subj "/CN=Machine Owner Key/" -out "$MOK_PREFIX/MOK.crt"
sudo openssl x509 -outform DER -in "$MOK_PREFIX/MOK.crt" -out "$MOK_PREFIX/MOK.cer"


# sign kernel and boot loader
sudo sbsign --key "$MOK_PREFIX/MOK.key" --cert "$MOK_PREFIX/MOK.crt" --output /boot/vmlinuz-linux /boot/vmlinuz-linux
sudo sbsign --key "$MOK_PREFIX/MOK.key" --cert "$MOK_PREFIX/MOK.crt" --output /boot/EFI/systemd/grubx64.efi /boot/EFI/systemd/grubx64.efi


# add boot entry
sudo efibootmgr --disk $esp_dev --part $esp_part --create --label "Shim Boot Manager" --loader /EFI/systemd/shimx64.efi


# enroll MOK public key
sudo mokutil --import "$MOK_PREFIX/MOK.cer"


sudo reboot

