#!/bin/sh
#set -x 

# nftsets 
echo "-- nft nftsets --"
nft list set inet fw4 vpn_domain_set
nft list set inet fw4 wan_domain_set
echo
echo "-- nft mangle --"
nft list chain inet fw4 mangle_prerouting
echo

# Проверка правил маршрутизации
echo "-- ip rules --"
ip rule show
echo

# Проверка таблиц маршрутизации
echo "-- vpnroute table --"
ip route show table vpnroute
echo

echo "-- wanroute table --"
ip route show table wanroute
echo

# Проверка конфигурации dnsmasq
echo "-- dnsmasq --test --"
dnsmasq --test
echo
echo "-- dnsmasq --test for nftset.conf --"
dnsmasq --test --conf-file=/etc/dnsmasq.d/nftset.conf

#set +x