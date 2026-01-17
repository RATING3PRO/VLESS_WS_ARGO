#!/bin/sh

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_link() {
    echo -e "${CYAN}$1${NC}"
}

# Check for required variables
if [ -z "$UUID" ]; then
    log_warn "UUID not provided, generating a random one..."
    UUID=$(cat /proc/sys/kernel/random/uuid)
    log_info "Generated UUID: $UUID"
fi

if [ -z "$ARGO_TOKEN" ]; then
    log_error "ARGO_TOKEN is missing! Please provide your Cloudflare Tunnel Token."
    exit 1
fi

WSPATH="/$UUID?ed=2048"
PORT=8080

log_info "---------------------------------------------------"
log_info "Starting VLESS-WS-ARGO Node"
log_info "UUID: $UUID"
log_info "WSPATH: $WSPATH"
if [ -n "$PUBLIC_HOSTNAME" ]; then
    log_info "PUBLIC_HOSTNAME: $PUBLIC_HOSTNAME"
fi
log_info "---------------------------------------------------"

# Generate sing-box configuration
cat > config.json <<EOF
{
  "log": {
    "level": "info",
    "timestamp": true
  },
  "inbounds": [
    {
      "type": "vless",
      "tag": "vless-in",
      "listen": "127.0.0.1",
      "listen_port": $PORT,
      "users": [
        {
          "uuid": "$UUID",
          "flow": ""
        }
      ],
      "transport": {
        "type": "ws",
        "path": "$WSPATH",
        "early_data_header_name": "Sec-WebSocket-Protocol"
      }
    }
  ],
  "outbounds": [
    {
      "type": "direct",
      "tag": "direct"
    }
  ]
}
EOF

log_info "Sing-box configuration generated."

# Output VLESS Links if PUBLIC_HOSTNAME is set
if [ -n "$PUBLIC_HOSTNAME" ]; then
    echo ""
    log_info "---------------------------------------------------"
    log_info "VLESS Share Links (Import to v2rayN / sing-box / Clash)"
    log_info "---------------------------------------------------"

    # Define best domains
    DOMAINS="cf.254301.xyz isp.254301.xyz www.visa.cn adventure-x.org www.hltv.org"
    
    for DOMAIN in $DOMAINS; do
        # Construct link: vless://uuid@host:443?encryption=none&security=tls&sni=sni&type=ws&host=host&path=path#remark
        # Note: In standard VLESS link, "host" refers to the destination server address (the best domain here).
        # "sni" and "host" (in query) refer to the actual hidden service (PUBLIC_HOSTNAME).
        
        LINK="vless://${UUID}@${DOMAIN}:443?encryption=none&security=tls&sni=${PUBLIC_HOSTNAME}&type=ws&host=${PUBLIC_HOSTNAME}&path=${WSPATH}#${DOMAIN}-Argo"
        
        echo -e "${YELLOW}Server: ${DOMAIN}${NC}"
        log_link "$LINK"
        echo ""
    done
    log_info "---------------------------------------------------"
else
    log_warn "PUBLIC_HOSTNAME not set. Skipping link generation."
    log_warn "Please set PUBLIC_HOSTNAME to your Cloudflare Tunnel domain (e.g. vless.example.com) to see share links."
fi

# Start sing-box in background
log_info "Starting sing-box..."
sing-box run -c config.json &
SINGBOX_PID=$!

# Wait for sing-box to initialize
sleep 2

if ! kill -0 $SINGBOX_PID > /dev/null 2>&1; then
    log_error "sing-box failed to start."
    exit 1
fi

# Start cloudflared
log_info "Starting cloudflared tunnel..."
cloudflared tunnel --no-autoupdate run --token "$ARGO_TOKEN" &
CLOUDFLARED_PID=$!

# Trap signals to kill both processes
trap "kill $SINGBOX_PID $CLOUDFLARED_PID; exit" SIGINT SIGTERM

# Wait for any process to exit
wait -n $SINGBOX_PID $CLOUDFLARED_PID

# Exit with the status of the process that exited first
exit $?
