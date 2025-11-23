#!/bin/bash

# Family Calendar - Lite OS Setup Script
# Installs X Server, Openbox, and configures Kiosk mode

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}==============================================${NC}"
echo -e "${BLUE}   Family Calendar - Lite OS Setup            ${NC}"
echo -e "${BLUE}==============================================${NC}"
echo ""

# Check if running as root (we need sudo, but shouldn't run the whole script as root)
if [ "$EUID" -eq 0 ]; then
  echo -e "${RED}Please do not run as root. Run as standard user (e.g., pi).${NC}"
  exit 1
fi

INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 1. Ask for Mode
echo -e "${GREEN}Select Display Mode:${NC}"
echo "1) Standard (Kiosk mode, clean loading screen)"
echo "2) Debug (Shows terminal logs + browser window)"
read -p "Enter choice [1]: " mode_choice
mode_choice=${mode_choice:-1}

if [ "$mode_choice" = "2" ]; then
    echo "debug" > "$INSTALL_DIR/display_mode.conf"
    echo -e "Mode set to: ${BLUE}Debug${NC}"
else
    echo "standard" > "$INSTALL_DIR/display_mode.conf"
    echo -e "Mode set to: ${BLUE}Standard${NC}"
fi

# 2. Install System Dependencies
echo -e "\n${GREEN}Installing System Dependencies (this may take a while)...${NC}"
sudo apt-get update
sudo apt-get install -y --no-install-recommends \
    xserver-xorg \
    x11-xserver-utils \
    xinit \
    openbox \
    chromium \
    python3-pip \
    python3-venv \
    unclutter \
    xterm

# 3. Python Setup
echo -e "\n${GREEN}Setting up Python Environment...${NC}"
if [ ! -d "$INSTALL_DIR/venv" ]; then
    python3 -m venv "$INSTALL_DIR/venv"
fi

source "$INSTALL_DIR/venv/bin/activate"
pip install --upgrade pip
pip install -r "$INSTALL_DIR/requirements.txt"
deactivate

# 4. Configure Service
echo -e "\n${GREEN}Configuring Systemd Service...${NC}"
SERVICE_FILE="$INSTALL_DIR/family-calendar.service"
# Update paths in service file
sed -i "s|/home/pi/family_calendar|$INSTALL_DIR|g" "$SERVICE_FILE"
sed -i "s|User=pi|User=$USER|g" "$SERVICE_FILE"

# Configure logging to file for debug mode
# We need to modify the service file to redirect output if not already there
if ! grep -q "StandardOutput" "$SERVICE_FILE"; then
    # Add logging config to service file
    sed -i '/\[Service\]/a StandardOutput=append:/var/log/family-calendar.log\nStandardError=append:/var/log/family-calendar.log' "$SERVICE_FILE"
fi

sudo cp "$SERVICE_FILE" /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable family-calendar.service

# Create log file with permissions
sudo touch /var/log/family-calendar.log
sudo chown $USER:$USER /var/log/family-calendar.log

# 5. Configure X / Openbox
echo -e "\n${GREEN}Configuring Display Environment...${NC}"

# Make launcher executable
chmod +x "$INSTALL_DIR/launcher.sh"

# Configure Openbox autostart
mkdir -p "$HOME/.config/openbox"
cat > "$HOME/.config/openbox/autostart" << EOF
# Disable screen blanking
xset s off
xset -dpms
xset s noblank

# Run our launcher
$INSTALL_DIR/launcher.sh
EOF

# Configure .bash_profile to start X on login
if ! grep -q "startx" "$HOME/.bash_profile" 2>/dev/null; then
    echo -e "\n# Start X automatically on login" >> "$HOME/.bash_profile"
    echo '[[ -z $DISPLAY && $XDG_VTNR -eq 1 ]] && startx -- -nocursor' >> "$HOME/.bash_profile"
fi

# 6. Enable Console Autologin
echo -e "\n${GREEN}Enabling Console Autologin...${NC}"
# This is the tricky part. We use raspi-config non-interactive mode if possible,
# or manually edit systemd target.
sudo systemctl set-default multi-user.target
# We can't easily script raspi-config autologin safely without raspi-config tool.
# But usually on Lite, the user is prompted to login.
# Let's try to use raspi-config if available.
if command -v raspi-config >/dev/null; then
    sudo raspi-config nonint do_boot_behaviour B2
else
    echo -e "${RED}Warning: raspi-config not found. You may need to manually enable console autologin.${NC}"
fi

echo -e "\n${BLUE}==============================================${NC}"
echo -e "${BLUE}   Setup Complete!                            ${NC}"
echo -e "${BLUE}==============================================${NC}"
echo ""
echo "1. Edit 'config.json' if you haven't already."
echo "2. Reboot your Pi to start:"
echo "   sudo reboot"
echo ""
