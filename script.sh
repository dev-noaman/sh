#!/bin/bash

# Disk to partition - replace 'nvme0n1' with your disk name if different
DISK="/dev/nvme0n1"

# Function to check for GRUB installation
check_grub_installed() {
    if ! command -v grub-install &> /dev/null; then
        echo "GRUB is not installed. Installing GRUB..."
        apt update
        apt install -y grub-efi grub-pc
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

    # Create EFI System Partition (ESP)
    parted "$DISK" --script mklabel gpt
    parted "$DISK" --script mkpart primary fat32 1MiB 512MiB
    parted "$DISK" --script set 1 esp on

    # Create Root Partition
    parted "$DISK" --script mkpart primary ext4 512MiB 20.5GiB

    # Create Swap Partition
    parted "$DISK" --script mkpart primary linux-swap 20.5GiB 24.5GiB

    # Create Home Partition
    parted "$DISK" --script mkpart primary ext4 24.5GiB 100%

    rescan_partitions
}

# Function to format partitions
format_partitions() {
    echo "Formatting EFI System Partition (ESP) as FAT32..."
    mkfs.fat -F32 "${DISK}p1"

    echo "Formatting root partition as ext4..."
    mkfs.ext4 "${DISK}p2"

    echo "Formatting home partition as ext4..."
    mkfs.ext4 "${DISK}p4"

    echo "Setting up swap partition..."
    mkswap "${DISK}p3"
    swapon "${DISK}p3"
}

# Function to install GRUB in UEFI mode
install_grub() {
    echo "Installing GRUB in UEFI mode..."

    # Mount root and ESP
    mount "${DISK}p2" /mnt
    mkdir -p /mnt/boot/efi
    mount "${DISK}p1" /mnt/boot/efi

    # Install GRUB for UEFI
    grub-install --target=x86_64-efi --boot-directory=/mnt/boot --efi-directory=/mnt/boot/efi --removable

    # Generate GRUB configuration
    chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg

    # Unmount
    umount -R /mnt
    swapoff "${DISK}p3"
}

# Step 1: Ensure GRUB is installed
check_grub_installed

# Step 2: Create partitions
create_partitions

# Step 3: Format partitions
format_partitions

# Step 4: Install GRUB in UEFI mode
install_grub

echo "Partitioning, formatting, and GRUB installation complete."
echo "Disk setup for $DISK is complete. You can now proceed with the Ubuntu installation."

# Final check
lsblk "$DISK"

echo "Done!"
