#!/bin/bash

# Exit script on error
set -e

echo "Removing any files named 'noaman*' in /root..."
rm -f /root/noaman*

echo "Starting automated Ubuntu Server setup..."

# Step 1: Configure Google DNS
echo "Configuring Google DNS..."
echo "nameserver 8.8.8.8" > /etc/resolv.conf
echo "nameserver 8.8.4.4" >> /etc/resolv.conf
echo "Google DNS configuration succeeded."

# Step 2: Disable CD-ROM repository if enabled
echo "Disabling CD-ROM repository if enabled..."
sed -i '/cdrom:/s/^/#/' /etc/apt/sources.list
echo "CD-ROM repository disabled."

# Step 3: Install required dependencies
echo "Installing required dependencies..."
apt-get update
apt-get install -y debootstrap grub-efi-amd64 openssh-server parted net-tools
echo "Dependencies installation succeeded."

# Step 4: Enable SSH for the live USB environment
echo "Enabling SSH..."
systemctl enable ssh
systemctl start ssh
echo "SSH configuration succeeded."

# Step 5: Configure root and user accounts for Live USB
echo "Checking and creating users for Live USB environment..."
echo "root:new@2024" | chpasswd
echo "Root password update succeeded."
if id "adel" &>/dev/null; then
  echo "adel:new@2024" | chpasswd
  echo "User adel password update succeeded."
else
  useradd -m -s /bin/bash adel
  echo "adel:new@2024" | chpasswd
  echo "User adel created and password update succeeded."
fi

# Step 6: Display Live USB SSH information
LIVE_USB_IP=$(hostname -I | awk '{print $1}')
echo "You can SSH into this Live USB using the following credentials:"
echo "  - Root: new@2024"
echo "  - User: adel / new@2024"
echo "  - Live USB IP Address: $LIVE_USB_IP"

# Step 7: Detect target disk
echo "Detecting target disk..."
TARGET_DISK=$(lsblk -nd --output NAME,SIZE | grep -E 'sd|nvme' | awk '{print "/dev/"$1}' | head -n 1)
if [ -z "$TARGET_DISK" ]; then
  echo "Error: No suitable target disk found. Exiting."
  exit 1
fi
echo "Detected target disk: $TARGET_DISK"

# Step 8: Unmount existing partitions on the target disk
echo "Unmounting existing partitions on $TARGET_DISK..."
umount -l ${TARGET_DISK}* || true
lsof | grep $TARGET_DISK | awk '{print $2}' | xargs -r kill -9 || true
partprobe $TARGET_DISK
echo "Disk unmounted and refreshed."

# Step 9: Partition the target disk
echo "Partitioning the disk..."
parted --script $TARGET_DISK mklabel gpt
parted --script $TARGET_DISK mkpart ESP fat32 1MiB 512MiB
parted --script $TARGET_DISK set 1 boot on
parted --script $TARGET_DISK mkpart primary ext4 512MiB 100%
echo "Disk partitioning succeeded."

# Step 10: Format the partitions
echo "Formatting partitions..."
mkfs.vfat -F32 ${TARGET_DISK}1
mkfs.ext4 ${TARGET_DISK}2
echo "Disk formatting succeeded."

# Step 11: Mount the partitions
echo "Mounting partitions..."
mount ${TARGET_DISK}2 /mnt
mkdir -p /mnt/boot/efi
mount ${TARGET_DISK}1 /mnt/boot/efi
echo "Partitions mounted."

# Step 12: Install Ubuntu minimal system
echo "Installing Ubuntu minimal system..."
debootstrap --arch=amd64 lunar /mnt http://archive.ubuntu.com/ubuntu/
echo "Base system installation succeeded."

# Step 13: Configure the new system
echo "Configuring the new system..."
cat <<EOF > /mnt/etc/fstab
${TARGET_DISK}2 / ext4 errors=remount-ro 0 1
${TARGET_DISK}1 /boot/efi vfat umask=0077 0 1
EOF

echo "nameserver 8.8.8.8" > /mnt/etc/resolv.conf
echo "nameserver 8.8.4.4" >> /mnt/etc/resolv.conf

mount -t proc none /mnt/proc
mount --rbind /sys /mnt/sys
mount --rbind /dev /mnt/dev

chroot /mnt /bin/bash -c "apt-get update && apt-get install -y openssh-server net-tools grub-efi-amd64"
chroot /mnt /bin/bash -c "systemctl enable ssh"

echo "Creating users in the new system..."
chroot /mnt /bin/bash -c "echo 'root:new@2024' | chpasswd"
chroot /mnt /bin/bash -c "useradd -m -s /bin/bash adel"
chroot /mnt /bin/bash -c "echo 'adel:new@2024' | chpasswd"
echo "Users configured successfully."

# Step 14: Install GRUB bootloader
echo "Installing GRUB bootloader..."
chroot /mnt /bin/bash -c "grub-install $TARGET_DISK"
chroot /mnt /bin/bash -c "update-grub"
echo "GRUB bootloader installation succeeded."

# Step 15: Cleanup
echo "Cleaning up..."
umount -R /mnt || true
echo "Cleanup succeeded."

# Step 16: Completion message
SERVER_IP=$(ip addr show | grep 'inet ' | grep -v '127.0.0.1' | awk '{print $2}' | cut -d/ -f1 | head -n 1)
echo "Ubuntu Server setup complete!"
echo "You can boot into the installed system and SSH using the following credentials:"
echo "  - Root: new@2024"
echo "  - User: adel / new@2024"
echo "  - Server IP Address: $SERVER_IP"
