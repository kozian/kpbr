#!/bin/sh

###############################################################################
# kPBR (kozian Policy Based Routing) Installation Script for OpenWrt
# Version: 1.1
# Description: Automated setup script for domain-based routing via nftables
###############################################################################

set -e  # Exit on error

# Configuration
REPO_URL="https://raw.githubusercontent.com/kozian/kpbr/refs/heads/main"
NFTSET_PATH="/etc/dnsmasq.d/nftset.conf"
CIDR_PATH="/etc/nftables.d/vpn-cidrs.lst"
DNS_PATH="/etc/dnsmasq.d/dns-servers.conf"
VPN_INTERFACE="amneziawg"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

###############################################################################
# Helper Functions
###############################################################################

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

check_success() {
    if [ $? -ne 0 ]; then
        log_error "$1"
        exit 1
    fi
    log_info "$2"
}

###############################################################################
# Step 0: Pre-flight checks
###############################################################################

preflight_checks() {
    log_info "Starting pre-flight checks..."
    
    # Check if running as root
    if [ "$(id -u)" -ne 0 ]; then
        log_error "This script must be run as root"
        exit 1
    fi
    
    # Check OpenWrt version
    if [ ! -f /etc/openwrt_release ]; then
        log_error "This script is designed for OpenWrt only"
        exit 1
    fi
    
    log_info "Pre-flight checks passed"
}

###############################################################################
# Step 1: Reinstall dnsmasq-full
###############################################################################

install_dnsmasq_full() {
    log_info "Step 1: Reinstalling dnsmasq-full..."

    # Detect package manager: apk (new OpenWrt) or opkg (old OpenWrt)
    if command -v apk >/dev/null 2>&1; then
        PKG_MGR="apk"
    elif command -v opkg >/dev/null 2>&1; then
        PKG_MGR="opkg"
    else
        log_error "No supported package manager found (opkg or apk)"
        exit 1
    fi
    log_info "Detected package manager: $PKG_MGR"

    log_info "Updating package lists..."
    if [ "$PKG_MGR" = "apk" ]; then
        apk update
    else
        opkg update
    fi
    check_success "Failed to update package lists" "Package lists updated"

    log_info "Removing dnsmasq and installing dnsmasq-full..."
    if [ "$PKG_MGR" = "apk" ]; then
        apk del dnsmasq
        apk add dnsmasq-full
    else
        opkg remove dnsmasq
        opkg install dnsmasq-full
    fi
    check_success "Failed to install dnsmasq-full" "dnsmasq-full installed successfully"
}

###############################################################################
# Step 2: Create and configure nftsets
###############################################################################

create_nftsets() {
    log_info "Step 2.1: Creating nftsets..."
    
    # Create nftables sets configuration
    cat << 'EOF' > /etc/nftables.d/sets.nft
set vpn_domain_set {
    type ipv4_addr
    flags interval
}
set wan_domain_set {
    type ipv4_addr
}
EOF
    check_success "Failed to create nftables sets configuration" "nftables sets configuration created"

    # Restart firewall
    log_info "Restarting firewall..."
    /etc/init.d/firewall restart
    check_success "Failed to restart firewall" "Firewall restarted"
    
}

configure_dnsmasq() {
    log_info "Step 2.2: Configuring dnsmasq..."
    
    # Check if confdir option already exists
    if ! grep -q "option confdir" /etc/config/dhcp; then
        log_info "Adding confdir option to /etc/config/dhcp..."
        
        # Add confdir option to dnsmasq section
        sed -i "/config dnsmasq/a\\\toption confdir '/etc/dnsmasq.d'" /etc/config/dhcp
        check_success "Failed to add confdir option" "confdir option added"
    else
        log_info "confdir option already exists in /etc/config/dhcp"
    fi
    
    # Create dnsmasq.d directory
    mkdir -p /etc/dnsmasq.d
    check_success "Failed to create /etc/dnsmasq.d directory" "dnsmasq.d directory created"

    if [ -f "${NFTSET_PATH}" ]; then
        log_info "${NFTSET_PATH} already exists — keeping current version. Run update-kpbr.sh to refresh."
    else
        log_info "Downloading nftset list to ${NFTSET_PATH}..."
        wget -O "${NFTSET_PATH}" "${REPO_URL}${NFTSET_PATH}"
        check_success "Failed to download nftset list" "nftset list downloaded"
    fi

    if [ -f "${DNS_PATH}" ]; then
        log_info "${DNS_PATH} already exists — keeping current version. Run update-kpbr.sh to refresh."
    else
        log_info "Downloading DNS servers config to ${DNS_PATH}..."
        wget -O "${DNS_PATH}" "${REPO_URL}${DNS_PATH}"
        check_success "Failed to download DNS servers config" "DNS servers config downloaded"
    fi
    
    # Test dnsmasq configuration
    log_info "Testing dnsmasq configuration..."
    dnsmasq --test
    check_success "dnsmasq configuration test failed" "dnsmasq configuration is valid"

    log_info "Testing dnsmasq configuration for ${NFTSET_PATH}..."
    dnsmasq --test --conf-file=${NFTSET_PATH}
    check_success "dnsmasq ${NFTSET_PATH} test failed" "dnsmasq ${NFTSET_PATH} is valid"

    log_info "Testing dnsmasq configuration for ${DNS_PATH}..."
    dnsmasq --test --conf-file=${DNS_PATH}
    check_success "dnsmasq ${DNS_PATH} test failed" "dnsmasq ${DNS_PATH} is valid"
    
    # Restart dnsmasq
    log_info "Restarting dnsmasq..."
    /etc/init.d/dnsmasq restart
    check_success "Failed to restart dnsmasq" "dnsmasq restarted successfully"
}

