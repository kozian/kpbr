#!/bin/sh

# Удалить созданные файлы
rm -f /etc/nftables.d/sets.nft
rm -f /etc/nftables.d/rules.nft
rm -f /etc/dnsmasq.d/nftset.conf
rm -f /etc/firewall.user
rm -f /etc/hotplug.d/iface/25-firewall-user

# Удалить правила из rt_tables
sed -i '/vpnroute/d' /etc/iproute2/rt_tables
sed -i '/wanroute/d' /etc/iproute2/rt_tables

# Удалить правила маршрутизации
ip rule del fwmark 0x1 lookup vpnroute
ip rule del fwmark 0x2 lookup wanroute

# Перезапустить сервисы
/etc/init.d/firewall restart
/etc/init.d/dnsmasq restart