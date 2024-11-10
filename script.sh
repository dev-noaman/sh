#!/bin/bash

# Ensure the script is executed as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root."
    echo "Switching to root user..."
    sudo bash "$0" "$@"
    exit 0
fi

echo "Starting fully automated minimal Ubuntu Server 24.04 setup..."

# Configure Google DNS
echo "Configuring Google DNS on Live USB..."
echo "nameserver 8.8.8.8" > /etc/resolv.conf
echo "nameserver 8.8.4.4" >> /etc/resolv.conf
echo "DNS configuration set."

# Install dependencies
echo "Checking and installing missing dependencies..."
apt update -y
apt install -y debootstrap parted grub-efi-amd64 openssh-server || {
    echo "Failed to install dependencies. Exiting."
    exit 1
}

# Enable SSH
echo "Enabling SSH on Live USB..."
systemctl start ssh
systemctl enable ssh
sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
systemctl restart ssh
echo "root:new@2024" | chpasswd
if ! id -u adel >/dev/null 2>&1; then
    adduser --gecos "" --disabled-password adel
    echo "adel:new@2024" | chpasswd
    usermod -aG sudo adel
fi

# Detect target disk
DISK=$(lsblk -dno NAME,TYPE | grep disk | awk '{print "/dev/"$1}' | head -n 1)
if [ -z "$DISK" ]; then
    echo "No valid disk found. Exiting."
    exit 1
fi
echo "Detected target disk: $DISK"

# Unmount and clean the disk
echo "Unmounting and cleaning the disk..."
for partition in $(lsblk -no NAME "${DISK}" | tail -n +2); do
    umount -f "/dev/${partition}" 2>/dev/null || true
done

# Partition the disk
echo "Partitioning the disk..."
parted -s "$DISK" mklabel gpt
parted -s "$DISK" mkpart primary fat32 1MiB 512MiB
parted -s "$DISK" set 1 boot on
parted -s "$DISK" mkpart primary ext4 512MiB 100%

# Format partitions
BOOT_PART="${DISK}1"
ROOT_PART="${DISK}2"
echo "Formatting partitions..."
umount -f "${BOOT_PART}" 2>/dev/null || true
mkfs.vfat -F 32 "${BOOT_PART}"
mkfs.ext4 "${ROOT_PART}"

# Mount partitions
echo "Mounting partitions..."
mount "${ROOT_PART}" /mnt
mkdir -p /mnt/boot/efi
mount "${BOOT_PART}" /mnt/boot/efi

# Clean target directory before bootstrapping
rm -rf /mnt/*

# Bootstrap Ubuntu
echo "Installing minimal Ubuntu Server system..."
debootstrap --arch=amd64 lunar /mnt http://archive.ubuntu.com/ubuntu/

# Configure the system
echo "Configuring system..."
echo "ubuntu-server" > /mnt/etc/hostname
echo "127.0.0.1 localhost" > /mnt/etc/hosts
mount -t proc none /mnt/proc
mount -t sysfs none /mnt/sys
mount --bind /dev /mnt/dev

# Install essential packages
chroot /mnt apt update -y
chroot /mnt apt install -y openssh-server grub-efi-amd64
chroot /mnt systemctl enable ssh
chroot /mnt sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
echo "root:new@2024" | chroot /mnt chpasswd
if ! chroot /mnt id -u adel >/dev/null 2>&1; then
    chroot /mnt adduser --gecos "" --disabled-password adel
    echo "adel:new@2024" | chroot /mnt chpasswd
    chroot /mnt usermod -aG sudo adel
fi

# Install GRUB
echo "Installing GRUB bootloader..."
chroot /mnt grub-install "$DISK"
chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg || echo "GRUB configuration failed."

# Cleanup
echo "Cleaning up..."
umount -f /mnt/boot/efi
umount -f /mnt/proc /mnt/sys /mnt/dev /mnt

# Display success message
echo "Minimal Ubuntu Server setup complete!"
