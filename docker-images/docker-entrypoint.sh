#!/bin/sh
# ==============================================================================
# Garbageman Nodes Manager - Unified Entrypoint
# ==============================================================================
# Unified entrypoint script for all deployment wrappers.
# Auto-detects deployment environment and configures accordingly.
#
# Detection Logic:
# 1. Check WRAPPER_TYPE environment variable (explicit override)
# 2. Check for /root/start9/config.yaml (StartOS marker file)
# 3. Check for APP_DATA_DIR environment variable (Umbrel marker)
# 4. Default to standalone mode
#
# Supported Wrappers:
# - startos:    Start9 Embassy OS (runs as root, reads config.yaml)
# - umbrel:     Umbrel Community App Store (runs as 1000:1000, uses APP_DATA_DIR)
# - standalone: Development/self-hosted (runs as root, auto-generates password)

set -euo pipefail

# ==============================================================================
# Wrapper Detection
# ==============================================================================

detect_wrapper() {
    # Explicit override via environment variable
    if [ -n "${WRAPPER_TYPE:-}" ]; then
        echo "$WRAPPER_TYPE"
        return
    fi
    
    # StartOS: Check for config.yaml marker file
    if [ -f "/root/start9/config.yaml" ]; then
        echo "startos"
        return
    fi
    
    # Umbrel: Check for APP_DATA_DIR environment variable
    if [ -n "${APP_DATA_DIR:-}" ]; then
        echo "umbrel"
        return
    fi
    
    # Default: Standalone mode
    echo "standalone"
}

export WRAPPER_TYPE=$(detect_wrapper)
echo "[i] Detected wrapper: $WRAPPER_TYPE"
echo "[i] Starting Garbageman Nodes Manager..."

# ==============================================================================
# Wrapper-Specific Initialization
# ==============================================================================

