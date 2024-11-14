#!/bin/bash

# Navigate to home directory
cd ~ || exit

# Clone the plugin-dongle repository
echo "Step 1: Cloning plugin-dongle repository..."
if git clone https://github.com/playsms/plugin-dongle.git; then
    echo "Repository cloned successfully."
else
    echo "Failed to clone repository."
    exit 1
fi

# Navigate to the plugin-dongle directory
cd plugin-dongle || exit

# Copy gateway source to playSMS plugin/gateway
echo "Step 2: Copying gateway source to playSMS plugin/gateway..."
if cp -r src/dongle /home/user/web/playsms/plugin/gateway/; then
    echo "Gateway source copied successfully."
else
    echo "Failed to copy gateway source."
    exit 1
fi

# Restart playSMS daemon
echo "Step 3: Restarting playSMS daemon..."
if playsmsd restart && playsmsd check; then
    echo "playSMS daemon restarted and checked successfully."
else
    echo "Failed to restart playSMS daemon."
    exit 1
fi

# Create configuration files for chan-dongle
echo "Step 4: Creating chan-dongle configuration files..."
cat <<EOL > /etc/asterisk/extensions_custom.conf
[dongle-incoming]
exten => sms,1,NoOp(Incoming SMS handler starts)
exten => sms,n,Set(PLAYSMS=/home/user/web/playsms)
exten => sms,n,Set(PLAYSMSIN=/usr/bin/php -q \${PLAYSMS}/plugin/gateway/dongle/callback.php)
exten => sms,n,GotoIf(\$[ "x\${PLAYSMS}" = "x" ]?end)
exten => sms,n,GotoIf(\$[ "x\${PLAYSMSIN}" = "x" ]?end)
exten => sms,n,Verbose(Incoming SMS smsc:\${DONGLENAME} from:\${CALLERID(num)} msg:\${BASE64_DECODE(\${SMS_BASE64})})
exten => sms,n,System(\${PLAYSMSIN} "\${PLAYSMS}" "\${DONGLENAME}" "\${STRFTIME(\${EPOCH},,%Y-%m-%d %H:%M:%S)}" "\${CALLERID(num)}" "\${SMS_BASE64}")
exten => sms,n(end),Hangup()
EOL

if [ $? -eq 0 ]; then
    echo "Configuration file for chan-dongle created successfully."
else
    echo "Failed to create configuration file for chan-dongle."
    exit 1
fi

echo "Script execution completed successfully."
