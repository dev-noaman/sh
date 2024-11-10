#!/bin/bash

# Ensure the script is executed as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root."
    echo "Switching to root user..."
    sudo bash "$0" "$@"
    exit 0
fi

echo "Starting fully automated minimal Ubuntu Server 24.04 setup..."

# Step 1: Configure Google DNS for Live USB
echo "Configuring Google DNS on Live USB..."
echo "nameserver 8.8.8.8" > /etc/resolv.conf
echo "nameserver 8.8.4.4" >> /etc/resolv.conf
echo "DNS configuration set to Google's public DNS servers."

# Step 2: Check and Install Missing Dependencies
echo "Checking and installing missing dependencies..."
apt update -y
apt install -y debootstrap parted grub-efi-amd64 openssh-server || {
    echo "Failed to install necessary dependencies. Check your network or package manager."
    exit 1
}
echo "All required dependencies are installed."

# Step 3: Enable SSH on the Live USB
echo "Enabling SSH on Live USB..."
systemctl start ssh
systemctl enable ssh
sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
systemctl restart ssh
echo "root:new@2024" | chpasswd
adduser --gecos "" --disabled-password adel
echo "adel:new@2024" | chpasswd
usermod -aG sudo adel
echo "SSH enabled with root and user credentials."

# Fetch and display the Live USB's IP address
IP_ADDRESS=$(hostname -I | awk '{print $1}')
echo "You can SSH into this Live USB using its IP address:"
echo "  - Root: new@2024"
echo "  - User: adel / new@2024"
echo "  - IP Address: ${IP_ADDRESS}"

# Step 4: Detect Target Disk
echo "Detecting target disk..."
DISK=$(lsblk -dno NAME,TYPE | grep disk | awk '{print "/dev/"$1}' | head -n 1)

if [ -z "$DISK" ]; then
    echo "No valid disk found. Please ensure a disk is connected."
    exit 1
fi

echo "Detected target disk: $DISK"

# Step 5: Unmount Any Mounted Partitions
echo "Unmounting any mounted partitions on the target disk..."
for partition in $(lsblk -no NAME "${DISK}" | tail -n +2); do
    umount "/dev/${partition}" 2>/dev/null || true
done

# Step 6: Partition the Disk
echo "Partitioning the disk..."
parted -s "${DISK}" mklabel gpt
parted -s "${DISK}" mkpart primary fat32 1MiB 512MiB
parted -s "${DISK}" set 1 boot on
parted -s "${DISK}" mkpart primary ext4 512MiB 100%

# Format the Partitions
echo "Formatting partitions..."
BOOT_PART="${DISK}1"
ROOT_PART="${DISK}2"
mkfs.vfat -F 32 "${BOOT_PART}"
mkfs.ext4 "${ROOT_PART}"

# Mount the Partitions
echo "Mounting partitions..."
mount "${ROOT_PART}" /mnt
mkdir -p /mnt/boot/efi
mount "${BOOT_PART}" /mnt/boot/efi

# Step 7: Install Minimal Ubuntu Server System
echo "Installing minimal Ubuntu Server system..."
debootstrap --arch=amd64 lunar /mnt http://archive.ubuntu.com/ubuntu/

# Configure the System
echo "Configuring system..."
echo "ubuntu-server" > /mnt/etc/hostname
echo "127.0.0.1 localhost" > /mnt/etc/hosts
mount -t proc none /mnt/proc
mount -t sysfs none /mnt/sys
mount --bind /dev /mnt/dev

# Step 8: Install Essential Packages
echo "Installing essential packages..."
chroot /mnt apt update -y
chroot /mnt apt install -y openssh-server grub-efi-amd64
chroot /mnt systemctl enable ssh
chroot /mnt sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
chroot /mnt systemctl restart ssh
echo "root:new@2024" | chroot /mnt chpasswd
chroot /mnt adduser --gecos "" --disabled-password adel
echo "adel:new@2024" | chroot /mnt chpasswd
chroot /mnt usermod -aG sudo adel

# Step 9: Install GRUB Bootloader
echo "Installing GRUB bootloader..."
mount --bind /dev /mnt/dev
chroot /mnt grub-install "${DISK}"
chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg

# Final Cleanup
echo "Cleaning up..."
umount /mnt/boot/efi
umount /mnt/proc /mnt/sys /mnt/dev /mnt

# Display the IP Address of the Installed System
echo "Minimal Ubuntu Server system setup complete!"
echo "You can now boot into the installed system and SSH using the credentials:"
echo "  - Root: new@2024"
echo "  - User: adel / new@2024"
