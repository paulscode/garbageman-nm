#!/bin/sh
# ==============================================================================
# Show WebUI Password - Helper Script
# ==============================================================================
# Quick command to display the WebUI password from persistent storage
# Usage: docker exec <container> show-password
#        or: show-password (from within container)

PASSWORD_FILE="/data/webui-password.txt"

if [ -f "$PASSWORD_FILE" ]; then
    echo "═══════════════════════════════════════════════════════════"
    echo "         Garbageman Nodes Manager - WebUI Password"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    echo "  $(cat $PASSWORD_FILE)"
    echo ""
    echo "═══════════════════════════════════════════════════════════"
    
    # Show appropriate access URL based on wrapper type
    if [ -n "${WRAPPER_TYPE:-}" ]; then
        case "$WRAPPER_TYPE" in
            umbrel)
                echo "  Access WebUI at: http://umbrel.local:${UI_PORT:-5173}"
                ;;
            startos)
                echo "  Access WebUI via Start9 Embassy interface"
                ;;
            standalone)
                echo "  Access WebUI at: http://localhost:${UI_PORT:-5173}"
                ;;
        esac
    else
        echo "  Access WebUI at: http://localhost:${UI_PORT:-5173}"
    fi
    
    echo "═══════════════════════════════════════════════════════════"
else
    echo "Password file not found at: $PASSWORD_FILE"
    echo "Container may still be initializing, or password was provided"
    echo "via environment variable (check docker-compose.yml or config)."
    exit 1
fi
