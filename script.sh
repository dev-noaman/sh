#!/bin/bash

# Step 0: Remove any files called "noaman*" in /root
echo "Removing any files named 'noaman*' in /root..."
rm -f /root/noaman* || {
    echo "Failed to remove 'noaman*' files. Check permissions or active usage."
    exit 1
}
echo "'noaman*' files removed successfully."

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

# Step 2: Install required dependencies
echo "Installing required dependencies..."
apt update -y
apt install -y debootstrap parted grub-efi-amd64 openssh-server || {
    echo "Failed to install dependencies. Exiting."
    exit 1
}

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

# Step 4: Detect target disk
DISK=$(lsblk -dno NAME,TYPE | grep disk | awk '{print "/dev/"$1}' | head -n 1)
if [ -z "$DISK" ]; then
    echo "No valid disk found. Exiting."
    exit 1
fi
echo "Detected target disk: $DISK"

# Step 5: Unmount any mounted partitions
echo "Unmounting any mounted partitions on the target disk..."
for partition in $(lsblk -no NAME "$DISK" | tail -n +2); do
    umount -f "/dev/${partition}" 2>/dev/null || true
done

# Step 6: Partition the disk
echo "Partitioning the disk..."
parted -s "$DISK" mklabel gpt
parted -s "$DISK" mkpart primary fat32 1MiB 512MiB
parted -s "$DISK" set 1 boot on
parted -s "$DISK" mkpart primary ext4 512MiB 100%

# Step 7: Format partitions
BOOT_PART="${DISK}1"
ROOT_PART="${DISK}2"
echo "Formatting partitions..."
mkfs.vfat -F 32 "$BOOT_PART"
mkfs.ext4 "$ROOT_PART"

# Step 8: Mount partitions
echo "Mounting partitions..."
mount "$ROOT_PART" /mnt
mkdir -p /mnt/boot/efi
mount "$BOOT_PART" /mnt/boot/efi

# Step 9: Bootstrap Ubuntu
echo "Installing Ubuntu Server..."
debootstrap --arch=amd64 lunar /mnt http://archive.ubuntu.com/ubuntu/

# Step 10: Configure the system
echo "Configuring system..."
echo "ubuntu-server" > /mnt/etc/hostname
echo "127.0.0.1 localhost" > /mnt/etc/hosts
mount -t proc none /mnt/proc
mount -t sysfs none /mnt/sys
mount --bind /dev /mnt/dev

# Step 11: Install essential packages
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

# Step 12: Install GRUB
echo "Installing GRUB bootloader..."
chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB || {
    echo "GRUB installation failed. Exiting."
    exit 1
}
chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg

# Step 13: Cleanup
echo "Cleaning up..."
umount -f /mnt/boot/efi
umount -f /mnt/proc /mnt/sys /mnt/dev /mnt

# Step 14: Completion message
echo "Ubuntu Server setup complete!"
echo "You can boot into the installed system and SSH using the following credentials:"
echo "  - Root: new@2024"
echo "  - User: adel / new@2024"
