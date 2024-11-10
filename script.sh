#!/bin/bash

# Function to check the success of a command
check_success() {
    if [ $? -ne 0 ]; then
        echo "Error: $1 failed. Exiting script."
        exit 1
    fi
}

# Step 0: Remove any files called "noaman*" in /root
echo "Removing any files named 'noaman*' in /root..."
rm -f /root/noaman*
check_success "Removing 'noaman*' files"

# Ensure the script is executed as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root."
    sudo bash "$0" "$@"
    exit 0
fi

echo "Starting automated Ubuntu Server setup..."

# Step 1: Configure Google DNS
echo "Configuring Google DNS..."
echo "nameserver 8.8.8.8" > /etc/resolv.conf
echo "nameserver 8.8.4.4" >> /etc/resolv.conf
check_success "Google DNS configuration"

# Step 2: Install required dependencies
echo "Installing required dependencies..."
apt update -y && apt install -y debootstrap parted grub-efi-amd64 openssh-server
check_success "Dependencies installation"

# Step 3: Enable SSH
echo "Enabling SSH..."
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
check_success "SSH configuration"

# Step 4: Detect target disk
DISK=$(lsblk -dno NAME,TYPE | grep disk | awk '{print "/dev/"$1}' | head -n 1)
if [ -z "$DISK" ]; then
    echo "No valid disk found. Exiting."
    exit 1
fi
echo "Detected target disk: $DISK"

# Step 5: Ensure no partitions are in use
echo "Ensuring no partitions are in use..."
for partition in $(lsblk -no NAME "$DISK" | tail -n +2); do
    umount -f "/dev/${partition}" 2>/dev/null || true
done
check_success "Unmounting partitions"

# Step 6: Clear existing partitions
echo "Removing existing partitions..."
parted -s "$DISK" mklabel gpt
check_success "Partition table reset"

# Step 7: Partition the disk
echo "Partitioning the disk..."
parted -s "$DISK" mkpart primary fat32 1MiB 512MiB
check_success "Creating EFI partition"
parted -s "$DISK" set 1 boot on
parted -s "$DISK" mkpart primary ext4 512MiB 100%
check_success "Creating root partition"

# Step 8: Format partitions
BOOT_PART="${DISK}1"
ROOT_PART="${DISK}2"
echo "Formatting partitions..."
mkfs.vfat -F 32 "$BOOT_PART"
check_success "Formatting EFI partition"
mkfs.ext4 "$ROOT_PART"
check_success "Formatting root partition"

# Step 9: Mount partitions
echo "Mounting partitions..."
mount "$ROOT_PART" /mnt
check_success "Mounting root partition"
mkdir -p /mnt/boot/efi
mount "$BOOT_PART" /mnt/boot/efi
check_success "Mounting EFI partition"

# Step 10: Bootstrap Ubuntu
echo "Installing Ubuntu Server..."
debootstrap --arch=amd64 lunar /mnt http://archive.ubuntu.com/ubuntu/
check_success "Ubuntu Server installation"

# Step 11: Configure the system
echo "Configuring system..."
echo "ubuntu-server" > /mnt/etc/hostname
echo "127.0.0.1 localhost" > /mnt/etc/hosts
mount -t proc none /mnt/proc
check_success "Mounting /proc"
mount -t sysfs none /mnt/sys
check_success "Mounting /sys"
mount --bind /dev /mnt/dev
check_success "Mounting /dev"

# Step 12: Install essential packages
chroot /mnt apt update -y
chroot /mnt apt install -y openssh-server grub-efi-amd64
check_success "Installing essential packages"
chroot /mnt systemctl enable ssh
chroot /mnt sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
echo "root:new@2024" | chroot /mnt chpasswd
if ! chroot /mnt id -u adel >/dev/null 2>&1; then
    chroot /mnt adduser --gecos "" --disabled-password adel
    echo "adel:new@2024" | chroot /mnt chpasswd
    chroot /mnt usermod -aG sudo adel
fi
check_success "User and SSH configuration in chroot"

# Step 13: Install GRUB
echo "Installing GRUB bootloader..."
chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB --recheck
check_success "GRUB installation"
chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
check_success "GRUB configuration"

# Step 14: Cleanup
echo "Cleaning up..."
umount -f /mnt/boot/efi
check_success "Unmounting EFI partition"
umount -f /mnt/proc /mnt/sys /mnt/dev /mnt
check_success "Unmounting all partitions"

# Step 15: Completion message
echo "Ubuntu Server setup complete!"
echo "You can boot into the installed system and SSH using the following credentials:"
echo "  - Root: new@2024"
echo "  - User: adel / new@2024"
