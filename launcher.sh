#!/bin/bash

# Launcher script for Family Calendar
# Handles Standard vs Debug mode

INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODE_FILE="$INSTALL_DIR/display_mode.conf"
LOG_FILE="/var/log/family-calendar.log"

# Default to standard if config missing
MODE="standard"
if [ -f "$MODE_FILE" ]; then
    MODE=$(cat "$MODE_FILE" | tr -d '[:space:]')
fi

# Ensure log file exists and is writable
if [ ! -f "$LOG_FILE" ]; then
    sudo touch "$LOG_FILE"
    sudo chown $USER:$USER "$LOG_FILE"
fi

if [ "$MODE" = "debug" ]; then
    # DEBUG MODE
    # 1. Launch xterm showing the logs
    # 2. Launch Chromium in a window (not kiosk) so we can see both
    
    # Start the service if not running (though systemd should handle it)
    # We assume systemd is enabled. If not, we could start it here.
    
    # Launch terminal with logs
    xterm -geometry 120x20+0+0 -fa 'Monospace' -fs 10 -title "Family Calendar Logs" -e "tail -f $LOG_FILE" &
    
    # Wait a bit for X to settle
    sleep 2
    
    # Launch Chromium (allow windowed mode for debugging)
    chromium-browser --window-position=0,300 --window-size=1024,768 http://localhost:5000 &
    
else
    # STANDARD MODE
    # 1. Hide cursor
    # 2. Show loading screen
    # 3. App will redirect when ready
    
    # Hide mouse cursor
    unclutter -idle 0.1 -root &
    
    # Launch Chromium in Kiosk mode pointing to loading page
    # We use file:// protocol for loading page so it works even if Flask isn't up yet
    LOADING_PAGE="file://$INSTALL_DIR/templates/loading.html"
    
    chromium-browser --noerrdialogs --disable-infobars --kiosk "$LOADING_PAGE" --check-for-update-interval=31536000 &
fi
