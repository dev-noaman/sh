#!/bin/bash

# Exit script on error
set -e

echo "Starting Live USB configuration..."

# Step 1: Configure Google DNS
echo "Configuring Google DNS..."
echo "nameserver 8.8.8.8" > /etc/resolv.conf
echo "nameserver 8.8.4.4" >> /etc/resolv.conf
echo "Google DNS configuration succeeded."

# Step 2: Enable SSH for the Live USB environment
echo "Enabling SSH..."
systemctl enable ssh
systemctl start ssh
echo "SSH configuration succeeded."

# Step 3: Enable root login through SSH
echo "Configuring SSH for root login..."
sed -i 's/^#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/^#PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
systemctl restart ssh
echo "Root login through SSH enabled."

# Step 4: Configure root and user accounts for Live USB
echo "Configuring user accounts for Live USB environment..."
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

# Step 5: Display Live USB SSH information
LIVE_USB_IP=$(hostname -I | awk '{print $1}')
echo "Live USB configuration complete! You can SSH into the Live USB using the following credentials:"
echo "  - Root: new@2024"
echo "  - User: adel / new@2024"
echo "  - Live USB IP Address: $LIVE_USB_IP"
