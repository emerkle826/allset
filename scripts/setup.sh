#!/bin/bash

# From the Installation guide here: https://wiki.archlinux.org/title/Installation_guide

# Setup system clock
timedatectl set-ntp true

# partition the Harddrive (/dev/sda)
parted /dev/sda mklabel gpt mkpart "EFI system partition" fat32 1MiB set 1 esp on mkpart "base filesystem partition" ext4 261MiB 100%

# Format EFI partition
mkfs.fat -q -F32 /dev/sda1

# Format main EXT4 partition
mkfs.ext4 -q /dev/sda2

# Mount main system partition
mount /dev/sda2 /mnt

# Create efi mount path
mkdir /mnt/efi

# Mount efi partition
mount /dev/sda1 /mnt/efi

# Setup Pacman mirrors
cat << EOF > /etc/pacman.d/mirrorlist
#Server = http://mirror.rackspace.com/archlinux/$repo/os/$arch
Server = http://mirror.us.leaseweb.net/archlinux/$repo/os/$arch
Server = http://arlm.tyzoid.com/$repo/os/$arch
#Server = http://mirrors.lug.mtu.edu/archlinux/$repo/os/$arch
Server = http://mirror.math.princeton.edu/pub/archlinux/$repo/os/$arch
Server = http://mirror.dal10.us.leaseweb.net/archlinux/$repo/os/$arch
Server = http://mirror.rackspace.com/archlinux/$repo/os/$arch
Server = http://mirrors.advancedhosters.com/archlinux/$repo/os/$arch
Server = http://mirrors.acm.wpi.edu/archlinux/$repo/os/$arch
EOF

# Install base system to new drives
pacstrap /mnt base base-devel linux linux-firmware lxde git openssh firefox ttf-dejavu curl intel-ucode clinfo vi vim

# Setup /etc/fstab
genfstab -U /mnt > /mnt/etc/fstab

# Setup locale
echo "LANG=en_US.UTF-8" > /mnt/etc/locale.conf
echo "en_US.UTF-8 UTF-8" > /mnt/etc/locale.gen

# Setup Hostname
echo "allset" > /mnt/etc/hostname

# Setup /etc/hosts
cat << EOF > /mnt/etc/hosts
127.0.0.1	localhost allset
::1		localhost allset
EOF

# Chroot into new system
arch-chroot /mnt

# Setup timezone
ln -sf /usr/share/zoneinfo/Region/City /etc/localtime

# Adjust system clock
hwclock --systohc

# Generate locale
locale-gen

# Update root password
passwd

# Create allset user
useradd -g users -G wheel -s /bin/bash -m allset
passwd allset

# Make custom packages directory
su --login allset mkdir /home/allset/custom_packages

# Clone AMD drivers
su --login allset git clone https://aur.archlinux.org/opencl-amd.git /home/allset/custom_packages/opencl-amd
pushd /home/allset/custom_packages/opencl-amd
# Use 20.40 specific version for now
su --login allset git reset --hard 88cc39d2619dddf7c62fc4e4eb3726ab04cb8f92
# build and install drivers
su --login allset makepkg -sicCf --noconfirm
popd

# Clone ethminer from AUR
su --login allset git clone https://aur.archlinux.org/ethminer.git /home/allset/custom_packages/ethminer
pushd /home/allset/custom_packages/ethminer
# build and install Ethminer
su --login allset makepkg -sicCf --noconfirm
popd
