# Family Calendar Display for Raspberry Pi

A 24/7 family calendar display that syncs with Samsung Calendar and displays events on a monitor via HDMI. Perfect for Raspberry Pi Zero 2 W.

## Features

- Syncs with Samsung Calendar via CalDAV
- Beautiful, responsive web interface
- Automatic refresh to stay in sync
- Full-screen kiosk mode on HDMI display
- Runs 24/7 with systemd service
- Shows events for the next 14 days (configurable)
- Grouped by day with color-coded event cards
- Shows event times, locations, and descriptions
- Supports all-day events and recurring events

## Requirements

### Hardware
- Raspberry Pi Zero 2 W (or any Raspberry Pi)
- MicroSD card (8GB or larger)
- HDMI display
- Power supply

### Software
- Raspberry Pi OS (Bullseye or newer)
- Python 3.7+
- Internet connection

## Installation

### 1. Get Samsung Calendar CalDAV Credentials

Samsung Calendar uses CalDAV for syncing. You'll need:

1. Your Samsung account email
2. Your Samsung account password
3. CalDAV URL: `https://caldav.calendar.samsung.com`

**Note**: For security, consider creating an app-specific password if Samsung offers this option.

### 2. Clone or Download This Project

On your Raspberry Pi:

```bash
cd ~
git clone <your-repo-url> family_calendar
# OR download and extract the files manually
cd family_calendar
```

### 3. Configure Calendar Settings

```bash
cp config.example.json config.json
nano config.json
```

Edit the configuration:

```json
{
  "caldav_url": "https://caldav.calendar.samsung.com",
  "username": "your_samsung_email@example.com",
  "password": "your_samsung_password",
  "calendar_name": "Family",
  "timezone": "America/New_York",
  "refresh_interval": 300,
  "days_to_display": 14,
  "port": 5000,
  "debug": false
}
```

**Configuration Options**:
- `caldav_url`: Samsung's CalDAV server URL
- `username`: Your Samsung account email
- `password`: Your Samsung account password
- `calendar_name`: Name of the calendar to display (leave as "Family" or change to match your calendar)
- `timezone`: Your local timezone (e.g., "America/New_York", "Europe/London", "America/Los_Angeles")
- `refresh_interval`: How often to sync with Samsung Calendar (in seconds)
- `days_to_display`: Number of days ahead to show events
- `port`: Port for the web server (default: 5000)
- `debug`: Enable debug mode (set to false for production)

### 4. Run the Installation Script

```bash
chmod +x install.sh
./install.sh
```

The script will:
- Install system dependencies
- Create a Python virtual environment
- Install Python packages
- Configure the systemd service for auto-start
- Set up Chromium in kiosk mode for fullscreen display

### 5. Reboot

```bash
sudo reboot
```

After rebooting, the calendar will automatically display in fullscreen on your HDMI monitor.

## Manual Testing

To test the calendar before installing as a service:

```bash
source venv/bin/activate
python3 calendar_display.py
```

Then open a browser and go to: `http://localhost:5000`

## Service Management

### Check Status
```bash
sudo systemctl status family-calendar.service
```

### Start Service
```bash
sudo systemctl start family-calendar.service
```

### Stop Service
```bash
sudo systemctl stop family-calendar.service
```

### View Logs
```bash
sudo journalctl -u family-calendar.service -f
```

### Restart Service
```bash
sudo systemctl restart family-calendar.service
```

## Troubleshooting

### Calendar Not Loading

1. Check if the service is running:
   ```bash
   sudo systemctl status family-calendar.service
   ```

2. View the logs for errors:
   ```bash
   sudo journalctl -u family-calendar.service -n 50
   ```

3. Verify your config.json credentials are correct

4. Test CalDAV connection manually:
   ```bash
   source venv/bin/activate
   python3 -c "import caldav; client = caldav.DAVClient(url='https://caldav.calendar.samsung.com', username='YOUR_EMAIL', password='YOUR_PASSWORD'); print(client.principal().calendars())"
   ```

### Display Not Showing in Fullscreen

1. Check if Chromium autostart is configured:
   ```bash
   cat ~/.config/lxsession/LXDE-pi/autostart
   ```

2. Manually start Chromium in kiosk mode:
   ```bash
   chromium-browser --kiosk http://localhost:5000
   ```

### Screen Goes Blank

The installation script disables screen blanking, but you can double-check:

```bash
xset s off
xset -dpms
xset s noblank
```

Add these to your autostart file if needed.

### Wrong Timezone

Edit config.json and change the timezone:

```bash
nano config.json
```

Find timezone names here: https://en.wikipedia.org/wiki/List_of_tz_database_time_zones

Then restart the service:
```bash
sudo systemctl restart family-calendar.service
```

## Customization

### Change Refresh Interval

Edit `config.json` and modify `refresh_interval` (in seconds):

```json
"refresh_interval": 600
```

### Display More/Fewer Days

Edit `config.json` and modify `days_to_display`:

```json
"days_to_display": 30
```

### Customize Colors and Styling

Edit `templates/calendar.html` and modify the CSS in the `<style>` section.

### Change Display Resolution

Edit `/boot/config.txt` on your Raspberry Pi:

```bash
sudo nano /boot/config.txt
```

Add or modify:
```
hdmi_group=2
hdmi_mode=82  # 1920x1080 60Hz
```

Other common modes:
- 16: 1024x768 60Hz
- 35: 1280x1024 60Hz
- 82: 1920x1080 60Hz

## Network Access

By default, the calendar is accessible from other devices on your network at:

```
http://YOUR_PI_IP_ADDRESS:5000
```

Find your Pi's IP address:
```bash
hostname -I
```

## Security Notes

- Your Samsung account password is stored in plain text in `config.json`
- Ensure file permissions are restrictive: `chmod 600 config.json`
- Consider using an app-specific password if available
- The calendar is accessible on your local network by default
- For internet access, use a reverse proxy with HTTPS (not covered here)

## Updating

To update the calendar display:

```bash
cd ~/family_calendar
git pull  # If using git
sudo systemctl restart family-calendar.service
```

## Uninstalling

```bash
sudo systemctl stop family-calendar.service
sudo systemctl disable family-calendar.service
sudo rm /etc/systemd/system/family-calendar.service
sudo systemctl daemon-reload
rm -rf ~/family_calendar
```

Remove autostart configuration:
```bash
rm ~/.config/lxsession/LXDE-pi/autostart
```

## License

This project is provided as-is for personal use.

## Support

For issues or questions, please check:
1. The troubleshooting section above
2. System logs: `sudo journalctl -u family-calendar.service -f`
3. Samsung Calendar CalDAV documentation

## Credits

Built with:
- Flask (web framework)
- CalDAV (calendar protocol)
- Python iCalendar library
# Samsung_Family_Calander
