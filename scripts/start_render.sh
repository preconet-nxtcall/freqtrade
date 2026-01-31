#!/bin/bash

# Render Deployment Startup Script

# Ensure user_data directory exists
mkdir -p /freqtrade/user_data

# Destination config path
CONFIG_FILE="/freqtrade/user_data/config.json"
SOURCE_CONFIG="/freqtrade/config.json"

echo "Checking for config file at $CONFIG_FILE..."

# If config file doesn't exist in the persistent volume, copy the default one
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Config file not found in persistent storage. Copying from source..."
    if [ -f "$SOURCE_CONFIG" ]; then
        cp "$SOURCE_CONFIG" "$CONFIG_FILE"
        echo "Config file copied."
    else
        echo "ERROR: Source config file not found at $SOURCE_CONFIG. Cannot proceed."
        exit 1
    fi
else
    echo "Config file found in persistent storage."
fi

echo "Updating configuration for Render environment..."

# Use Python to update the JSON config as jq might not be available
# user and pass are passed via env vars or defaults are used
export USERNAME="${WEB_USERNAME:-freqtrader}"
export PASSWORD="${WEB_PASSWORD:-supersecretpassword}"

python3 -c "
import json
import os

config_path = '$CONFIG_FILE'
username = os.environ.get('USERNAME')
password = os.environ.get('PASSWORD')

try:
    with open(config_path, 'r') as f:
        config = json.load(f)

    # Ensure api_server dict exists
    if 'api_server' not in config:
        config['api_server'] = {}

    config['api_server']['enabled'] = True
    config['api_server']['listen_ip_address'] = '0.0.0.0'
    config['api_server']['listen_port'] = 8080
    config['api_server']['username'] = username
    config['api_server']['password'] = password
    
    # Optional: Enable dry_run for safety if not explicitly set? 
    # Better to leave it as is in the file to respect user choice, 
    # but the API enablement is critical for Render.

    with open(config_path, 'w') as f:
        json.dump(config, f, indent=4)
    
    print('Configuration successfully updated via Python.')

except Exception as e:
    print(f'Error updating config: {e}')
    exit(1)
"

# Start Freqtrade
echo "Starting Freqtrade..."
exec freqtrade trade --config "$CONFIG_FILE" --db-url sqlite:////freqtrade/user_data/tradesv3.sqlite
