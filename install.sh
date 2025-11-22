#!/bin/bash

# Family Calendar Display - Installation Script for Raspberry Pi
# This script sets up the calendar display to run on boot

set -e

echo "=================================="
echo "Family Calendar Display Installer"
echo "=================================="
echo ""

# Check if running on Raspberry Pi
if [ ! -f /proc/device-tree/model ]; then
    echo "Warning: This script is designed for Raspberry Pi"
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Get the current directory
INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "Installation directory: $INSTALL_DIR"

# Check if config.json exists
if [ ! -f "$INSTALL_DIR/config.json" ]; then
    echo ""
    echo "Configuration file not found!"
    echo "Copying config.example.json to config.json"
    cp "$INSTALL_DIR/config.example.json" "$INSTALL_DIR/config.json"
    echo ""
    echo "Please edit config.json with your calendar credentials:"
    echo "  nano $INSTALL_DIR/config.json"
    echo ""
    read -p "Press Enter after you've configured config.json..."
fi

# Install system dependencies
echo ""
echo "Installing system dependencies..."
sudo apt-get update
sudo apt-get install -y python3-pip python3-venv chromium unclutter xdotool

# Create virtual environment if it doesn't exist
if [ ! -d "$INSTALL_DIR/venv" ]; then
    echo ""
    echo "Creating Python virtual environment..."
    python3 -m venv "$INSTALL_DIR/venv"
fi

# Install Python dependencies
echo ""
echo "Installing Python dependencies..."
source "$INSTALL_DIR/venv/bin/activate"
pip install --upgrade pip
pip install -r "$INSTALL_DIR/requirements.txt"
deactivate

# Update systemd service file with correct paths
echo ""
echo "Configuring systemd service..."
SERVICE_FILE="$INSTALL_DIR/family-calendar.service"
sed -i "s|/home/pi/family_calendar|$INSTALL_DIR|g" "$SERVICE_FILE"
sed -i "s|User=pi|User=$USER|g" "$SERVICE_FILE"

# Install systemd service
sudo cp "$SERVICE_FILE" /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable family-calendar.service

# Create autostart directory for Chromium kiosk mode
AUTOSTART_DIR="/home/$USER/.config/lxsession/LXDE-pi"
mkdir -p "$AUTOSTART_DIR"

# Create autostart file for kiosk mode
cat > "$AUTOSTART_DIR/autostart" << EOF
@lxpanel --profile LXDE-pi
@pcmanfm --desktop --profile LXDE-pi
@xscreensaver -no-splash
@xset s off
@xset -dpms
@xset s noblank
@unclutter -idle 0.1 -root
@chromium --noerrdialogs --disable-infobars --kiosk http://localhost:5000 --check-for-update-interval=31536000
EOF

echo ""
echo "=================================="
echo "Installation Complete!"
echo "=================================="
echo ""
echo "The calendar display will start automatically on boot."
echo ""
echo "To start the service now:"
echo "  sudo systemctl start family-calendar.service"
echo ""
echo "To check the status:"
echo "  sudo systemctl status family-calendar.service"
echo ""
echo "To view logs:"
echo "  sudo journalctl -u family-calendar.service -f"
echo ""
echo "To manually test the application:"
echo "  source $INSTALL_DIR/venv/bin/activate"
echo "  python3 $INSTALL_DIR/calendar_display.py"
echo ""
echo "After reboot, the calendar will display in fullscreen kiosk mode."
echo ""
read -p "Would you like to start the service now? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    sudo systemctl start family-calendar.service
    echo "Service started! Check http://localhost:5000 in a browser."
fi
