#!/bin/bash

set -e

check_success() {
    if [ $? -ne 0 ]; then
        echo "Error encountered at step: $1. Exiting script."
        exit 1
    fi
}

echo "Removing any files named 'noaman*' in /root..."
rm -f /root/noaman* || true
echo "File cleanup succeeded."

echo "Starting automated Ubuntu Server setup..."

# Step 1: Configure Google DNS
echo "Configuring Google DNS..."
cat <<EOF >/etc/resolv.conf
nameserver 8.8.8.8
nameserver 8.8.4.4
EOF
check_success "Google DNS configuration"

# Step 2: Disable CD-ROM repository
echo "Disabling CD-ROM repository if enabled..."
sed -i '/cdrom:/s/^/#/' /etc/apt/sources.list
check_success "Disabling CD-ROM repository"

# Step 3: Install required dependencies
echo "Installing required dependencies..."
apt-get update && apt-get install -y net-tools debootstrap grub-efi-amd64 openssh-server parted
check_success "Dependencies installation"

# Step 4: Enable SSH
echo "Enabling SSH..."
systemctl enable ssh
check_success "SSH configuration"

# Step 5: Create users for Live USB
echo "Checking and creating users for Live USB environment..."
echo "root:new@2024" | chpasswd
check_success "Root password update"
id adel &>/dev/null || adduser --disabled-password --gecos "" adel
echo "adel:new@2024" | chpasswd
check_success "Adel password update"

# Step 6: Detect and confirm target disk
TARGET_DISK="/dev/nvme0n1"
echo "Selected target disk: $TARGET_DISK"

# Step 7: Unmount any partitions on the target disk
echo "Unmounting existing partitions on $TARGET_DISK..."
for PART in $(lsblk -lnp $TARGET_DISK | awk '{print $1}'); do
    umount -lf $PART || true
done
echo "Killing processes using $TARGET_DISK..."
lsof | grep $TARGET_DISK | awk '{print $2}' | xargs -r kill -9
check_success "Disk unmounting and process cleanup"

# Step 8: Partition the disk
echo "Partitioning $TARGET_DISK..."
parted $TARGET_DISK mklabel gpt
parted $TARGET_DISK mkpart ESP fat32 1MiB 512MiB
parted $TARGET_DISK set 1 boot on
parted $TARGET_DISK mkpart primary ext4 512MiB 100%
check_success "Disk partitioning"

# Step 9: Format the partitions
echo "Formatting partitions..."
mkfs.vfat -F 32 "${TARGET_DISK}p1"
mkfs.ext4 "${TARGET_DISK}p2"
check_success "Partition formatting"

# Step 10: Mount partitions
echo "Mounting partitions..."
mount "${TARGET_DISK}p2" /mnt
mkdir -p /mnt/boot/efi
mount "${TARGET_DISK}p1" /mnt/boot/efi
check_success "Partition mounting"

# Step 11: Install Ubuntu Server base system
echo "Installing Ubuntu Server base system..."
debootstrap --arch=amd64 lunar /mnt http://archive.ubuntu.com/ubuntu/
check_success "Ubuntu Server base system installation"

# Step 12: Configure the base system
echo "Configuring the base system..."
echo "nameserver 8.8.8.8" > /mnt/etc/resolv.conf
mount --bind /dev /mnt/dev
mount --bind /proc /mnt/proc
mount --bind /sys /mnt/sys
chroot /mnt /bin/bash -c "apt-get update && apt-get install -y grub-efi-amd64 openssh-server net-tools"
check_success "Base system configuration"

# Step 13: Install and configure GRUB
echo "Installing GRUB bootloader..."
chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=ubuntu
chroot /mnt update-grub
check_success "GRUB installation and configuration"

# Step 14: Set root and user passwords in the new system
echo "Setting root and user passwords in the new system..."
chroot /mnt /bin/bash -c "echo 'root:new@2024' | chpasswd"
chroot /mnt /bin/bash -c "id adel &>/dev/null || adduser --disabled-password --gecos '' adel"
chroot /mnt /bin/bash -c "echo 'adel:new@2024' | chpasswd"
check_success "Password setup in the new system"

# Step 15: Clean up
echo "Cleaning up..."
umount -l /mnt/dev || true
umount -l /mnt/proc || true
umount -l /mnt/sys || true
umount -l /mnt/boot/efi || true
umount -l /mnt || true
check_success "Cleanup"

# Step 16: Completion message
SERVER_IP=$(hostname -I | awk '{print $1}')
echo "Ubuntu Server setup complete!"
echo "You can boot into the installed system and SSH using the following credentials:"
echo "  - Root: new@2024"
echo "  - User: adel / new@2024"
echo "  - Server IP Address: $SERVER_IP"
