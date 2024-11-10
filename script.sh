#!/bin/bash

# Disk to partition - replace 'nvme0n1' with your disk name if different
DISK="/dev/nvme0n1"

# Function to check for GRUB installation
check_grub_installed() {
    if ! command -v grub-install &> /dev/null; then
        echo "GRUB is not installed. Installing GRUB..."
        apt update
        apt install -y grub-pc grub-efi
    else
        echo "GRUB is already installed."
    fi
}

# Function to rescan partitions
rescan_partitions() {
    echo "Rescanning disk to ensure partitions are recognized..."
    partprobe "$DISK"
    sleep 5  # Give kernel time to recognize new partitions
}

# Function to create partitions
create_partitions() {
    echo "Creating partitions on $DISK..."
    parted "$DISK" --script mklabel gpt
    parted "$DISK" --script mkpart primary ext4 1MiB 20GiB
    parted "$DISK" --script mkpart primary linux-swap 20GiB 24GiB
    parted "$DISK" --script mkpart primary ext4 24GiB 100%
    rescan_partitions
}

# Function to format partitions
format_partitions() {
    echo "Formatting root partition as ext4..."
    mkfs.ext4 "${DISK}p1"

    echo "Formatting home partition as ext4..."
    mkfs.ext4 "${DISK}p3"

    echo "Setting up swap partition..."
    mkswap "${DISK}p2"
    swapon "${DISK}p2"
}

# Function to install GRUB
install_grub() {
    echo "Installing GRUB on $DISK..."
    mount "${DISK}p1" /mnt
    mkdir -p /mnt/boot
    grub-install --boot-directory=/mnt/boot --target=i386-pc "$DISK"
    umount /mnt
}

# Step 1: Check for GRUB installation
check_grub_installed

# Step 2: Create partitions
create_partitions

# Step 3: Format partitions
format_partitions

# Step 4: Install GRUB
install_grub

echo "Partitioning, formatting, and GRUB installation complete."
echo "Disk setup for $DISK is complete. You can now proceed with the Ubuntu installation."

# Final check
lsblk "$DISK"

echo "Done!"
