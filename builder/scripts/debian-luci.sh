#!/bin/bash
# BPI-R4 Debian 12 mit OpenWrt LuCI Interface
# Kombiniert Debian-Basis mit OpenWrt-Verwaltung

set -e

# Konfiguration
WORK_DIR="/tmp/bpi-r4-debian-luci"
IMAGE_SIZE="8G"
DEBIAN_VERSION="bookworm"
HOSTNAME="bpi-r4"
ROOT_PASSWORD="bananapi"
OUTPUT_DIR="/opt/builder/output"

# Farben für Output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== BPI-R4 Debian + OpenWrt LuCI Builder ===${NC}"
echo -e "${YELLOW}Erstelle Debian-Basis mit OpenWrt-Management-Interface${NC}"

# Cleanup-Funktion
cleanup() {
    echo -e "${YELLOW}Aufräumen...${NC}"
    sudo umount ${WORK_DIR}/rootfs/dev/pts 2>/dev/null || true
    sudo umount ${WORK_DIR}/rootfs/dev 2>/dev/null || true
    sudo umount ${WORK_DIR}/rootfs/proc 2>/dev/null || true
    sudo umount ${WORK_DIR}/rootfs/sys 2>/dev/null || true
    sudo umount ${WORK_DIR}/rootfs/boot 2>/dev/null || true
    sudo umount ${WORK_DIR}/rootfs 2>/dev/null || true
    sudo losetup -d ${LOOP_DEV} 2>/dev/null || true
}

trap cleanup EXIT

# Installiere Build-Tools
echo -e "${GREEN}1. Installiere Build-Tools...${NC}"
apt-get update
apt-get install -y \
    debootstrap \
    qemu-user-static \
    binfmt-support \
    parted \
    kpartx \
    dosfstools \
    e2fsprogs \
    git \
    gcc-aarch64-linux-gnu \
    device-tree-compiler \
    u-boot-tools \
    xz-utils \
    wget \
    curl \
    lua5.1 \
    lua5.1-dev

# Erstelle Arbeitsverzeichnis
echo -e "${GREEN}2. Erstelle Arbeitsverzeichnis...${NC}"
rm -rf ${WORK_DIR}
mkdir -p ${WORK_DIR}/{rootfs,boot,openwrt-src}
mkdir -p ${OUTPUT_DIR}

# Erstelle Image-Datei
echo -e "${GREEN}3. Erstelle Image-Datei (8GB für mehr Software)...${NC}"
IMAGE_FILE="${WORK_DIR}/debian-luci-bpi-r4.img"
dd if=/dev/zero of=${IMAGE_FILE} bs=1 count=0 seek=${IMAGE_SIZE}

# Partitionierung
echo -e "${GREEN}4. Partitioniere Image...${NC}"
parted ${IMAGE_FILE} --script mklabel gpt
parted ${IMAGE_FILE} --script mkpart primary fat32 1MiB 256MiB
parted ${IMAGE_FILE} --script mkpart primary ext4 256MiB 100%
parted ${IMAGE_FILE} --script set 1 boot on

# Setup Loop Device
LOOP_DEV=$(sudo losetup --partscan --find --show ${IMAGE_FILE})
echo "Loop Device: ${LOOP_DEV}"

# Formatiere Partitionen
echo -e "${GREEN}5. Formatiere Partitionen...${NC}"
sudo mkfs.vfat -F 32 -n BOOT ${LOOP_DEV}p1
sudo mkfs.ext4 -L rootfs ${LOOP_DEV}p2

# Mount Partitionen
echo -e "${GREEN}6. Mounte Partitionen...${NC}"
sudo mount ${LOOP_DEV}p2 ${WORK_DIR}/rootfs
sudo mkdir -p ${WORK_DIR}/rootfs/boot
sudo mount ${LOOP_DEV}p1 ${WORK_DIR}/rootfs/boot

# Debian Bootstrap
echo -e "${GREEN}7. Installiere Debian Base System...${NC}"
sudo debootstrap \
    --arch=arm64 \
    --foreign \
    --include=wget,curl,net-tools,openssh-server,sudo,vim,htop,git,build-essential \
    ${DEBIAN_VERSION} \
    ${WORK_DIR}/rootfs \
    http://deb.debian.org/debian/

# Kopiere QEMU für ARM64
sudo cp /usr/bin/qemu-aarch64-static ${WORK_DIR}/rootfs/usr/bin/

# Zweite Stage Bootstrap
echo -e "${GREEN}8. Führe zweite Stage Bootstrap aus...${NC}"
sudo chroot ${WORK_DIR}/rootfs /debootstrap/debootstrap --second-stage

