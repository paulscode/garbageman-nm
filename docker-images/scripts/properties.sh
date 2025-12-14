#!/bin/sh
# ==============================================================================
# Properties Display Script - Umbrel Integration
# ==============================================================================
# Displays app information in Umbrel UI properties panel
# Called by Umbrel to show key information to users
#
# Output format: YAML (version 1 properties schema)
# Fields: WebUI Password, URLs, API endpoints

set -e

# Read password from persistent file
PASSWORD_FILE="/data/webui-password.txt"

if [ -f "$PASSWORD_FILE" ]; then
    WEBUI_PASSWORD=$(cat "$PASSWORD_FILE")
else
    WEBUI_PASSWORD="Not generated yet (check logs or restart container)"
fi

# Get port configuration from environment
UI_PORT="${UI_PORT:-5173}"
API_PORT="${API_PORT:-8080}"
SUPERVISOR_PORT="${SUPERVISOR_PORT:-9000}"

# Output properties in YAML format for Umbrel UI
cat <<EOF
version: 1
data:
  WebUI Password:
    type: string
    value: "$WEBUI_PASSWORD"
    description: Use this password to access the WebUI
    copyable: true
    qr: false
    masked: true
  
  WebUI URL:
    type: string
    value: "http://umbrel.local:$UI_PORT"
    description: Access the Garbageman management interface
    copyable: true
    qr: true
    masked: false
  
  API Endpoint:
    type: string
    value: "http://umbrel.local:$API_PORT"
    description: Direct API access (requires authentication)
    copyable: true
    qr: false
    masked: false
  
  Supervisor API:
    type: string
    value: "http://umbrel.local:$SUPERVISOR_PORT"
    description: Multi-daemon supervisor control interface
    copyable: true
    qr: false
    masked: false
  
  Default Password Warning:
    type: string
    value: "⚠️ Change default password on first login"
    description: For security, you must change the default 'garbageman' password
    copyable: false
    qr: false
    masked: false
EOF
