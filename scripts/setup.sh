#!/bin/bash

# From the Installation guide here: https://wiki.archlinux.org/title/Installation_guide

# Setup system clock
echo "Setting up system clock"
timedatectl set-ntp true

# partition the Harddrive (/dev/sda)
echo ""
echo "Setting up harddrive partitions. Enter \"Ignore\" and/or confirm overwriting partions"
parted /dev/sda mklabel gpt mkpart "EFI system partition" fat32 1MiB set 1 esp on mkpart "base filesystem partition" ext4 261MiB 100%

# Format EFI partition
mkfs.fat -F32 /dev/sda1

# Format main EXT4 partition
mkfs.ext4 /dev/sda2

# Mount main system partition
echo ""
echo "Mounting root partition"
mount /dev/sda2 /mnt

# Create efi mount path
echo "Creating EFI mount point"
mkdir /mnt/efi

# Mount efi partition
echo "Mounting EFI partition"
mount /dev/sda1 /mnt/efi

# Setup Pacman mirrors
echo "Setting up pacman mirrorlist"
cat << EOF > /etc/pacman.d/mirrorlist
#Server = http://mirror.rackspace.com/archlinux/\$repo/os/\$arch
Server = http://mirror.us.leaseweb.net/archlinux/\$repo/os/\$arch
Server = http://arlm.tyzoid.com/\$repo/os/\$arch
#Server = http://mirrors.lug.mtu.edu/archlinux/\$repo/os/\$arch
Server = http://mirror.math.princeton.edu/pub/archlinux/\$repo/os/\$arch
Server = http://mirror.dal10.us.leaseweb.net/archlinux/\$repo/os/\$arch
Server = http://mirror.rackspace.com/archlinux/\$repo/os/\$arch
Server = http://mirrors.advancedhosters.com/archlinux/\$repo/os/\$arch
Server = http://mirrors.acm.wpi.edu/archlinux/\$repo/os/\$arch
EOF

# Install base system to new drives
echo "Installing base system"
pacstrap /mnt base base-devel linux linux-firmware lxde git openssh firefox ttf-dejavu curl intel-ucode clinfo vi vim
echo "Base installation complete."

# Setup /etc/fstab
echo ""
echo "Genertaing fstab file"
genfstab -U /mnt > /mnt/etc/fstab

# Setup locale
echo "Generating Locale"
echo "LANG=en_US.UTF-8" > /mnt/etc/locale.conf
echo "en_US.UTF-8 UTF-8" > /mnt/etc/locale.gen

# Setup Hostname
echo "Setting hostname"
echo "allset" > /mnt/etc/hostname

# Setup /etc/hosts
echo "Setting up hosts file"
cat << EOF > /mnt/etc/hosts
127.0.0.1	localhost allset
::1		localhost allset
EOF

# Setup timezone
echo "Setting timezone"
arch-chroot /mnt ln -sf /usr/share/zoneinfo/America/Chicago /etc/localtime

# Adjust system clock
echo "Adjusting system clock"
arch-chroot /mnt hwclock --systohc

# Generate locale
echo "Generating locale"
arch-chroot /mnt locale-gen

# Update root password
echo "Update ROOT password. Enter new password, then confirm"
arch-chroot /mnt passwd

# Create allset user
echo "Creating \"allset\" user. When prompted, enter desired password, then confirm"
arch-chroot /mnt useradd -g users -G wheel -s /bin/bash -m allset
arch-chroot /mnt passwd allset

# Make custom packages directory
echo "Cretaing custom_packages directory"
arch-chroot /mnt su --login allset mkdir /home/allset/custom_packages

# Clone AMD drivers
echo "Cloning OpenCL AMD GPU drievrs"
arch-chroot /mnt su --login allset git clone https://aur.archlinux.org/opencl-amd.git /home/allset/custom_packages/opencl-amd
echo "Building drivers"
arch-chroot /mnt cd /home/allset/custom_packages/opencl-amd && su --login allset git reset --hard 88cc39d2619dddf7c62fc4e4eb3726ab04cb8f92&& su --login allset makepkg -sicCf --noconfirm

# Clone ethminer from AUR
echo "Cloning Ethminer"
arch-chroot /mnt su --login allset git clone https://aur.archlinux.org/ethminer.git /home/allset/custom_packages/ethminer
echo "Building Ethminer"
arch-chroot /mnt cd /home/allset/custom_packages/ethminer && su --login allset makepkg -sicCf --noconfirm
