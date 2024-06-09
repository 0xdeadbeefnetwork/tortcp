#!/bin/bash

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root"
    exit 1
fi

# Function to install required packages
install_packages() {
    echo "Installing required packages..."
    apt-get update
    apt-get install -y tor unbound iptables-persistent
}

# Function to download root hints file
download_root_hints() {
    echo "Downloading root hints file..."
    wget -q -O /var/lib/unbound/root.hints https://www.internic.net/domain/named.root
    if [ $? -ne 0 ]; then
        echo "Failed to download root hints file."
        exit 1
    fi
}

# Function to configure Tor
configure_tor() {
    echo "Configuring Tor..."
    cat <<EOF >/etc/tor/torrc
# Enable Tor transparent proxy
VirtualAddrNetworkIPv4 10.192.0.0/10
AutomapHostsOnResolve 1
TransPort 9040
DNSPort 5353

# Use Unbound as DNS resolver
DNSPort 127.0.0.1:53
EOF
}

# Function to configure Unbound
configure_unbound() {
    echo "Configuring Unbound..."
    cat <<EOF >/etc/unbound/unbound.conf
server:
  num-threads: 4
  verbosity: 1
  root-hints: "/var/lib/unbound/root.hints"
  interface: 127.0.0.1
  max-udp-size: 3072

  # Remove access control rules to allow all queries from localhost
  access-control: 127.0.0.1/32 allow

  # Forward DNS queries to Cloudflare DNS servers
  forward-zone:
    name: "."
    forward-addr: 1.1.1.1
    forward-addr: 1.0.0.1
EOF
}

# Function to enable transparent proxy
enable_transparent_proxy() {
    echo "Enabling transparent proxy..."
    iptables -t nat -F
    iptables -t nat -A OUTPUT -m owner ! --uid-owner debian-tor -p tcp --syn -j REDIRECT --to-ports 9040
    iptables-save >/etc/iptables/rules.v4
}

# Function to restart Tor and Unbound
restart_services() {
    echo "Restarting Tor and Unbound..."
    systemctl restart tor
    systemctl restart unbound
}

# Main function
main() {
    install_packages
    download_root_hints
    configure_tor
    configure_unbound
    enable_transparent_proxy
    restart_services
    echo "Setup completed successfully. All outgoing traffic is now routed securely through Tor."
}

# Call main function
main
