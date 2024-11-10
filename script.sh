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

# Function to check if the disk has partitions
check_partitions() {
    echo "Checking for existing partitions on $DISK..."
    lsblk -no NAME "$DISK" | grep -q "${DISK##*/}p"
    if [ $? -eq 0 ]; then
        echo "Existing partitions detected on $DISK:"
        lsblk "$DISK"
        return 0
    else
        echo "No existing partitions found on $DISK."
        return 1
    fi
}

# Function to delete all partitions on the disk
delete_partitions() {
    echo "Deleting all partitions on $DISK..."
    for PART in $(lsblk -no NAME "$DISK" | grep "${DISK##*/}p"); do
        echo "Deleting /dev/$PART..."
        parted "$DISK" rm "$(echo $PART | grep -o '[0-9]*')"
    done
    echo "All partitions deleted."
}

# Step 1: Check if GRUB is installed
check_grub_installed

# Step 2: Check for existing partitions
check_partitions
if [ $? -eq 0 ]; then
    echo "Do you want to delete existing partitions? (yes/no)"
    read CONFIRM
    if [ "$CONFIRM" != "yes" ]; then
        echo "Operation canceled. No changes were made."
        exit 1
    fi
    delete_partitions
fi

# Step 3: Create a new GPT partition table
echo "Creating a new GPT partition table on $DISK..."
parted $DISK --script mklabel gpt

# Step 4: Create partitions
echo "Creating partitions..."
parted $DISK --script mkpart primary ext4 1MiB 20GiB
parted $DISK --script mkpart primary linux-swap 20GiB 24GiB
parted $DISK --script mkpart primary ext4 24GiB 100%

# Rescan disk to ensure partitions are recognized
echo "Rescanning disk to ensure partitions are recognized..."
partprobe $DISK
sleep 5  # Allow time for the kernel to recognize the partitions

# Step 5: Format partitions
echo "Formatting root partition as ext4..."
mkfs.ext4 "${DISK}p1"

echo "Formatting home partition as ext4..."
mkfs.ext4 "${DISK}p3"

echo "Setting up swap partition..."
mkswap "${DISK}p2"
swapon "${DISK}p2"

# Step 6: Install GRUB
echo "Installing GRUB on $DISK..."
mount "${DISK}p1" /mnt
mkdir -p /mnt/boot
grub-install --boot-directory=/mnt/boot --target=i386-pc $DISK

# Clean up
umount /mnt

echo "Partitioning, formatting, and GRUB installation complete."
echo "Disk setup for $DISK is complete. You can now proceed with the Ubuntu installation."

# Final check
lsblk $DISK

echo "Done!"
