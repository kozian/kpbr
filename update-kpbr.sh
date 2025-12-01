#!/bin/sh

###############################################################################
# kPBR (kozian Policy Based Routing) Update Script for OpenWrt
# Version: 1.0
# Description: Automated update script with validation and rollback support
###############################################################################

set -e  # Exit on error

# Configuration
REPO_URL="https://raw.githubusercontent.com/kozian/kpbr/refs/heads/main/"
NFTSET_FILE="nftset.conf"
CIDR_FILE="vpn-cidrs.lst"
NFTSET_TARGET="/etc/dnsmasq.d/nftset.conf"
CIDR_TARGET="/etc/nftables.d/vpn-cidrs.lst"
LOG_FILE="/var/log/kpbr-update.log"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Backup file names
NFTSET_BACKUP="${NFTSET_TARGET}_${TIMESTAMP}.bak"
CIDR_BACKUP="${CIDR_TARGET}_${TIMESTAMP}.bak"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

###############################################################################
# Helper Functions
###############################################################################

log_to_file() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

log_info() {
    local msg="[INFO] $1"
    echo -e "${GREEN}${msg}${NC}"
    log_to_file "$msg"
}

log_error() {
    local msg="[ERROR] $1"
    echo -e "${RED}${msg}${NC}"
    log_to_file "$msg"
}

log_warning() {
    local msg="[WARNING] $1"
    echo -e "${YELLOW}${msg}${NC}"
    log_to_file "$msg"
}

###############################################################################
# Pre-flight checks
###############################################################################

preflight_checks() {
    #log_info "Starting pre-flight checks..."

    # Check if running as root
    if [ "$(id -u)" -ne 0 ]; then
        log_error "This script must be run as root"
        exit 1
    fi

    # Check if kPBR is installed
    if [ ! -f "$NFTSET_TARGET" ] || [ ! -f "$CIDR_TARGET" ]; then
        log_error "kPBR does not appear to be installed. Please run install-kpbr.sh first"
        exit 1
    fi

    # Create log file if it doesn't exist
    touch "$LOG_FILE"

    #log_info "Pre-flight checks passed"
}

###############################################################################
# Download new versions
###############################################################################

download_files() {
    #log_info "Downloading new versions from repository..."

    # Download nftset.conf
    log_info "Downloading ${REPO_URL}/${NFTSET_FILE}"
    if ! wget -q -O "/tmp/${NFTSET_FILE}.new" "${REPO_URL}/${NFTSET_FILE}"; then
        log_error "Failed to download ${NFTSET_FILE}"
        return 1
    fi

    # Download vpn-cidrs.lst
    log_info "Downloading ${REPO_URL}/${CIDR_FILE}"
    if ! wget -q -O "/tmp/${CIDR_FILE}.new" "${REPO_URL}/${CIDR_FILE}"; then
        log_error "Failed to download ${CIDR_FILE}"
        rm -f "/tmp/${NFTSET_FILE}.new"
        return 1
    fi

    log_info "Files downloaded successfully"
    return 0
}

###############################################################################
# Validate versions are different
###############################################################################

check_differences() {
    #log_info "Checking for differences..."

    local has_changes=0

    # Compare nftset.conf
    if ! cmp -s "$NFTSET_TARGET" "/tmp/${NFTSET_FILE}.new"; then
        log_info "Changes detected in ${NFTSET_FILE}"
        has_changes=1
    else
        log_info "No changes in ${NFTSET_FILE}"
    fi

    # Compare vpn-cidrs.lst
    if ! cmp -s "$CIDR_TARGET" "/tmp/${CIDR_FILE}.new"; then
        log_info "Changes detected in ${CIDR_FILE}"
        has_changes=1
    else
        log_info "No changes in ${CIDR_FILE}"
    fi

    if [ $has_changes -eq 0 ]; then
        log_info "All files are up to date."
        cleanup_temp_files
        exit 0
    fi

    return 0
}

###############################################################################
# Create backups
###############################################################################

create_backups() {
    #log_info "Creating backups..."

    # Backup nftset.conf
    if ! cp "$NFTSET_TARGET" "$NFTSET_BACKUP"; then
        log_error "Failed to backup ${NFTSET_FILE}"
        return 1
    fi
    log_info "Backed up to ${NFTSET_BACKUP}"

    # Backup vpn-cidrs.lst
    if ! cp "$CIDR_TARGET" "$CIDR_BACKUP"; then
        log_error "Failed to backup ${CIDR_FILE}"
        return 1
    fi
    log_info "Backed up to ${CIDR_BACKUP}"

    # Keep only last 5 backups for each file
    cleanup_old_backups

    return 0
}

###############################################################################
# Cleanup old backups
###############################################################################