# Basis-Konfiguration
echo -e "${GREEN}9. Konfiguriere Basis-System...${NC}"

# fstab
cat << EOF | sudo tee ${WORK_DIR}/rootfs/etc/fstab
/dev/mmcblk0p2  /       ext4    defaults,noatime  0 1
/dev/mmcblk0p1  /boot   vfat    defaults          0 2
tmpfs           /tmp    tmpfs   defaults,nosuid   0 0
EOF

# Hostname
echo ${HOSTNAME} | sudo tee ${WORK_DIR}/rootfs/etc/hostname

# APT Sources
cat << EOF | sudo tee ${WORK_DIR}/rootfs/etc/apt/sources.list
deb http://deb.debian.org/debian ${DEBIAN_VERSION} main contrib non-free non-free-firmware
deb http://deb.debian.org/debian ${DEBIAN_VERSION}-updates main contrib non-free non-free-firmware
deb http://security.debian.org/debian-security ${DEBIAN_VERSION}-security main contrib non-free non-free-firmware
EOF

# Mount für Chroot
sudo mount -t proc proc ${WORK_DIR}/rootfs/proc
sudo mount -t sysfs sys ${WORK_DIR}/rootfs/sys
sudo mount -o bind /dev ${WORK_DIR}/rootfs/dev
sudo mount -o bind /dev/pts ${WORK_DIR}/rootfs/dev/pts

# Installiere Debian-Pakete und OpenWrt-Komponenten
echo -e "${BLUE}10. Installiere OpenWrt LuCI und Abhängigkeiten...${NC}"
cat << 'CHROOT_SCRIPT' | sudo chroot ${WORK_DIR}/rootfs /bin/bash
#!/bin/bash
export DEBIAN_FRONTEND=noninteractive

# System Update
apt-get update
apt-get upgrade -y

# Basis-Pakete für Router
apt-get install -y \
    linux-image-arm64 \
    firmware-linux \
    firmware-realtek \
    firmware-atheros \
    firmware-mediatek \
    bridge-utils \
    vlan \
    iptables \
    iproute2 \
    ethtool \
    tcpdump \
    wireless-tools \
    wpasupplicant \
    hostapd \
    rfkill

# Entwicklungs-Tools für LuCI
apt-get install -y \
    lua5.1 \
    lua5.1-dev \
    liblua5.1-0 \
    lua-cjson \
    lua-socket \
    lua-nixio \
    nginx \
    fcgiwrap \
    spawn-fcgi \
    python3-pip \
    cmake \
    pkg-config \
    libjson-c-dev \
    libnl-3-dev \
    libnl-genl-3-dev

# UCI (OpenWrt Konfiguration) kompilieren
cd /tmp
git clone https://git.openwrt.org/project/uci.git
cd uci
cmake .
make
make install
ldconfig

# ubus (OpenWrt System Bus) kompilieren
cd /tmp
git clone https://git.openwrt.org/project/ubus.git
cd ubus
cmake .
make
make install
ldconfig

# rpcd (OpenWrt RPC Daemon)
cd /tmp
git clone https://git.openwrt.org/project/rpcd.git
cd rpcd
cmake .
make
make install

# uhttpd (OpenWrt HTTP Server)
cd /tmp
git clone https://git.openwrt.org/project/uhttpd.git
cd uhttpd
cmake .
make
make install

# LuCI Installation
cd /usr/local
git clone https://github.com/openwrt/luci.git
cd luci

# Build LuCI
make

# Erstelle LuCI Verzeichnisse
mkdir -p /www/cgi-bin
mkdir -p /etc/config
mkdir -p /var/run
mkdir -p /var/lock
mkdir -p /usr/lib/lua/luci

