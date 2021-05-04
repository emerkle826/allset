#!/bin/bash

# From the Installation guide here: https://wiki.archlinux.org/title/Installation_guide

# Setup system clock
echo "Setting up system clock"
timedatectl set-ntp true

# partition the Harddrive (/dev/sda)
echo ""
echo "Setting up harddrive partitions. Enter \"Ignore\" and/or confirm overwriting partions"
parted -s /dev/sda mklabel gpt
parted -s /dev/sda mkpart "EFI" fat32 1MiB 512MiB
parted -s /dev/sda set 1 esp on
parted -s /dev/sda mkpart "system" ext4 513MiB 100%

# Format EFI partition
mkfs.fat -F32 /dev/sda1

# Format main EXT4 partition
mkfs.ext4 -F /dev/sda2

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
pacstrap /mnt base base-devel linux linux-firmware lxde git openssh firefox ttf-dejavu curl intel-ucode clinfo vi vim grub efibootmgr bash-completion wget
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

# Setup allset user in sudoers file
arch-chroot /mnt sh -c 'echo "%wheel ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers'

# Make custom packages directory
echo "Cretaing custom_packages directory"
arch-chroot -u allset /mnt mkdir /home/allset/custom_packages

# Setup makepkg config
cat << EOF > /mnt/home/allset/.makepkg.conf
MAKEFLAGS="-j$(nproc)"
INTEGRITY_CHECK=(md5 sha1 sha256)
COMPRESSXZ=(xz -c -z - --threads=0)
COMPRESSZST=(zstd -c -z -q - --threads=0)
EOF

arch-chroot /mnt chown allset:user /home/allset/.makepkg.conf

# Clone AMD drivers
echo "Cloning OpenCL AMD GPU drievrs"
arch-chroot -u allset /mnt git clone https://github.com/emerkle826/opencl-amd.git /home/allset/custom_packages/opencl-amd
echo "Building drivers"
arch-chroot -u allset /mnt sh -c 'export HOME=/home/allset && cd /home/allset/custom_packages/opencl-amd && git reset --hard 88cc39d2619dddf7c62fc4e4eb3726ab04cb8f92 && makepkg -sicCf --noconfirm'

# Download Boost libs for Ethminer
echo "Setting up Boost"
arch-chroot -u allset /mnt mkdir -p /home/allset/.hunter/_Base/Download/Boost/1.66.0/075d0b4
arch-chroot -u allset /mnt wget -O /home/allset/.hunter/_Base/Download/Boost/1.66.0/075d0b4/boost_1_66_0.7z https://boostorg.jfrog.io/artifactory/main/release/1.66.0/source/boost_1_66_0.7z

# Clone ethminer from AUR
echo "Cloning Ethminer"
arch-chroot -u allset /mnt git clone https://github.com/emerkle826/ethminer.git /home/allset/custom_packages/ethminer
echo "Building Ethminer"
arch-chroot -u allset /mnt sh -c 'export HOME=/home/allset && cd /home/allset/custom_packages/ethminer && makepkg -sicCf --noconfirm'

# Setup Networking DHCP
echo "Setting up Networking/DHCP"
mkdir -p /mnt/etc/systemd/network /mnt/etc/systemd/system/sockets.target.wants /mnt/etc/systemd/system/network-online.target.wants
cat << EOF > /mnt/etc/systemd/network/20-wired.network
[Match]
Name=*

[Network]
DHCP=yes
EOF

# enable networking services
# systemd-networkd
arch-chroot /mnt ln -s /usr/lib/systemd/system/systemd-networkd.service /etc/systemd/system/dbus-org.freedesktop.network1.service
arch-chroot /mnt ln -s /usr/lib/systemd/system/systemd-networkd.service /etc/systemd/system/multi-user.target.wants/systemd-networkd.service
arch-chroot /mnt ln -s /usr/lib/systemd/system/systemd-networkd.socket /etc/systemd/system/sockets.target.wants/systemd-networkd.socket
arch-chroot /mnt ln -s /usr/lib/systemd/system/systemd-networkd-wait-online.service /etc/systemd/system/network-online.target.wants/systemd-networkd-wait-online.service
# systemd-resolvd
arch-chroot /mnt ln -s /usr/lib/systemd/system/systemd-resolved.service /etc/systemd/system/dbus-org.freedesktop.resolve1.service
arch-chroot /mnt ln -s /usr/lib/systemd/system/systemd-resolved.service /etc/systemd/system/multi-user.target.wants/systemd-resolved.service

# Setup LXDM
echo "setting up LXDM for GPU"
arch-chroot /mnt ln -s /usr/lib/systemd/system/lxdm.service /etc/systemd/system/display-manager.service
arch-chroot /mnt sed -i 's/^# autologin.*$/autologin=allset/g' /etc/lxdm/lxdm.conf
arch-chroot /mnt sed -i 's/^# session.*$/session=\/usr\/bin\/startlxde/g' /etc/lxdm/lxdm.conf

# Setup GRUB
echo "Setting up GRUB"
arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/efi --bootloader-id=GRUB
arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg

# Setup ethminer scripts
echo "Setting up Ethminer scripts"
arch-chroot -u allset /mnt mkdir /home/allset/ethminer
arch-chroot -u allset /mnt sh -c 'export HOME=/home/allset && echo "export PATH=~/ethminer:${PATH}" >> /home/allset/.bashrc'
arch-chroot -u allset /mnt wget -O /home/allset/ethminer/miner_status https://raw.githubusercontent.com/emerkle826/allset/master/scripts/miner_status
arch-chroot -u allset /mnt wget -O /home/allset/ethminer/start_miner https://raw.githubusercontent.com/emerkle826/allset/master/scripts/start_miner
arch-chroot -u allset /mnt wget -O /home/allset/ethminer/stop_miner https://raw.githubusercontent.com/emerkle826/allset/master/scripts/stop_miner
arch-chroot /mnt wget -O /home/allset/ethminer/ethminer.service https://raw.githubusercontent.com/emerkle826/allset/master/scripts/ethminer.service
chmod 755 /mnt/home/allset/ethminer/*
arch-chroot /mnt ln -s /home/allset/ethminer/ethminer.service /etc/systemd/system/multi-user.target.wants/ethminer.service
arch-chroot /mnt ln -s /home/allset/ethminer/ethminer.service /etc/systemd/system/ethminer.service

echo "Please type in your Etherium wallet ID (default: 94F533789cf2b9b33c3bEf1d3200c8f9B2792558):"
read WALLETID
if [ "${WALLETID}" == "" ]
then
  WALLETID="94F533789cf2b9b33c3bEf1d3200c8f9B2792558"
fi
echo "Using wallet ID: ${WALLETID}"
echo ${WALLETID} > /mnt/home/allset/ethminer/walletid
arch-chroot /mnt chown allset:user /home/allset/ethminer/walletid

# Unmount disks and reboot
echo "Installation complete. Unmounting disks and restarting."
umount /dev/sda1 /dev/sda2
echo "Trying to umount USB. You can ignore any failures that follow."
umount /dev/sdb3
echo "Press enter to reboot"
read junk
reboot

