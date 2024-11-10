#!/bin/bash

set -e

# Function to check if the previous command succeeded
check_success() {
    if [ $? -eq 0 ]; then
        echo "$1 succeeded."
    else
        echo "Error: $1 failed. Exiting script."
        exit 1
    fi
}

echo "Removing any files named 'noaman*' in /root..."
rm -f /root/noaman*
check_success "File cleanup"

echo "Starting automated Ubuntu Server setup..."

# Step 1: Configure Google DNS
echo "Configuring Google DNS..."
echo -e "nameserver 8.8.8.8\nnameserver 8.8.4.4" > /etc/resolv.conf
check_success "Google DNS configuration"

# Step 2: Disable CD-ROM Repository
echo "Disabling CD-ROM repository if enabled..."
if grep -q "^deb cdrom:" /etc/apt/sources.list; then
    sed -i 's/^deb cdrom:/#deb cdrom:/g' /etc/apt/sources.list
    echo "CD-ROM repository disabled."
else
    echo "CD-ROM repository is not enabled."
fi

# Step 3: Install required dependencies
echo "Installing required dependencies..."
apt update -y && apt install -y debootstrap parted grub-efi-amd64 openssh-server net-tools
check_success "Dependencies installation"

# Step 4: Enable SSH
echo "Enabling SSH..."
systemctl enable ssh
systemctl start ssh
check_success "SSH configuration"

# Step 5: Check and create users for Live USB
echo "Checking and creating users for Live USB environment..."
if ! id -u root &>/dev/null; then
    echo "Creating root user..."
    echo "root:new@2024" | chpasswd
    check_success "Root user creation"
else
    echo "Root user already exists. Updating password..."
    echo "root:new@2024" | chpasswd
    check_success "Root password update"
fi

if ! id -u adel &>/dev/null; then
    echo "Creating user adel..."
    useradd -m -s /bin/bash adel
    echo "adel:new@2024" | chpasswd
    check_success "User adel creation"
else
    echo "User adel already exists. Updating password..."
    echo "adel:new@2024" | chpasswd
    check_success "Adel password update"
fi

# Display Live USB IP address
LIVE_USB_IP=$(hostname -I | awk '{print $1}')
echo "You can SSH into this Live USB using the following credentials:"
echo "  - Root: new@2024"
echo "  - User: adel / new@2024"
echo "  - Live USB IP Address: $LIVE_USB_IP"

# Step 6: Detect target disk
echo "Detecting target disk..."
TARGET_DISK=$(lsblk -dpno NAME | grep -E "/dev/sd|/dev/nvme" | head -n 1)
if [ -z "$TARGET_DISK" ]; then
    echo "Error: No target disk detected. Exiting script."
    exit 1
fi
echo "Detected target disk: $TARGET_DISK"

# Step 7: Unmount any existing partitions
echo "Unmounting existing partitions on $TARGET_DISK..."
umount "${TARGET_DISK}"* || true

# Step 8: Partition the disk
echo "Partitioning the disk..."
parted --script "$TARGET_DISK" \
    mklabel gpt \
    mkpart ESP fat32 1MiB 512MiB \
    set 1 boot on \
    mkpart primary ext4 512MiB 100%
check_success "Disk partitioning"

# Step 9: Format partitions
echo "Formatting partitions..."
mkfs.vfat -F32 "${TARGET_DISK}1"
check_success "EFI partition formatting"
mkfs.ext4 "${TARGET_DISK}2"
check_success "Root partition formatting"

# Step 10: Mount partitions
echo "Mounting partitions..."
mount "${TARGET_DISK}2" /mnt
mkdir -p /mnt/boot/efi
mount "${TARGET_DISK}1" /mnt/boot/efi
check_success "Partition mounting"

# Step 11: Install minimal Ubuntu Server system
echo "Installing minimal Ubuntu Server system..."
debootstrap --arch=amd64 lunar /mnt http://archive.ubuntu.com/ubuntu/
check_success "Base system installation"

# Step 12: Configure the system
echo "Configuring the installed system..."
mount --bind /dev /mnt/dev
mount --bind /proc /mnt/proc
mount --bind /sys /mnt/sys
echo "ubuntu-server" > /mnt/etc/hostname
cat << EOF > /mnt/etc/hosts
127.0.0.1   localhost
127.0.1.1   ubuntu-server
EOF
check_success "System configuration"

# Step 13: Configure and install essential packages
echo "Installing essential packages..."
chroot /mnt apt update -y
chroot /mnt apt install -y openssh-server grub-efi-amd64
check_success "Essential packages installation"

# Step 14: Check and create users for the installed system
echo "Checking and creating users for the installed system..."
chroot /mnt bash -c '
if ! id -u root &>/dev/null; then
    echo "Creating root user..."
    echo "root:new@2024" | chpasswd
else
    echo "Root user already exists. Updating password..."
    echo "root:new@2024" | chpasswd
fi

if ! id -u adel &>/dev/null; then
    echo "Creating user adel..."
    useradd -m -s /bin/bash adel
    echo "adel:new@2024" | chpasswd
else
    echo "User adel already exists. Updating password..."
    echo "adel:new@2024" | chpasswd
fi
'
check_success "User creation for installed system"

# Step 15: Install GRUB Bootloader
echo "Installing GRUB bootloader..."
chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=ubuntu
check_success "GRUB installation"
chroot /mnt update-grub
check_success "GRUB configuration"

# Step 16: Cleanup
echo "Cleaning up..."
umount -l /mnt/dev || true
umount -l /mnt/proc || true
umount -l /mnt/sys || true
umount -l /mnt/boot/efi || true
umount -l /mnt || true
check_success "Cleanup"

# Step 17: Completion message
INSTALLED_SYSTEM_IP=$(chroot /mnt hostname -I | awk '{print $1}')
echo "Ubuntu Server setup complete!"
echo "You can boot into the installed system and SSH using the following credentials:"
echo "  - Root: new@2024"
echo "  - User: adel / new@2024"
echo "  - Installed System IP Address: $INSTALLED_SYSTEM_IP"
