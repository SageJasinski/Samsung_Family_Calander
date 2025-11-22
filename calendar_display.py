#!/usr/bin/env python3
"""
Family Calendar Display for Raspberry Pi
Syncs with Samsung Calendar and displays via HDMI
"""

import json
import os
import signal
import sys
from datetime import datetime, timedelta
from pathlib import Path

import caldav
import pytz
import recurring_ical_events
from flask import Flask, render_template, jsonify
from icalendar import Calendar

app = Flask(__name__)

# Configuration
CONFIG_FILE = Path(__file__).parent / 'config.json'
config = {}


def load_config():
    """Load configuration from config.json"""
    global config
    if not CONFIG_FILE.exists():
        print(f"Error: Configuration file not found at {CONFIG_FILE}")
        print("Please copy config.example.json to config.json and configure it.")
        sys.exit(1)

    with open(CONFIG_FILE, 'r') as f:
        config = json.load(f)

    return config


def connect_to_calendar():
    """Connect to Samsung Calendar via CalDAV"""
    try:
        client = caldav.DAVClient(
            url=config['caldav_url'],
            username=config['username'],
            password=config['password']
        )
        principal = client.principal()
        calendars = principal.calendars()

        if not calendars:
            print("Warning: No calendars found")
            return None

        # Return the first calendar or filter by name if specified
        calendar_name = config.get('calendar_name')
        if calendar_name:
            for cal in calendars:
                if calendar_name.lower() in cal.name.lower():
                    return cal

        return calendars[0]
    except Exception as e:
        print(f"Error connecting to calendar: {e}")
        return None


def get_calendar_info():
    """Get calendar connection information for debugging"""
    try:
        client = caldav.DAVClient(
            url=config['caldav_url'],
            username=config['username'],
            password=config['password']
        )
        principal = client.principal()
        calendars = principal.calendars()

        calendar_list = []
        selected_calendar = None

        for cal in calendars:
            cal_info = {
                'name': cal.name,
                'url': str(cal.url)
            }
            calendar_list.append(cal_info)

            # Check if this is the selected calendar
            calendar_name = config.get('calendar_name')
            if calendar_name and calendar_name.lower() in cal.name.lower():
                selected_calendar = cal_info

        # If no specific calendar selected, use first one
        if not selected_calendar and calendar_list:
            selected_calendar = calendar_list[0]

        return {
            'success': True,
            'connected': True,
            'caldav_url': config['caldav_url'],
            'username': config['username'],
            'configured_calendar_name': config.get('calendar_name', 'Not specified'),
            'available_calendars': calendar_list,
            'selected_calendar': selected_calendar,
            'total_calendars': len(calendar_list),
            'timezone': config.get('timezone', 'UTC'),
            'days_to_display': config.get('days_to_display', 14)
        }
    except Exception as e:
        error_msg = str(e)
        if "NameResolutionError" in error_msg or "Failed to resolve" in error_msg:
            error_msg += " (Check your CalDAV URL in config.json. Samsung Cloud URLs are not supported; use Google Calendar instead.)"
            
        return {
            'success': False,
            'connected': False,
            'error': error_msg,
            'caldav_url': config.get('caldav_url', 'Not configured'),
            'username': config.get('username', 'Not configured'),
            'configured_calendar_name': config.get('calendar_name', 'Not specified')
        }


