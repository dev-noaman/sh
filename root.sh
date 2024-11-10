#!/bin/bash

# Exit script on error
set -e

echo "Starting Live USB configuration..."


# Step 1: Configure Google DNS
echo "Configuring Google DNS..."
if chattr -i /etc/resolv.conf 2>/dev/null; then
  echo "Immutable bit cleared for /etc/resolv.conf."
fi
cat <<EOF > /etc/resolv.conf
nameserver 8.8.8.8
nameserver 8.8.4.4
EOF
echo "Google DNS configuration succeeded."

# Step 2: Ensure SSH is installed explicitly
echo "Installing OpenSSH server..."
apt update
apt install -y openssh-server
echo "OpenSSH server installed successfully."

# Step 3: Enable and start SSH explicitly
echo "Enabling and starting SSH service..."
systemctl enable ssh
systemctl start ssh
echo "SSH service enabled and started successfully."

# Step 4: Enable root login through SSH
echo "Configuring SSH for root login..."
sed -i 's/^#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/^#PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
systemctl restart ssh
echo "Root login through SSH enabled."

# Step 5: Configure root and user accounts for Live USB
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

# Step 6: Display Live USB SSH information
LIVE_USB_IP=$(hostname -I | awk '{print $1}')
echo "Live USB configuration complete! You can SSH into the Live USB using the following credentials:"
echo "  - Root: new@2024"
echo "  - User: adel / new@2024"
echo "  - Live USB IP Address: $LIVE_USB_IP"

echo "Configuration finished successfully!"
