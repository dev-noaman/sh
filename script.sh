#!/bin/bash

# Ensure the script is executed as root
if [ "$(id -u)" -ne 0 ]; then
    echo "this script must be run as root."
    echo "switching to root user..."
    sudo bash "$0" "$@"
    exit 0
fi

echo "starting fully automated minimal ubuntu server setup..."

# Step 1: Configure Google DNS for Live USB
echo "configuring google dns on live usb..."
echo "nameserver 8.8.8.8" > /etc/resolv.conf
echo "nameserver 8.8.4.4" >> /etc/resolv.conf
echo "dns configuration set to google's public dns servers."

# Step 2: Check and Install Missing Dependencies
echo "checking and installing missing dependencies..."
apt update -y
apt install -y debootstrap parted grub-efi-amd64 openssh-server || {
    echo "failed to install necessary dependencies. check your network or package manager."
    exit 1
}
echo "all required dependencies are installed."

# Step 3: Enable SSH on the Live USB
echo "enabling ssh on live usb..."
systemctl start ssh
systemctl enable ssh
sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
systemctl restart ssh
echo "root:new@2024" | chpasswd
adduser --gecos "" --disabled-password adel
echo "adel:new@2024" | chpasswd
usermod -aG sudo adel
echo "ssh enabled with root and user credentials."

# Fetch and display the Live USB's IP address
IP_ADDRESS=$(hostname -I | awk '{print $1}')
echo "you can ssh into this live usb using its ip address:"
echo "  - root: new@2024"
echo "  - user: adel / new@2024"
echo "  - ip address: ${IP_ADDRESS}"

# Step 4: Detect Target Disk
DISK=$(lsblk -dno NAME,TYPE | grep disk | awk '{print "/dev/"$1}' | head -n 1)

if [ -z "$DISK" ]; then
    echo "no valid disk found. please ensure a disk is connected."
    exit 1
fi

echo "detected target disk: $DISK"

BOOT_PART="${DISK}1"
ROOT_PART="${DISK}2"

# Unmount any existing partitions
umount ${BOOT_PART} 2>/dev/null
umount ${ROOT_PART} 2>/dev/null

# Step 5: Partition the Disk
echo "partitioning the disk..."
parted -s "${DISK}" mklabel gpt
parted -s "${DISK}" mkpart primary fat32 1MiB 512MiB
parted -s "${DISK}" set 1 boot on
parted -s "${DISK}" mkpart primary ext4 512MiB 100%

# Format the Partitions
echo "formatting partitions..."
mkfs.vfat -F 32 "${BOOT_PART}"
mkfs.ext4 "${ROOT_PART}"

# Mount the Partitions
echo "mounting partitions..."
mount "${ROOT_PART}" /mnt
mkdir -p /mnt/boot/efi
mount "${BOOT_PART}" /mnt/boot/efi

# Step 6: Install Minimal Ubuntu Server System
echo "installing minimal ubuntu server system..."
debootstrap --arch=amd64 lunar /mnt http://archive.ubuntu.com/ubuntu/

# Configure the System
echo "configuring system..."
echo "ubuntu-server" > /mnt/etc/hostname
echo "127.0.0.1 localhost" > /mnt/etc/hosts
mount -t proc none /mnt/proc
mount -t sysfs none /mnt/sys
mount --bind /dev /mnt/dev

# Step 7: Install Essential Packages
echo "installing essential packages..."
chroot /mnt apt update -y
chroot /mnt apt install -y openssh-server grub-efi-amd64
chroot /mnt systemctl enable ssh
chroot /mnt sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
chroot /mnt systemctl restart ssh
echo "root:new@2024" | chroot /mnt chpasswd
chroot /mnt adduser --gecos "" --disabled-password adel
echo "adel:new@2024" | chroot /mnt chpasswd
chroot /mnt usermod -aG sudo adel

# Step 8: Install GRUB Bootloader
echo "installing grub bootloader..."
chroot /mnt grub-install "${DISK}"
chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg

# Final Cleanup
echo "cleaning up..."
umount /mnt/boot/efi
umount /mnt/proc /mnt/sys /mnt/dev /mnt

# Display the IP Address of the Installed System
IP_ADDRESS_INSTALLED=$(hostname -I | awk '{print $1}')
echo "minimal ubuntu server system setup complete!"
echo "you can now boot into the installed system and ssh using the credentials:"
echo "  - root: new@2024"
echo "  - user: adel / new@2024"
echo "  - ip address: ${IP_ADDRESS_INSTALLED}"
