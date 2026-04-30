#!/bin/sh
IPT=/sbin/ip6tables

# FLUSH IT ALL
$IPT -F

# LOCAL SPOT
$IPT -A INPUT -i lo -j ACCEPT
$IPT -A OUTPUT -o lo -j ACCEPT

# Allow outbound DNS
#$IPT -A OUTPUT -p udp --dport 53 -j ACCEPT
#$IPT -A INPUT  -p udp --sport 53 -j ACCEPT

# Allow inbound HTTP (apt-get, wget etc.)
#$IPT -A INPUT -p tcp --sport 80 -j ACCEPT

# ICMP
$IPT -A INPUT -p icmpv6 -j REJECT
$IPT -A OUTPUT -p icmpv6 -j ACCEPT

# Drop everything else
$IPT -A INPUT -j REJECT --reject-with icmp6-adm-prohibited