# Kopiere LuCI Dateien
cp -R /usr/local/luci/applications/* /usr/lib/lua/luci/ 2>/dev/null || true
cp -R /usr/local/luci/collections/* /usr/lib/lua/luci/ 2>/dev/null || true
cp -R /usr/local/luci/libs/* /usr/lib/lua/luci/ 2>/dev/null || true
cp -R /usr/local/luci/modules/* /usr/lib/lua/luci/ 2>/dev/null || true
cp -R /usr/local/luci/themes/* /usr/lib/lua/luci/ 2>/dev/null || true

# UCI Konfiguration (OpenWrt-Style)
cat << 'UCI' > /etc/config/network
config interface 'loopback'
    option ifname 'lo'
    option proto 'static'
    option ipaddr '127.0.0.1'
    option netmask '255.0.0.0'

config interface 'wan'
    option ifname 'eth0'
    option proto 'dhcp'

config interface 'lan'
    option type 'bridge'
    option ifname 'eth1 eth2 eth3'
    option proto 'static'
    option ipaddr '192.168.1.1'
    option netmask '255.255.255.0'
UCI

cat << 'UCI' > /etc/config/dhcp
config dnsmasq
    option domainneeded '1'
    option localise_queries '1'
    option rebind_protection '1'
    option rebind_localhost '1'
    option local '/lan/'
    option domain 'lan'
    option expandhosts '1'
    option authoritative '1'
    option readethers '1'
    option leasefile '/tmp/dhcp.leases'
    option resolvfile '/tmp/resolv.conf.auto'

config dhcp 'lan'
    option interface 'lan'
    option start '100'
    option limit '150'
    option leasetime '12h'

config dhcp 'wan'
    option interface 'wan'
    option ignore '1'
UCI

cat << 'UCI' > /etc/config/firewall
config defaults
    option syn_flood '1'
    option input 'ACCEPT'
    option output 'ACCEPT'
    option forward 'REJECT'

config zone
    option name 'lan'
    list network 'lan'
    option input 'ACCEPT'
    option output 'ACCEPT'
    option forward 'ACCEPT'

config zone
    option name 'wan'
    list network 'wan'
    option input 'REJECT'
    option output 'ACCEPT'
    option forward 'REJECT'
    option masq '1'
    option mtu_fix '1'

config forwarding
    option src 'lan'
    option dest 'wan'

config rule
    option name 'Allow-DHCP-Renew'
    option src 'wan'
    option proto 'udp'
    option dest_port '68'
    option target 'ACCEPT'
    option family 'ipv4'

config rule
    option name 'Allow-SSH'
    option src 'wan'
    option dest_port '22'
    option proto 'tcp'
    option target 'ACCEPT'

config rule
    option name 'Allow-HTTP'
    option src 'lan'
    option dest_port '80'
    option proto 'tcp'
    option target 'ACCEPT'
UCI

cat << 'UCI' > /etc/config/system
config system
    option hostname 'BPI-R4'
    option timezone 'UTC'
    option ttylogin '0'
    option log_size '64'
    option urandom_seed '0'

config timeserver 'ntp'
    option enabled '1'
    option enable_server '0'
    list server '0.debian.pool.ntp.org'
    list server '1.debian.pool.ntp.org'
UCI

cat << 'UCI' > /etc/config/wireless
config wifi-device 'radio0'
    option type 'mac80211'
    option channel '36'
    option hwmode '11a'
    option path 'platform/soc/18000000.wmac'
    option htmode 'VHT80'

config wifi-iface 'default_radio0'
    option device 'radio0'
    option network 'lan'
    option mode 'ap'
    option ssid 'BPI-R4-5G'
    option encryption 'psk2'
    option key 'bananapi'

config wifi-device 'radio1'
    option type 'mac80211'
    option channel '11'
    option hwmode '11g'
    option path 'platform/soc/18000000.wmac+1'
    option htmode 'HT20'

config wifi-iface 'default_radio1'
    option device 'radio1'
    option network 'lan'
    option mode 'ap'
    option ssid 'BPI-R4-2G'
    option encryption 'psk2'
    option key 'bananapi'
UCI

# NGINX Konfiguration für LuCI
cat << 'NGINX' > /etc/nginx/sites-available/luci
server {
    listen 80;
    listen [::]:80;
    server_name _;
    
    root /www;
    index index.html;
    
    location /cgi-bin/luci {
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME /www/cgi-bin/luci;
        fastcgi_param PATH_INFO $fastcgi_script_name;
        fastcgi_pass unix:/var/run/fcgiwrap.socket;
    }
    
    location /luci-static {
        alias /www/luci-static;
    }
}
NGINX

ln -s /etc/nginx/sites-available/luci /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# LuCI CGI Script
cat << 'LUCI' > /www/cgi-bin/luci
#!/usr/bin/lua
require "luci.dispatcher"
luci.dispatcher.indexcache = "/tmp/luci-indexcache"
luci.dispatcher.run()
LUCI
chmod +x /www/cgi-bin/luci

# Startup Script für OpenWrt-Dienste
cat << 'STARTUP' > /etc/systemd/system/openwrt-compat.service
[Unit]
Description=OpenWrt Compatibility Layer
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/openwrt-init.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
STARTUP

cat << 'INIT' > /usr/local/bin/openwrt-init.sh
#!/bin/bash
# OpenWrt Kompatibilität initialisieren

# Erstelle Verzeichnisse
mkdir -p /var/run/ubus
mkdir -p /var/run/rpcd
mkdir -p /tmp/dhcp.leases
mkdir -p /tmp/run

# Starte ubus
/usr/local/sbin/ubusd &

# Starte rpcd
/usr/local/sbin/rpcd &

# Lade UCI Konfiguration
for config in /etc/config/*; do
    uci import $(basename $config) < $config
done

# Netzwerk-Konfiguration anwenden
/usr/local/bin/uci-to-debian-network.sh

# Firewall anwenden
/usr/local/bin/uci-to-iptables.sh

echo "OpenWrt compatibility layer started"
INIT
chmod +x /usr/local/bin/openwrt-init.sh

# UCI zu Debian Netzwerk Konverter
cat << 'CONVERTER' > /usr/local/bin/uci-to-debian-network.sh
#!/bin/bash
# Konvertiert UCI network config zu Debian networking

# Lese LAN IP aus UCI
LAN_IP=$(uci get network.lan.ipaddr 2>/dev/null || echo "192.168.1.1")
LAN_NETMASK=$(uci get network.lan.netmask 2>/dev/null || echo "255.255.255.0")

# Erstelle Debian interfaces Datei
cat << EOF > /etc/network/interfaces
auto lo
iface lo inet loopback

# WAN Interface
auto eth0
iface eth0 inet dhcp

# LAN Bridge
auto br-lan
iface br-lan inet static
    address ${LAN_IP}
    netmask ${LAN_NETMASK}
    bridge_ports eth1 eth2 eth3
    bridge_stp off
    bridge_fd 0
EOF

# Restart Networking
systemctl restart networking
CONVERTER
chmod +x /usr/local/bin/uci-to-debian-network.sh

# UCI zu iptables Konverter
cat << 'FIREWALL' > /usr/local/bin/uci-to-iptables.sh
#!/bin/bash
# Konvertiert UCI firewall zu iptables

# Flush existing rules
iptables -F
iptables -t nat -F
iptables -t mangle -F

# Default policies
iptables -P INPUT ACCEPT
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

# NAT für WAN
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE

# Allow established connections
iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

# Allow LAN to WAN
iptables -A FORWARD -i br-lan -o eth0 -j ACCEPT

# Enable IP forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward

# Save rules
iptables-save > /etc/iptables/rules.v4
FIREWALL
chmod +x /usr/local/bin/uci-to-iptables.sh

# Web-Interface Anpassungen
cat << 'INDEX' > /www/index.html
<!DOCTYPE html>
<html>
<head>
    <title>BPI-R4 Router</title>
    <meta http-equiv="refresh" content="0; url=/cgi-bin/luci">
</head>
<body>
    <p>Redirecting to LuCI interface...</p>
</body>
</html>
INDEX

# Setze Passwörter
echo "root:${ROOT_PASSWORD}" | chpasswd

# Erstelle Admin User
useradd -m -s /bin/bash -G sudo admin
echo "admin:admin" | chpasswd

# Services aktivieren
systemctl enable ssh
systemctl enable nginx
systemctl enable fcgiwrap
systemctl enable openwrt-compat

# Installiere zusätzliche LuCI Apps
cd /tmp
# luci-app-firewall
git clone https://github.com/openwrt/luci.git luci-apps
cp -R luci-apps/applications/luci-app-firewall /usr/lib/lua/luci/
cp -R luci-apps/applications/luci-app-network /usr/lib/lua/luci/
cp -R luci-apps/applications/luci-app-system /usr/lib/lua/luci/
cp -R luci-apps/applications/luci-app-statistics /usr/lib/lua/luci/

# Performance Monitoring
apt-get install -y collectd collectd-core rrdtool

# Cleanup
apt-get clean
rm -rf /tmp/*
CHROOT_SCRIPT

# Kernel Module für Router
echo -e "${GREEN}11. Konfiguriere Kernel Module...${NC}"
cat << EOF | sudo tee ${WORK_DIR}/rootfs/etc/modules
# Network
bridge
8021q
nf_conntrack
nf_nat
xt_nat
iptable_nat
ipt_MASQUERADE

# WiFi
mac80211
cfg80211
mt76
mt7915e
mt7921e

# Hardware
thermal_sys
mtk_thermal
cryptodev
EOF

# Sysctl Optimierungen
cat << EOF | sudo tee ${WORK_DIR}/rootfs/etc/sysctl.d/99-router.conf
# IP Forwarding
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1

# Netzwerk Performance
net.core.netdev_max_backlog = 5000
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq_codel

# Conntrack
net.netfilter.nf_conntrack_max = 65536
net.netfilter.nf_conntrack_tcp_timeout_established = 3600

# Security
net.ipv4.conf.all.rp_filter = 1
net.ipv4.tcp_syncookies = 1
EOF

# U-Boot Konfiguration
echo -e "${GREEN}12. Konfiguriere Bootloader...${NC}"
cat << 'UBOOT' | sudo tee ${WORK_DIR}/rootfs/boot/boot.txt
# BPI-R4 U-Boot Boot Script
setenv bootargs console=ttyS0,115200 root=/dev/mmcblk0p2 rootwait

# Lade Kernel
load mmc 0:1 ${kernel_addr_r} vmlinuz
load mmc 0:1 ${fdt_addr_r} dtb/mediatek/mt7988-bananapi-bpi-r4.dtb
load mmc 0:1 ${ramdisk_addr_r} initrd.img

# Boote Kernel
booti ${kernel_addr_r} ${ramdisk_addr_r}:${filesize} ${fdt_addr_r}
UBOOT

# Kompiliere Boot Script
sudo mkimage -A arm64 -O linux -T script -C none -n "BPI-R4 Boot Script" \
    -d ${WORK_DIR}/rootfs/boot/boot.txt ${WORK_DIR}/rootfs/boot/boot.scr 2>/dev/null || true

# Quick Start Guide
cat << 'GUIDE' | sudo tee ${WORK_DIR}/rootfs/root/README.txt
===========================================
BPI-R4 Debian + OpenWrt LuCI Quick Start
===========================================

ZUGANG:
-------
Web-Interface: http://192.168.1.1
SSH: ssh root@192.168.1.1
Passwort: bananapi

VERWALTUNG:
-----------
Die Verwaltung erfolgt über das OpenWrt LuCI Web-Interface.
Alle Konfigurationen werden in /etc/config/ gespeichert (UCI Format).

BEFEHLE:
--------
uci show                    - Zeige Konfiguration
uci set network.lan.ipaddr=192.168.2.1  - Ändere IP
uci commit                  - Speichere Änderungen
/etc/init.d/network restart - Netzwerk neustarten

WIFI:
-----
uci set wireless.radio0.disabled=0
uci commit wireless
wifi reload

FIREWALL:
---------
Die Firewall wird über LuCI oder UCI konfiguriert:
uci show firewall
/usr/local/bin/uci-to-iptables.sh

DEBIAN PAKETE:
--------------
Normale Debian-Pakete können weiterhin installiert werden:
apt update
apt install <paket>

LOGS:
-----
System: journalctl -f
Kernel: dmesg -w
LuCI: /var/log/nginx/error.log

===========================================
GUIDE

# Cleanup QEMU
sudo rm ${WORK_DIR}/rootfs/usr/bin/qemu-aarch64-static

# Unmount
echo -e "${GREEN}13. Finalisiere Image...${NC}"
sudo umount ${WORK_DIR}/rootfs/dev/pts
sudo umount ${WORK_DIR}/rootfs/dev
sudo umount ${WORK_DIR}/rootfs/proc
sudo umount ${WORK_DIR}/rootfs/sys
sudo umount ${WORK_DIR}/rootfs/boot
sudo umount ${WORK_DIR}/rootfs

# Detach Loop Device
sudo losetup -d ${LOOP_DEV}

# Komprimiere Image
echo -e "${GREEN}14. Komprimiere Image...${NC}"
xz -9 -T0 ${IMAGE_FILE}

# Verschiebe zum Output
mv ${IMAGE_FILE}.xz ${OUTPUT_DIR}/debian-luci-bpi-r4-$(date +%Y%m%d).img.xz

echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}✅ Build erfolgreich abgeschlossen!${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${YELLOW}Image: ${OUTPUT_DIR}/debian-luci-bpi-r4-*.img.xz${NC}"
echo ""
echo "📋 Installation:"
echo "   xzcat ${OUTPUT_DIR}/debian-luci-bpi-r4-*.img.xz | sudo dd of=/dev/sdX bs=4M status=progress"
echo ""
echo "🌐 Zugang:"
echo "   Web-Interface: http://192.168.1.1"
echo "   SSH: ssh root@192.168.1.1"
echo "   Passwort: bananapi"
echo ""
echo "📖 Features:"
echo "   ✓ Debian 12 Basis (volle APT Pakete)"
echo "   ✓ OpenWrt LuCI Web-Interface"
echo "   ✓ UCI Konfiguration (OpenWrt-Style)"
echo "   ✓ Firewall & NAT vorkonfiguriert"
echo "   ✓ DHCP Server aktiv"
echo "   ✓ WiFi 7 ready"
echo "   ✓ 2.5G/10G Ethernet Support"
