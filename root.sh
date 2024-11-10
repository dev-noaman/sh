#!/bin/bash

# Exit script on error
set -e

echo "Starting Live USB configuration..."

# Step 0: Remove the specified file explicitly
FILE_TO_REMOVE="/root/noaman-live*"
if [ -f "$FILE_TO_REMOVE" ]; then
  echo "Removing file: $FILE_TO_REMOVE"
  rm -f "$FILE_TO_REMOVE"
  echo "File $FILE_TO_REMOVE removed successfully."
else
  echo "File $FILE_TO_REMOVE does not exist. Skipping removal."
fi

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

# Step 2: Ensure SSH is installed
echo "Checking for OpenSSH server..."
if ! dpkg -l | grep -q openssh-server; then
  echo "OpenSSH server not found. Installing..."
  apt update
  apt install -y openssh-server
  echo "OpenSSH server installed successfully."
else
  echo "OpenSSH server is already installed."
fi

# Step 3: Enable and start SSH
echo "Enabling and starting SSH..."
if systemctl list-unit-files | grep -q ssh.service; then
  systemctl enable ssh
  systemctl start ssh
elif systemctl list-unit-files | grep -q sshd.service; then
  systemctl enable sshd
  systemctl start sshd
else
  echo "SSH service file not found. Please ensure OpenSSH server is installed correctly."
  exit 1
fi
echo "SSH configuration succeeded."

# Step 4: Enable root login through SSH
echo "Configuring SSH for root login..."
sed -i 's/^#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/^#PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
systemctl restart ssh || systemctl restart sshd
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
