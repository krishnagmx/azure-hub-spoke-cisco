#!/bin/sh
set -eu
ip addr replace 192.0.2.1/30 dev eth1
ip link set eth1 up
sysctl -w net.ipv4.ip_forward=1
# Host published UDP ports -> WAN container eth0 -> Cisco outside interface.
for p in 500 4500; do
  iptables -t nat -A PREROUTING -i eth0 -p udp --dport "$p" -j DNAT --to-destination 192.0.2.2:"$p"
done
iptables -t nat -A POSTROUTING -s 192.0.2.0/30 -o eth0 -j MASQUERADE
iptables -A FORWARD -i eth0 -o eth1 -p udp -m multiport --dports 500,4500 -j ACCEPT
iptables -A FORWARD -i eth1 -o eth0 -j ACCEPT
iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
