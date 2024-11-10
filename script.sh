#!/bin/bash

# Disk to partition - replace 'nvme0n1' with your disk name if different
DISK="/dev/nvme0n1"

# Log start
echo "Starting automated disk setup for $DISK..."

# Step 1: Install GRUB if not already installed
echo "Ensuring GRUB is installed..."
if ! command -v grub-install &> /dev/null; then
    echo "Installing GRUB..."
    apt update
    apt install grub-pc grub-efi -y
fi

# Step 2: Create a new GPT partition table
echo "Creating a new GPT partition table on $DISK..."
parted $DISK --script mklabel gpt

# Step 3: Create partitions
# Partition 1: Root (20GB)
echo "Creating root partition..."
parted $DISK --script mkpart primary ext4 1MiB 20GiB

# Partition 2: Swap (4GB)
echo "Creating swap partition..."
parted $DISK --script mkpart primary linux-swap 20GiB 24GiB

# Partition 3: Home (remaining space)
echo "Creating home partition..."
parted $DISK --script mkpart primary ext4 24GiB 100%

# Step 4: Format partitions
echo "Formatting root partition as ext4..."
mkfs.ext4 "${DISK}p1"

echo "Formatting home partition as ext4..."
mkfs.ext4 "${DISK}p3"

echo "Setting up swap partition..."
mkswap "${DISK}p2"
swapon "${DISK}p2"

# Step 5: Install GRUB
echo "Installing GRUB on $DISK..."
mount "${DISK}p1" /mnt
grub-install --root-directory=/mnt $DISK

# Step 6: Clean up and finalize
umount /mnt

echo "Partitioning, formatting, and GRUB installation complete."
echo "Disk setup for $DISK is complete. You can now proceed with the Ubuntu installation."

# Final check
lsblk $DISK

echo "Done!"