cleanup_old_backups() {
    log_info "Cleaning old backups (keeping last 5 for each file)..."

    # Cleanup old nftset.conf backups
    ls -t "${NFTSET_TARGET}_"*.bak 2>/dev/null | tail -n +6 | while read old_backup; do
        rm -f "$old_backup"
        log_info "Removed old backup: ${old_backup}"
    done

    # Cleanup old vpn-cidrs.lst backups
    ls -t "${CIDR_TARGET}_"*.bak 2>/dev/null | tail -n +6 | while read old_backup; do
        rm -f "$old_backup"
        log_info "Removed old backup: ${old_backup}"
    done
}

###############################################################################
# Update files
###############################################################################

update_files() {
    log_info "Updating configuration files..."

    # Update nftset.conf
    if ! cp "/tmp/${NFTSET_FILE}.new" "$NFTSET_TARGET"; then
        log_error "Failed to update ${NFTSET_FILE}"
        return 1
    fi
    log_info "Updated ${NFTSET_TARGET}"

    # Update vpn-cidrs.lst
    if ! cp "/tmp/${CIDR_FILE}.new" "$CIDR_TARGET"; then
        log_error "Failed to update ${CIDR_FILE}"
        return 1
    fi
    log_info "Updated ${CIDR_TARGET}"

    return 0
}

###############################################################################
# Validate installation
###############################################################################

validate_installation() {
    log_info "Validating installation..."

    # Test dnsmasq configuration
    log_info "Testing dnsmasq configuration..."
    if ! dnsmasq --test 2>&1 | tee -a "$LOG_FILE"; then
        log_error "dnsmasq configuration test failed"
        return 1
    fi
    log_info "dnsmasq configuration is valid"

    # Restart dnsmasq
    log_info "Restarting dnsmasq..."
    if ! /etc/init.d/dnsmasq restart 2>&1 | tee -a "$LOG_FILE"; then
        log_error "Failed to restart dnsmasq"
        return 1
    fi
    log_info "dnsmasq restarted successfully"

    # Test firewall.user script
    log_info "Testing firewall.user script..."
    if [ ! -f /etc/firewall.user ]; then
        log_error "/etc/firewall.user does not exist"
        return 1
    fi

    if [ ! -x /etc/firewall.user ]; then
        log_error "/etc/firewall.user is not executable"
        return 1
    fi

    # Execute firewall.user
    log_info "Executing firewall.user..."
    if ! /etc/firewall.user 2>&1 | tee -a "$LOG_FILE"; then
        log_error "firewall.user execution failed"
        return 1
    fi
    log_info "firewall.user executed successfully"

    log_info "Validation completed successfully"
    return 0
}

###############################################################################
# Rollback on error
###############################################################################

rollback() {
    log_error "Rolling back to previous version..."

    # Restore nftset.conf
    if [ -f "$NFTSET_BACKUP" ]; then
        cp "$NFTSET_BACKUP" "$NFTSET_TARGET"
        log_info "Restored ${NFTSET_FILE}"
    fi

    # Restore vpn-cidrs.lst
    if [ -f "$CIDR_BACKUP" ]; then
        cp "$CIDR_BACKUP" "$CIDR_TARGET"
        log_info "Restored ${CIDR_FILE}"
    fi

    # Restart services
    log_info "Restarting dnsmasq after rollback..."
    /etc/init.d/dnsmasq restart

    log_info "Executing firewall.user after rollback..."
    /etc/firewall.user

    log_error "Rollback completed. System restored to previous state."
}

###############################################################################
# Cleanup
###############################################################################

cleanup_temp_files() {
    log_info "Cleaning up temporary files..."
    rm -f "/tmp/${NFTSET_FILE}.new"
    rm -f "/tmp/${CIDR_FILE}.new"
}

###############################################################################
# Main Update Flow
###############################################################################

main() {
    echo "kPBR Update Script for OpenWrt"

    # Run pre-flight checks
    if ! preflight_checks; then
        log_error "Pre-flight checks failed"
        exit 1
    fi

    # Download new files
    if ! download_files; then
        log_error "Download failed"
        cleanup_temp_files
        exit 1
    fi

    # Check for differences
    check_differences

    # Create backups
    if ! create_backups; then
        log_error "Backup creation failed"
        cleanup_temp_files
        exit 1
    fi

    # Update files
    if ! update_files; then
        log_error "File update failed"
        rollback
        cleanup_temp_files
        exit 1
    fi

    # Validate installation
    if ! validate_installation; then
        log_error "Validation failed"
        rollback
        cleanup_temp_files
        exit 1
    fi

    # Cleanup
    cleanup_temp_files

    log_info "Update completed successfully!"
    log_info "Log file: ${LOG_FILE}"
}

# Run main function
main
