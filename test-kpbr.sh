#!/bin/sh
set +x 
# Проверка nftsets
nft list set inet fw4 vpn_domain_set
nft list set inet fw4 wan_domain_set

# Проверка правил маршрутизации
ip rule show

# Проверка таблиц маршрутизации
ip route show table vpnroute
ip route show table wanroute

# Проверка конфигурации dnsmasq
dnsmasq --test
dnsmasq --test --conf-file=/etc/dnsmasq.d/nftset.conf
set -x