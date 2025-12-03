#!/bin/bash

# ═══════════════════════════════════════════════════════════════════
#  _____ _    _  ___  _____ _______ _____ _____ _____ _   _          _ 
# / ____| |  | |/ _ \/ ____|__   __/ ____|_   _/ ____| \ | |   /\   | |
#| |  __| |__| | | | | (___    | | | (___   | || |  __|  \| |  /  \  | |
#| | |_ |  __  | | | |\___ \   | |  \___ \  | || | |_ | . ` | / /\ \ | |
#| |__| | |  | | |_| |____) |  | |  ____) |_| || |__| | |\  |/ ____ \| |
# \_____|_|  |_|\___/|_____/   |_| |_____/|_____\_____|_| \_/_/    \_\_|
#
#                       .-''-.
#                     .'  o o '.
#                    (     <    )
#                     '.  ___.'
#                     .-'"""'-.
#                    /         \
#                   '  ~  ~  ~  '
#                      [_____]
#
# REMnux Network Configuration Script
# Configures the VM for 10.99.99.0/24 internal network
# 
# Created by: gh0stsignal
# Purpose: Isolated malware analysis lab setup
# Run with: sudo ./setup_remnux_network.sh
# ═══════════════════════════════════════════════════════════════════

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration variables
NETWORK_INTERFACE=""
IP_ADDRESS="10.99.99.10"
WINDOWS_VM_IP="10.99.99.20"
SUBNET_MASK="24"
NETPLAN_FILE="/etc/netplan/01-netcfg.yaml"

echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}REMnux Network Setup Script${NC}"
echo -e "${GREEN}================================${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Error: This script must be run as root (use sudo)${NC}"
    exit 1
fi

# Step 1: Detect network interface
echo -e "${YELLOW}[1/5] Detecting network interface...${NC}"
NETWORK_INTERFACE=$(ip link show | grep -E '^[0-9]+: (en|eth)' | grep -v 'lo' | head -n 1 | awk '{print $2}' | sed 's/://')

if [ -z "$NETWORK_INTERFACE" ]; then
    echo -e "${RED}Error: Could not detect network interface${NC}"
    echo "Please check your network adapter in VirtualBox settings"
    exit 1
fi

echo -e "${GREEN}✓ Detected interface: $NETWORK_INTERFACE${NC}"
echo ""

# Step 2: Bring up the interface
echo -e "${YELLOW}[2/5] Bringing up network interface...${NC}"
ip link set "$NETWORK_INTERFACE" up
echo -e "${GREEN}✓ Interface is up${NC}"
echo ""

# Step 3: Configure NetworkManager to manage the device
echo -e "${YELLOW}[3/5] Configuring NetworkManager...${NC}"

# Create configuration to allow NetworkManager to manage ethernet devices
cat > /etc/NetworkManager/conf.d/10-globally-managed-devices.conf << EOF
[keyfile]
unmanaged-devices=none
EOF

echo -e "${GREEN}✓ NetworkManager configured${NC}"
echo ""

# Step 4: Configure Netplan
echo -e "${YELLOW}[4/5] Configuring Netplan...${NC}"

# Backup existing netplan config if it exists
if [ -f "$NETPLAN_FILE" ]; then
    cp "$NETPLAN_FILE" "${NETPLAN_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
    echo -e "${GREEN}✓ Backed up existing netplan config${NC}"
fi

# Create new netplan configuration
cat > "$NETPLAN_FILE" << EOF
network:
  version: 2
  renderer: NetworkManager
  ethernets:
    $NETWORK_INTERFACE:
      dhcp4: no
      addresses:
        - $IP_ADDRESS/$SUBNET_MASK
EOF

echo -e "${GREEN}✓ Netplan configured with IP: $IP_ADDRESS/$SUBNET_MASK${NC}"
echo ""

# Step 5: Apply configuration
echo -e "${YELLOW}[5/5] Applying network configuration...${NC}"

# Restart NetworkManager
systemctl restart NetworkManager
sleep 2

# Apply netplan
netplan apply
sleep 2

echo -e "${GREEN}✓ Configuration applied${NC}"
echo ""

# Verify configuration
echo -e "${YELLOW}Verifying configuration...${NC}"
echo ""
ip addr show "$NETWORK_INTERFACE" | grep "inet "
echo ""

# Test connectivity hint
echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}Setup Complete!${NC}"
echo -e "${GREEN}================================${NC}"
echo ""
echo -e "Network Interface: ${GREEN}$NETWORK_INTERFACE${NC}"
echo -e "IP Address: ${GREEN}$IP_ADDRESS/$SUBNET_MASK${NC}"
echo -e "Network: ${GREEN}10.99.99.0/24${NC}"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "1. Configure your Windows VM with IP: 10.99.99.20/24"
echo "2. Test connectivity: ping 10.99.99.20"
echo ""
echo -e "${YELLOW}Troubleshooting:${NC}"
echo "• View network status: ip addr show"
echo "• Check NetworkManager: nmcli device status"
echo "• View connections: nmcli connection show"
echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
echo -e "                   .-'''-."
echo -e "                 .'  o o  '."
echo -e "                (     <     )"
echo -e "                 '.  ___  .'"
echo -e "                 .-'\"\"\"'-."
echo -e "                /         \\"
echo -e "               '  ~  ~  ~  '"
echo -e "                  [_____]"
echo ""
echo -e "           ${GREEN}GH0STSIGNAL NETWORKS${NC}"
echo -e "        Secure Labs • Cyber Range"
echo -e "     ${YELLOW}\"Hunt threats in isolation\"${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
echo ""
