#!/bin/sh
IPT=/sbin/iptables

### TABULA RASA ### 
echo "[+] Flushing existing rule set..."
$IPT -F
$IPT -F -t nat
$IPT -X
$IPT -P INPUT DROP
$IPT -P OUTPUT DROP
$IPT -P FORWARD DROP

### LO AND BEHOLD ###
$IPT -A INPUT -i lo -j ACCEPT
$IPT -A INPUT ! -i lo -s 127.0.0.0/8 -j REJECT
$IPT -A OUTPUT -o lo -j ACCEPT

### PING ME BABY ###
$IPT -A INPUT -p icmp -m state --state NEW --icmp-type 8 -j ACCEPT
$IPT -A INPUT -p icmp -m state --state ESTABLISHED,RELATED -j ACCEPT
$IPT -A OUTPUT -p icmp -j ACCEPT

### INPUT chain ###
echo "[+] Configuring INPUT chain..."
## state tracking rules
# Log & drop invalid packets
$IPT -A INPUT -m state --state INVALID -j LOG --log-prefix "DROP INVALID " --log-ip-options --log-tcp-options
$IPT -A INPUT -m state --state INVALID -j DROP
# Drop new connections that don't begin with a SYN
$IPT -A INPUT -p tcp ! --syn -m state --state NEW -j DROP
# Drop fragmented packets
$IPT -A INPUT -f -j DROP
# Drop XMAS packets
$IPT -A INPUT -p tcp --tcp-flags ALL ALL -j DROP
# Drop NULL packets
$IPT -A INPUT -p tcp --tcp-flags ALL NONE -j DROP
# Allow established connections
$IPT -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

## ACCEPT rules
#$IPT -A INPUT -i tun+ -j ACCEPT # VPN DEV
#$IPT -A INPUT -p tcp --dports 18080,18089 -j ACCEPT # MONEROD
#$IPT -A INPUT -p udp -m state --state NEW --dport 1194 -j ACCEPT # OPENVPN
#$IPT -A INPUT -p tcp -m state --state NEW --dport 22 -j ACCEPT # OPENSSH
#$IPT -A INPUT -p tcp -m state --state NEW  --dport 3413 -j ACCEPT # GRIN API
#$IPT -A INPUT -p tcp -m state --state NEW  --dport 3414 -j ACCEPT # GRIN P2P
#$IPT -A INPUT -p tcp -m state --state NEW --dport 3415 -j ACCEPT # GRIN HTTP
#$IPT -A INPUT -p tcp -m state --state NEW --dport 51738 -j ACCEPT # PART

## INPUT LOG rule
$IPT -A INPUT ! -i lo -m limit --limit 3/min -j LOG --log-prefix "DROP " --log-ip-options --log-tcp-options

### OUTPUT chain ###
echo "[+] Configuring OUTPUT chain..."
## state tracking rules
$IPT -A OUTPUT -m state --state INVALID -j LOG --log-prefix "DROP INVALID " --log-ip-options --log-tcp-options
$IPT -A OUTPUT -m state --state INVALID -j DROP
$IPT -A OUTPUT -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT

## ACCEPT rules
#$IPT -A OUTPUT -p tcp -m state --state NEW --dport 22 -j ACCEPT
#$IPT -A OUTPUT -p tcp -m state --state NEW --dport 25 -j ACCEPT # POSTFIX
#$IPT -A OUTPUT -p udp -m state --state NEW --dport 53:65535 -j ACCEPT # BIND
#$IPT -A OUTPUT -p tcp -m state --state NEW --dport 80 -j ACCEPT # NGINX
#$IPT -A OUTPUT -p tcp -m state --state NEW --dport 443 -j ACCEPT
#$IPT -A OUTPUT -p tcp -m state --state NEW --dport 1024: -j ACCEPT # WEECHAT
#$IPT -A OUTPUT -p tcp -o tun+ -j ACCEPT # OPENVPN

## OUTPUT LOG rule
#$IPT -A OUTPUT ! -i lo -m limit --limit 3/min -j LOG --log-prefix "DROP " --log-ip-options --log-tcp-options --log-level 4

### FORWARD chain
echo "[+] Configuring FORWARD chain..."
## state tracking rules
$IPT -A FORWARD -m state --state INVALID -j LOG --log-prefix "DROP INVALID " --log-ip-options --log-tcp-options
$IPT -A FORWARD -m state --state INVALID -j DROP
$IPT -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT

## ACCEPT rules
#$IPT -A FORWARD -i tun+ -j ACCEPT
#$IPT -A FORWARD -i tun+ -o eth0 -j ACCEPT
#$IPT -A FORWARD -i eth0 -o tun+ -j ACCEPT
#$IPT -t nat -A POSTROUTING -s 10.10.42.0/24 -o eth0 -j MASQUERADE # OOP but w/e

## FORWARD LOG rule
$IPT -A FORWARD ! -i lo -m limit --limit 3/min -j LOG --log-prefix "DROP " --log-ip-options --log-tcp-options --log-level 4

### DEFAULT POLICY: DROP THAT SHIT  ###
$IPT -A INPUT -j DROP
$IPT -A OUTPUT -j DROP
$IPT -A FORWARD -j DROP