def get_events(days_ahead=14):
    """Fetch events from the calendar"""
    calendar = connect_to_calendar()
    if not calendar:
        return []

    try:
        # Get timezone
        tz = pytz.timezone(config.get('timezone', 'UTC'))

        # Get events for the specified date range
        start_date = datetime.now(tz).replace(hour=0, minute=0, second=0, microsecond=0)
        end_date = start_date + timedelta(days=days_ahead)

        # Fetch events from CalDAV
        events_fetched = calendar.date_search(
            start=start_date,
            end=end_date,
            expand=True
        )

        events = []
        for event in events_fetched:
            try:
                cal = Calendar.from_ical(event.data)

                # Process each event component
                for component in cal.walk('VEVENT'):
                    # Handle recurring events
                    event_start = component.get('dtstart').dt
                    event_end = component.get('dtend').dt if component.get('dtend') else None

                    # Convert to datetime if date only
                    if not isinstance(event_start, datetime):
                        event_start = datetime.combine(event_start, datetime.min.time())
                        event_start = tz.localize(event_start)

                    if event_end and not isinstance(event_end, datetime):
                        event_end = datetime.combine(event_end, datetime.min.time())
                        event_end = tz.localize(event_end)

                    # Make timezone aware if naive
                    if event_start.tzinfo is None:
                        event_start = tz.localize(event_start)
                    if event_end and event_end.tzinfo is None:
                        event_end = tz.localize(event_end)

                    events.append({
                        'summary': str(component.get('summary', 'Untitled Event')),
                        'start': event_start,
                        'end': event_end,
                        'location': str(component.get('location', '')),
                        'description': str(component.get('description', '')),
                        'all_day': not isinstance(component.get('dtstart').dt, datetime)
                    })
            except Exception as e:
                print(f"Error processing event: {e}")
                continue

        # Sort events by start time
        events.sort(key=lambda x: x['start'])
        return events

    except Exception as e:
        print(f"Error fetching events: {e}")
        return []


def format_event_for_display(event):
    """Format event data for web display"""
    start = event['start']
    end = event['end']

    # Format date and time
    if event['all_day']:
        time_str = 'All Day'
        date_str = start.strftime('%A, %B %d, %Y')
    else:
        time_str = start.strftime('%I:%M %p')
        if end:
            time_str += f" - {end.strftime('%I:%M %p')}"
        date_str = start.strftime('%A, %B %d, %Y')

    return {
        'summary': event['summary'],
        'date_str': date_str,
        'time_str': time_str,
        'location': event['location'],
        'description': event['description'],
        'date': start.strftime('%Y-%m-%d'),
        'day_of_week': start.strftime('%A'),
        'day': start.day,
        'month': start.strftime('%B'),
        'all_day': event['all_day']
    }


@app.route('/')
def index():
    """Main calendar display page"""
    return render_template('calendar.html',
                         refresh_interval=config.get('refresh_interval', 300))


@app.route('/api/events')
def api_events():
    """API endpoint to fetch events"""
    try:
        days_ahead = config.get('days_to_display', 14)
        events = get_events(days_ahead)
        formatted_events = [format_event_for_display(e) for e in events]

        # Group events by date
        events_by_date = {}
        for event in formatted_events:
            date = event['date']
            if date not in events_by_date:
                events_by_date[date] = []
            events_by_date[date].append(event)

        return jsonify({
            'success': True,
            'events': formatted_events,
            'events_by_date': events_by_date,
            'event_count': len(formatted_events),
            'last_updated': datetime.now().strftime('%I:%M %p')
        })
    except Exception as e:
        print(f"Error in API: {e}")
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500


@app.route('/api/status')
def api_status():
    """API endpoint to get calendar connection status"""
    return jsonify(get_calendar_info())


def signal_handler(sig, frame):
    """Handle shutdown signals gracefully"""
    print("\nShutting down calendar display...")
    sys.exit(0)


def main():
    """Main entry point"""
    # Load configuration
    load_config()

    # Set up signal handlers
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)

    # Create templates directory if it doesn't exist
    templates_dir = Path(__file__).parent / 'templates'
    templates_dir.mkdir(exist_ok=True)

    # Start Flask app
    print("Starting Family Calendar Display...")
    print(f"Access the calendar at http://localhost:{config.get('port', 5000)}")

    app.run(
        host='0.0.0.0',
        port=config.get('port', 5000),
        debug=config.get('debug', False)
    )


if __name__ == '__main__':
    main()