###############################################################################
# Step 3: Configure packet marking
###############################################################################

configure_packet_marking() {
    log_info "Step 3: Configuring packet marking rules..."
    
    cat << 'EOF' > /etc/nftables.d/rules.nft
chain mangle_prerouting {
	type filter hook prerouting priority mangle; policy accept;
	ip daddr @vpn_domain_set meta mark set 0x1
	ip daddr @wan_domain_set meta mark set 0x2
}
EOF
    check_success "Failed to create packet marking rules" "Packet marking rules created"
    
    # Restart firewall to apply rules
    log_info "Restarting firewall to apply marking rules..."
    /etc/init.d/firewall restart
    check_success "Failed to restart firewall" "Firewall restarted with marking rules"
}

###############################################################################
# Step 4: Configure routing tables and rules
###############################################################################

configure_routing_tables() {
    log_info "Step 4.1: Configuring routing tables..."
    
    # Check if entries already exist in rt_tables
    if ! grep -q "vpnroute" /etc/iproute2/rt_tables; then
        echo "100 vpnroute" >> /etc/iproute2/rt_tables
        log_info "Added vpnroute table"
    else
        log_info "vpnroute table already exists"
    fi
    
    if ! grep -q "wanroute" /etc/iproute2/rt_tables; then
        echo "101 wanroute" >> /etc/iproute2/rt_tables
        log_info "Added wanroute table"
    else
        log_info "wanroute table already exists"
    fi
    
    check_success "Failed to configure routing tables" "Routing tables configured"
}

configure_routing_rules() {
    if [ -f "${CIDR_PATH}" ]; then
        log_info "${CIDR_PATH} already exists — keeping current version. Run update-kpbr.sh to refresh."
    else
        log_info "Downloading CIDR list to ${CIDR_PATH}..."
        wget -O "${CIDR_PATH}" "${REPO_URL}${CIDR_PATH}"
        check_success "Failed to download CIDR list" "CIDR list downloaded"
    fi

    log_info "Step 4.2: Configuring routing rules..."

## добавить проверку на пустое значение
    WAN_INTERFACE=$(ubus call network.interface.wan status | jsonfilter -e '@.l3_device')
    
    cat << EOF > /etc/firewall.user
#!/bin/sh
# KPBR routing rules

# Add routing rules (remove old ones)
ip rule del fwmark 0x1 lookup vpnroute 2>/dev/null
ip rule del fwmark 0x2 lookup wanroute 2>/dev/null
ip rule add fwmark 0x1 lookup vpnroute
ip rule add fwmark 0x2 lookup wanroute

# Add routes
WAN_GW=\$(ubus call network.interface.wan status | jsonfilter -e '@.route[@.target="0.0.0.0"].nexthop')

ip route add default dev ${VPN_INTERFACE} table vpnroute
ip route add default via \${WAN_GW} dev ${WAN_INTERFACE} table wanroute

# Add known cidrs
while read ELEMENT; do
    nft add element inet fw4 vpn_domain_set { \${ELEMENT} }
done < /etc/nftables.d/vpn-cidrs.lst
EOF
    
    check_success "Failed to create firewall.user script" "firewall.user script created"
    
    chmod +x /etc/firewall.user
    check_success "Failed to make firewall.user executable" "firewall.user made executable"
    
    # Execute the script
    log_info "Applying routing rules..."
    /etc/firewall.user
    check_success "Failed to apply routing rules" "Routing rules applied"
}

configure_autostart() {
    log_info "Step 4.3: Configuring autostart..."
    
    cat << 'EOF' > /etc/hotplug.d/iface/25-firewall-user
#!/bin/sh
/etc/firewall.user
EOF
    
    check_success "Failed to create hotplug script" "Hotplug script created"
    
    chmod +x /etc/hotplug.d/iface/25-firewall-user
    check_success "Failed to make hotplug script executable" "Hotplug script made executable"
}

###############################################################################
# Main Installation Flow
###############################################################################

main() {
    echo "=========================================="
    echo "KPBR Installation Script for OpenWrt"
    echo "=========================================="
    echo ""
    
    preflight_checks
    install_dnsmasq_full
    create_nftsets
    configure_dnsmasq
    configure_packet_marking
    configure_routing_tables
    configure_routing_rules
    configure_autostart
    
    echo ""
    echo "=========================================="
    log_info "Installation completed successfully!"
    echo "=========================================="
    echo ""
    log_info "Configuration summary:"
    echo "  - VPN Interface: $VPN_INTERFACE"
    echo "  - WAN Interface: $WAN_INTERFACE"
    echo "  - WAN Gateway: $WAN_GATEWAY"
    echo ""
    log_info "You can verify the setup with:"
    echo "  - nft list set inet fw4 vpn_domain_set"
    echo "  - nft list set inet fw4 wan_domain_set"
    echo "  - ip rule show"
    echo "  - ip route show table vpnroute"
    echo "  - ip route show table wanroute"
    echo ""
    echo "test kpbr:    sh <(wget -O - https://raw.githubusercontent.com/kozian/kpbr/refs/heads/main/test-kpbr.sh)"
    echo "update lists: sh <(wget -O - https://raw.githubusercontent.com/kozian/kpbr/refs/heads/main/update-kpbr.sh)"
    echo "uninstall:    sh <(wget -O - https://raw.githubusercontent.com/kozian/kpbr/refs/heads/test/uninstall-kpbr.sh)"
}

# Run main function
main