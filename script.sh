#!/bin/bash

# Function to check if the last command succeeded
check_success() {
    if [ $? -eq 0 ]; then
        echo "$1 succeeded."
    else
        echo "$1 failed. Exiting script."
        exit 1
    fi
}

# Step 1: Remove any existing noaman files
echo "Removing any files named 'noaman*' in /root..."
rm -f /root/noaman*
check_success "File cleanup"

# Step 2: Configure Google DNS
echo "Configuring Google DNS..."
echo "nameserver 8.8.8.8" > /etc/resolv.conf
echo "nameserver 8.8.4.4" >> /etc/resolv.conf
check_success "Google DNS configuration"

# Step 3: Disable CD-ROM repository
echo "Disabling CD-ROM repository if enabled..."
sed -i '/cdrom:/s/^/#/' /etc/apt/sources.list
check_success "CD-ROM repository disabling"

# Step 4: Install required dependencies
echo "Installing required dependencies..."
apt update && apt install -y net-tools debootstrap grub-efi-amd64 openssh-server parted
check_success "Dependencies installation"

# Step 5: Enable SSH
echo "Enabling SSH..."
systemctl enable ssh
check_success "SSH configuration"

# Step 6: Configure users for Live USB
echo "Checking and creating users for Live USB environment..."
echo "root:new@2024" | chpasswd
check_success "Root password update"
id adel &>/dev/null || useradd -m adel
echo "adel:new@2024" | chpasswd
check_success "User adel password update"

# Step 7: Detect target disk
echo "Detecting target disk..."
TARGET_DISK=$(lsblk -ndp -o NAME | grep -v "$(df / | tail -1 | awk '{print $1}')")
if [ -z "$TARGET_DISK" ]; then
    echo "No suitable target disk found. Exiting script."
    exit 1
fi
echo "Detected target disk: $TARGET_DISK"

# Step 8: Unmount any partitions on the target disk
echo "Unmounting existing partitions on $TARGET_DISK..."
for PART in $(lsblk -lnp $TARGET_DISK | awk '{print $1}'); do
    umount -lf $PART || true
done
echo "Killing processes using $TARGET_DISK..."
lsof | grep $TARGET_DISK | awk '{print $2}' | xargs -r kill -9
check_success "Disk unmounting and process cleanup"

# Step 9: Partition the disk
echo "Partitioning the disk..."
parted --script $TARGET_DISK \
    mklabel gpt \
    mkpart primary fat32 1MiB 512MiB \
    set 1 esp on \
    mkpart primary ext4 512MiB 100%
check_success "Disk partitioning"

# Step 10: Format partitions
echo "Formatting partitions..."
mkfs.vfat -F32 "${TARGET_DISK}1"
check_success "EFI partition formatting"
mkfs.ext4 "${TARGET_DISK}2"
check_success "Root partition formatting"

# Step 11: Mount partitions
echo "Mounting partitions..."
mount "${TARGET_DISK}2" /mnt
mkdir -p /mnt/boot/efi
mount "${TARGET_DISK}1" /mnt/boot/efi
check_success "Partition mounting"

# Step 12: Install minimal Ubuntu system
echo "Installing minimal Ubuntu system..."
debootstrap --arch=amd64 focal /mnt http://archive.ubuntu.com/ubuntu/
check_success "Minimal Ubuntu installation"

# Step 13: Configure system
echo "Configuring system..."
echo "root:new@2024" | chroot /mnt chpasswd
check_success "Root password configuration in installed system"
chroot /mnt useradd -m adel
echo "adel:new@2024" | chroot /mnt chpasswd
check_success "User adel configuration in installed system"

# Step 14: Install GRUB Bootloader
echo "Installing GRUB bootloader..."
chroot /mnt grub-install --target=x86_64-efi --bootloader-id=ubuntu --recheck
check_success "GRUB installation"
chroot /mnt update-grub
check_success "GRUB configuration"

# Step 15: Cleanup
echo "Cleaning up..."
umount -lf /mnt/boot/efi
umount -lf /mnt
check_success "Cleanup"

# Step 16: Completion message for installed system with Server IP
SERVER_IP=$(chroot /mnt hostname -I | awk '{print $1}')
echo "Ubuntu Server setup complete!"
echo "You can boot into the installed system and SSH using the following credentials:"
echo "  - Root: new@2024"
echo "  - User: adel / new@2024"
echo "  - Installed Server IP Address: $SERVER_IP"