case "$WRAPPER_TYPE" in
    startos)
        echo "[i] Initializing for Start9 Embassy OS..."
        
        # Read StartOS configuration
        CONFIG_FILE="/root/start9/config.yaml"
        DEFAULT_API_PORT=8080
        DEFAULT_UI_PORT=3000
        DEFAULT_SUPERVISOR_PORT=9000
        DEFAULT_LOG_LEVEL="info"
        DEFAULT_ADMIN_PASSWORD="changeme"
        DEFAULT_TOR_ENABLED=true
        DEFAULT_MAX_INSTANCES=10
        
        # Parse config with defaults if file doesn't exist yet
        if [ -f "$CONFIG_FILE" ]; then
            echo "[i] Reading configuration from $CONFIG_FILE"
            
            # Use simple grep/sed for parsing YAML (yq not available in minimal Alpine)
            export API_PORT=$(grep -E '^api-port:' "$CONFIG_FILE" | sed 's/api-port: *//' || echo "$DEFAULT_API_PORT")
            export UI_PORT=$(grep -E '^ui-port:' "$CONFIG_FILE" | sed 's/ui-port: *//' || echo "$DEFAULT_UI_PORT")
            export SUPERVISOR_PORT=$(grep -E '^supervisor-port:' "$CONFIG_FILE" | sed 's/supervisor-port: *//' || echo "$DEFAULT_SUPERVISOR_PORT")
            export LOG_LEVEL=$(grep -E '^log-level:' "$CONFIG_FILE" | sed 's/log-level: *//' | tr -d '"' || echo "$DEFAULT_LOG_LEVEL")
            export ADMIN_PASSWORD=$(grep -E '^admin-password:' "$CONFIG_FILE" | sed 's/admin-password: *//' | tr -d '"' || echo "$DEFAULT_ADMIN_PASSWORD")
            export TOR_ENABLED=$(grep -E '^enable-tor-proxy:' "$CONFIG_FILE" | sed 's/enable-tor-proxy: *//' || echo "$DEFAULT_TOR_ENABLED")
            export MAX_INSTANCES=$(grep -E '^max-instances:' "$CONFIG_FILE" | sed 's/max-instances: *//' || echo "$DEFAULT_MAX_INSTANCES")
        else
            echo "[i] Config file not found, using defaults"
            export API_PORT=$DEFAULT_API_PORT
            export UI_PORT=$DEFAULT_UI_PORT
            export SUPERVISOR_PORT=$DEFAULT_SUPERVISOR_PORT
            export LOG_LEVEL=$DEFAULT_LOG_LEVEL
            export ADMIN_PASSWORD=$DEFAULT_ADMIN_PASSWORD
            export TOR_ENABLED=$DEFAULT_TOR_ENABLED
            export MAX_INSTANCES=$DEFAULT_MAX_INSTANCES
        fi
        
        # StartOS data directories (must be under /root)
        export DATA_DIR="/root/data"
        export ENVFILES_DIR="/root/envfiles"
        export ARTIFACTS_DIR="/root/artifacts"
        
        # Create directory structure
        mkdir -p "$DATA_DIR" "$ENVFILES_DIR/instances" "$ARTIFACTS_DIR" /root/start9
        
        # Tor proxy configuration
        export TOR_PROXY_HOST="${TOR_PROXY_HOST:-127.0.0.1}"
        export TOR_PROXY_PORT="${TOR_PROXY_PORT:-9050}"
        
        # Authentication
        export WEBUI_PASSWORD="${ADMIN_PASSWORD}"
        export WRAPPER_UI_PASSWORD="${ADMIN_PASSWORD}"
        
        # Use StartOS supervisord config
        export SUPERVISORD_CONFIG="/etc/supervisord.startos.conf"
        ;;
        
    umbrel)
        echo "[i] Initializing for Umbrel Community App Store..."
        
        # Fix volume permissions (container starts as root, needs to fix mounted volumes)
        echo "[i] Fixing volume permissions for user 1000:1000..."
        chown -R 1000:1000 /data 2>/dev/null || true
        chmod -R 755 /data 2>/dev/null || true
        
        # Create supervisord runtime directories
        mkdir -p /var/log/supervisor /var/run/supervisor
        chown -R 1000:1000 /var/log/supervisor /var/run/supervisor
        chmod -R 755 /var/log/supervisor /var/run/supervisor
        
        # Service ports
        export UI_PORT="${UI_PORT:-5173}"
        export API_PORT="${API_PORT:-8080}"
        export SUPERVISOR_PORT="${SUPERVISOR_PORT:-9000}"
        
        # Data directories
        export DATA_DIR="${DATA_DIR:-/data/bitcoin}"
        export ENVFILES_DIR="${ENVFILES_DIR:-/data/envfiles}"
        export ARTIFACTS_DIR="${ARTIFACTS_DIR:-/data/artifacts}"
        
        # Create directory structure (as root, with correct ownership)
        mkdir -p "$DATA_DIR" "$ENVFILES_DIR/instances" "$ARTIFACTS_DIR" || true
        chown -R 1000:1000 "$DATA_DIR" "$ENVFILES_DIR" "$ARTIFACTS_DIR" 2>/dev/null || true
        chmod -R 755 "$DATA_DIR" "$ENVFILES_DIR" "$ARTIFACTS_DIR" 2>/dev/null || true
        
        # Tor proxy (provided by Umbrel)
        export TOR_PROXY_HOST="${TOR_PROXY_HOST:-127.0.0.1}"
        export TOR_PROXY_PORT="${TOR_PROXY_PORT:-9050}"
        
        # Logging
        export LOG_LEVEL="${LOG_LEVEL:-info}"
        export NODE_ENV="${NODE_ENV:-production}"
        
        # WebUI authentication - generate random password if not provided
        export ADMIN_PASSWORD="${ADMIN_PASSWORD:-}"
        if [ -z "$ADMIN_PASSWORD" ]; then
            # Generate secure random password using Node.js (32 chars, base64url safe)
            ADMIN_PASSWORD=$(node -e "console.log(require('crypto').randomBytes(24).toString('base64url').slice(0,32))")
            
            # Save to persistent file for user access
            PASSWORD_FILE="/data/webui-password.txt"
            echo "$ADMIN_PASSWORD" > "$PASSWORD_FILE"
            chmod 600 "$PASSWORD_FILE"
            chown 1000:1000 "$PASSWORD_FILE"
            
            echo "[i] Generated WebUI password and saved to: $PASSWORD_FILE"
        fi
        export WEBUI_PASSWORD="${ADMIN_PASSWORD}"
        export WRAPPER_UI_PASSWORD="${ADMIN_PASSWORD}"
        
        # Use Umbrel supervisord config
        export SUPERVISORD_CONFIG="/etc/supervisord.umbrel.conf"
        ;;
        
    standalone)
        echo "[i] Initializing for standalone/development mode..."
        
        # Service ports
        export UI_PORT="${UI_PORT:-5173}"
        export API_PORT="${API_PORT:-8080}"
        export SUPERVISOR_PORT="${SUPERVISOR_PORT:-9000}"
        
        # Data directories
        export DATA_DIR="${DATA_DIR:-/data/bitcoin}"
        export ENVFILES_DIR="${ENVFILES_DIR:-/data/envfiles}"
        export ARTIFACTS_DIR="${ARTIFACTS_DIR:-/data/artifacts}"
        
        # Create directory structure
        mkdir -p "$DATA_DIR" "$ENVFILES_DIR/instances" "$ARTIFACTS_DIR"
        
        # Tor proxy
        export TOR_PROXY_HOST="${TOR_PROXY_HOST:-127.0.0.1}"
        export TOR_PROXY_PORT="${TOR_PROXY_PORT:-9050}"
        
        # Logging
        export LOG_LEVEL="${LOG_LEVEL:-info}"
        export NODE_ENV="${NODE_ENV:-production}"
        
        # WebUI authentication - generate random password if not provided
        export ADMIN_PASSWORD="${ADMIN_PASSWORD:-}"
        if [ -z "$ADMIN_PASSWORD" ]; then
            # Generate secure random password
            ADMIN_PASSWORD=$(node -e "console.log(require('crypto').randomBytes(24).toString('base64url').slice(0,32))")
            
            # Save to file for user access
            PASSWORD_FILE="/data/webui-password.txt"
            echo "$ADMIN_PASSWORD" > "$PASSWORD_FILE"
            chmod 600 "$PASSWORD_FILE"
            
            echo "[i] Generated WebUI password and saved to: $PASSWORD_FILE"
            echo "[i] Use 'docker exec <container> cat /data/webui-password.txt' to view"
        fi
        export WEBUI_PASSWORD="${ADMIN_PASSWORD}"
        export WRAPPER_UI_PASSWORD="${ADMIN_PASSWORD}"
        
        # Use standalone supervisord config
        export SUPERVISORD_CONFIG="/etc/supervisord.standalone.conf"
        ;;
        
    *)
        echo "[!] ERROR: Unknown wrapper type: $WRAPPER_TYPE"
        echo "[!] Supported values: startos, umbrel, standalone"
        exit 1
        ;;
esac

# ==============================================================================
# Display Configuration
# ==============================================================================

echo "[i] Configuration:"
echo "    Wrapper:         $WRAPPER_TYPE"
echo "    UI Port:         $UI_PORT"
echo "    API Port:        $API_PORT"
echo "    Supervisor Port: $SUPERVISOR_PORT"
echo "    Data Directory:  $DATA_DIR"
echo "    Tor Proxy:       $TOR_PROXY_HOST:$TOR_PROXY_PORT"
echo "    Log Level:       $LOG_LEVEL"
echo "    Config File:     $SUPERVISORD_CONFIG"

# ==============================================================================
# Start Services via Supervisord
# ==============================================================================

echo "[i] Starting services via supervisord..."

# Run supervisord with wrapper-specific configuration
# Note: StartOS/standalone run as root, Umbrel runs services as user 1000
exec /usr/bin/supervisord -c "$SUPERVISORD_CONFIG" -n
