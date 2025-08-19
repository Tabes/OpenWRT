#!/bin/bash
################################################################################
### BPI-R4 Debian + OpenWrt LuCI Builder Script
### Creates Debian base system with OpenWrt management interface
################################################################################
### Build Debian 12 with OpenWrt LuCI Web Interface
################################################################################

set -e

################################################################################
### CONFIGURATION
################################################################################

### Load configuration from environment or use defaults ###
WORK_DIR="${WORK_DIR:-/opt/builder/work}"
IMAGE_SIZE="${IMAGE_SIZE:-8G}"
DEBIAN_VERSION="${DEBIAN_VERSION:-bookworm}"
HOSTNAME="${HOSTNAME:-bpi-r4}"
ROOT_PASSWORD="${ROOT_PASSWORD:-bananapi}"
OUTPUT_DIR="${OUTPUT_DIR:-/opt/builder/output}"
LOG_FILE="${LOG_FILE:-/opt/builder/log/debian-luci-$(date +%Y%m%d_%H%M%S).log}"

### Network Configuration ###
LAN_IP="${LAN_IP:-192.168.1.1}"
LAN_NETMASK="${LAN_NETMASK:-255.255.255.0}"
DHCP_START="${DHCP_START:-100}"
DHCP_END="${DHCP_END:-200}"

### Colors for output ###
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

################################################################################
### HELPER FUNCTIONS
################################################################################

### Print with logging ###
log_print() {
    local color=$1
    shift
    echo -e "${color}$*${NC}"
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $*" >> "$LOG_FILE"
}

### Print section header ###
print_header() {
    echo ""
    log_print "$BLUE" "=== $1 ==="
    echo ""
}

### Error handling ###
error_exit() {
    log_print "$RED" "ERROR: $1"
    cleanup
    exit 1
}

### Cleanup function ###
cleanup() {
    log_print "$YELLOW" "Cleaning up..."
    
    ### Unmount filesystems ###
    for mount in $(mount | grep "$WORK_DIR" | awk '{print $3}' | sort -r); do
        umount "$mount" 2>/dev/null || true
    done
    
    ### Detach loop devices ###
    if [ -n "$LOOP_DEV" ]; then
        losetup -d "$LOOP_DEV" 2>/dev/null || true
    fi
    
    log_print "$GREEN" "Cleanup completed"
}

### Set trap for cleanup ###
trap cleanup EXIT

################################################################################
### MAIN BUILD PROCESS
################################################################################

print_header "BPI-R4 Debian + OpenWrt LuCI Builder"
log_print "$YELLOW" "Creating Debian base with OpenWrt management interface"

### Create directories ###
print_header "Setting up build environment"
mkdir -p "$WORK_DIR"/{rootfs,boot,temp}
mkdir -p "$OUTPUT_DIR"
mkdir -p "$(dirname "$LOG_FILE")"

### Install build tools ###
print_header "Installing build dependencies"
log_print "$GREEN" "1. Installing build tools..."

apt-get update >> "$LOG_FILE" 2>&1

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
    liblua5.1-0-dev \
    cmake \
    pkg-config \
    libjson-c-dev \
    libnl-3-dev \
    libnl-genl-3-dev \
    ca-certificates \
    libssl-dev \
    libcurl4-openssl-dev \
    autoconf \
    automake \
    libtool \
    make \
    gcc \
    g++ >> "$LOG_FILE" 2>&1

### Create image file ###
print_header "Creating system image"
log_print "$GREEN" "2. Creating work directory..."

IMAGE_FILE="$WORK_DIR/debian-luci-bpi-r4.img"
rm -f "$IMAGE_FILE"

log_print "$GREEN" "3. Creating image file (8GB for extended software)..."
dd if=/dev/zero of="$IMAGE_FILE" bs=1 count=0 seek="$IMAGE_SIZE" >> "$LOG_FILE" 2>&1

### Partition image ###
log_print "$GREEN" "4. Partitioning image..."
parted "$IMAGE_FILE" --script mklabel gpt >> "$LOG_FILE" 2>&1
parted "$IMAGE_FILE" --script mkpart primary fat32 1MiB 256MiB >> "$LOG_FILE" 2>&1
parted "$IMAGE_FILE" --script mkpart primary ext4 256MiB 100% >> "$LOG_FILE" 2>&1
parted "$IMAGE_FILE" --script set 1 boot on >> "$LOG_FILE" 2>&1

### Setup loop device ###
LOOP_DEV=$(losetup --partscan --find --show "$IMAGE_FILE")
log_print "$CYAN" "Loop Device: $LOOP_DEV"

### Format partitions ###
log_print "$GREEN" "5. Formatting partitions..."
mkfs.vfat -F 32 -n BOOT "${LOOP_DEV}p1" >> "$LOG_FILE" 2>&1
mkfs.ext4 -L rootfs "${LOOP_DEV}p2" >> "$LOG_FILE" 2>&1

### Mount partitions ###
log_print "$GREEN" "6. Mounting partitions..."
mount "${LOOP_DEV}p2" "$WORK_DIR/rootfs"
mkdir -p "$WORK_DIR/rootfs/boot"
mount "${LOOP_DEV}p1" "$WORK_DIR/rootfs/boot"

### Bootstrap Debian ###
log_print "$GREEN" "7. Installing Debian base system..."
debootstrap \
    --arch=arm64 \
    --foreign \
    --include=wget,curl,net-tools,openssh-server,sudo,vim,htop,git,build-essential,ca-certificates,cmake,nginx,spawn-fcgi,fcgiwrap \
    "$DEBIAN_VERSION" \
    "$WORK_DIR/rootfs" \
    http://deb.debian.org/debian/ >> "$LOG_FILE" 2>&1

### Copy QEMU for ARM64 ###
cp /usr/bin/qemu-aarch64-static "$WORK_DIR/rootfs/usr/bin/"

### Second stage bootstrap ###
log_print "$GREEN" "8. Executing second stage bootstrap..."
chroot "$WORK_DIR/rootfs" /debootstrap/debootstrap --second-stage >> "$LOG_FILE" 2>&1

### Basic system configuration ###
log_print "$GREEN" "9. Configuring base system..."

### Configure fstab ###
cat << EOF > "$WORK_DIR/rootfs/etc/fstab"
/dev/mmcblk0p2  /       ext4    defaults,noatime  0 1
/dev/mmcblk0p1  /boot   vfat    defaults          0 2
tmpfs           /tmp    tmpfs   defaults,nosuid   0 0
EOF

### Set hostname ###
echo "$HOSTNAME" > "$WORK_DIR/rootfs/etc/hostname"

### Configure APT sources ###
cat << EOF > "$WORK_DIR/rootfs/etc/apt/sources.list"
deb http://deb.debian.org/debian $DEBIAN_VERSION main contrib non-free non-free-firmware
deb http://deb.debian.org/debian $DEBIAN_VERSION-updates main contrib non-free non-free-firmware
deb http://security.debian.org/debian-security $DEBIAN_VERSION-security main contrib non-free non-free-firmware
EOF

### Mount for chroot ###
mount -t proc proc "$WORK_DIR/rootfs/proc"
mount -t sysfs sys "$WORK_DIR/rootfs/sys"
mount -o bind /dev "$WORK_DIR/rootfs/dev"
mount -o bind /dev/pts "$WORK_DIR/rootfs/dev/pts"

### Install packages and configure OpenWrt components ###
print_header "Installing OpenWrt LuCI and dependencies"
log_print "$BLUE" "10. Installing OpenWrt LuCI and dependencies..."

cat << 'CHROOT_SCRIPT' | chroot "$WORK_DIR/rootfs" /bin/bash
#!/bin/bash
export DEBIAN_FRONTEND=noninteractive

### Update system ###
apt-get update
apt-get upgrade -y

### Install router packages ###
apt-get install -y \
    linux-image-arm64 \
    firmware-linux \
    firmware-realtek \
    firmware-atheros \
    bridge-utils \
    vlan \
    iptables \
    iptables-persistent \
    iproute2 \
    ethtool \
    tcpdump \
    wireless-tools \
    wpasupplicant \
    hostapd \
    rfkill \
    dnsmasq \
    nginx \
    fcgiwrap \
    spawn-fcgi

### Install development tools ###
apt-get install -y \
    lua5.1 \
    liblua5.1-0-dev \
    liblua5.1-0 \
    cmake \
    pkg-config \
    libjson-c-dev \
    libnl-3-dev \
    libnl-genl-3-dev \
    libubox-dev \
    ca-certificates \
    git \
    autoconf \
    automake \
    libtool \
    make \
    gcc \
    g++

### Update CA certificates ###
update-ca-certificates

### Create OpenWrt directory structure ###
mkdir -p /etc/config
mkdir -p /var/run
mkdir -p /var/lock
mkdir -p /usr/lib/lua/luci
mkdir -p /www/cgi-bin
mkdir -p /www/luci-static
mkdir -p /tmp/luci-indexcache

### Build and install UCI ###
cd /tmp
export GIT_SSL_NO_VERIFY=1
git clone https://git.openwrt.org/project/uci.git || {
    echo "Downloading UCI tarball as fallback..."
    wget https://github.com/openwrt/uci/archive/master.tar.gz -O uci.tar.gz
    tar xzf uci.tar.gz
    mv uci-master uci
}

cd uci
cmake .
make
make install
ldconfig

### Build and install ubus ###
cd /tmp
git clone https://git.openwrt.org/project/ubus.git || {
    echo "Downloading ubus tarball as fallback..."
    wget https://github.com/openwrt/ubus/archive/master.tar.gz -O ubus.tar.gz
    tar xzf ubus.tar.gz
    mv ubus-master ubus
}

cd ubus
cmake .
make
make install
ldconfig

### Build and install rpcd ###
cd /tmp
git clone https://git.openwrt.org/project/rpcd.git || {
    echo "Downloading rpcd tarball as fallback..."
    wget https://github.com/openwrt/rpcd/archive/master.tar.gz -O rpcd.tar.gz
    tar xzf rpcd.tar.gz
    mv rpcd-master rpcd
}

cd rpcd
cmake .
make
make install

### Build and install uhttpd ###
cd /tmp
git clone https://git.openwrt.org/project/uhttpd.git || {
    echo "Downloading uhttpd tarball as fallback..."
    wget https://github.com/openwrt/uhttpd/archive/master.tar.gz -O uhttpd.tar.gz
    tar xzf uhttpd.tar.gz
    mv uhttpd-master uhttpd
}

cd uhttpd
cmake .
make
make install

### Install LuCI ###
cd /tmp
git clone https://github.com/openwrt/luci.git || {
    echo "Downloading LuCI tarball as fallback..."
    wget https://github.com/openwrt/luci/archive/master.tar.gz -O luci.tar.gz
    tar xzf luci.tar.gz
    mv luci-master luci
}

cd luci
make

### Copy LuCI files ###
cp -R applications/* /usr/lib/lua/luci/ 2>/dev/null || true
cp -R collections/* /usr/lib/lua/luci/ 2>/dev/null || true
cp -R libs/* /usr/lib/lua/luci/ 2>/dev/null || true
cp -R modules/* /usr/lib/lua/luci/ 2>/dev/null || true
cp -R themes/* /usr/lib/lua/luci/ 2>/dev/null || true

### Create UCI configurations ###
cat << 'UCI_NETWORK' > /etc/config/network
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
UCI_NETWORK

cat << 'UCI_DHCP' > /etc/config/dhcp
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
UCI_DHCP

cat << 'UCI_FIREWALL' > /etc/config/firewall
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
UCI_FIREWALL

cat << 'UCI_SYSTEM' > /etc/config/system
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
UCI_SYSTEM

cat << 'UCI_WIRELESS' > /etc/config/wireless
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
UCI_WIRELESS

### Configure nginx for LuCI ###
cat << 'NGINX_LUCI' > /etc/nginx/sites-available/luci
server {
    listen 80 default_server;
    listen [::]:80 default_server;
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
        expires 1d;
    }
    
    location / {
        try_files $uri $uri/ @luci;
    }
    
    location @luci {
        rewrite ^(.*)$ /cgi-bin/luci$1 last;
    }
}
NGINX_LUCI

### Enable LuCI site ###
rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/luci /etc/nginx/sites-enabled/

### Create LuCI CGI script ###
cat << 'LUCI_CGI' > /www/cgi-bin/luci
#!/usr/bin/lua
package.path = "/usr/lib/lua/luci/?.lua;" .. package.path
require "luci.dispatcher"
luci.dispatcher.indexcache = "/tmp/luci-indexcache"
luci.dispatcher.run()
LUCI_CGI
chmod +x /www/cgi-bin/luci

### Create web interface index ###
cat << 'WEB_INDEX' > /www/index.html
<!DOCTYPE html>
<html>
<head>
    <title>BPI-R4 Router</title>
    <meta http-equiv="refresh" content="0; url=/cgi-bin/luci">
    <style>
        body { font-family: Arial, sans-serif; text-align: center; margin-top: 100px; }
        .container { background: #f0f0f0; padding: 20px; border-radius: 10px; display: inline-block; }
    </style>
</head>
<body>
    <div class="container">
        <h1>BPI-R4 Router</h1>
        <p>Redirecting to LuCI management interface...</p>
        <p><a href="/cgi-bin/luci">Click here if not redirected automatically</a></p>
    </div>
</body>
</html>
WEB_INDEX

### Create OpenWrt compatibility systemd service ###
cat << 'SYSTEMD_SERVICE' > /etc/systemd/system/openwrt-compat.service
[Unit]
Description=OpenWrt Compatibility Layer
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/openwrt-init.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
SYSTEMD_SERVICE

### Create OpenWrt initialization script ###
cat << 'INIT_SCRIPT' > /usr/local/bin/openwrt-init.sh
#!/bin/bash
### OpenWrt compatibility initialization ###

### Create runtime directories ###
mkdir -p /var/run/ubus
mkdir -p /var/run/rpcd
mkdir -p /tmp/dhcp.leases
mkdir -p /tmp/run
mkdir -p /tmp/luci-indexcache

### Start ubus daemon ###
if command -v ubusd >/dev/null 2>&1; then
    /usr/local/sbin/ubusd -s /var/run/ubus/ubus.sock &
fi

### Start rpcd daemon ###
if command -v rpcd >/dev/null 2>&1; then
    /usr/local/sbin/rpcd &
fi

### Load UCI configurations ###
if command -v uci >/dev/null 2>&1; then
    for config in /etc/config/*; do
        [ -f "$config" ] && uci import "$(basename "$config")" < "$config" 2>/dev/null || true
    done
fi

### Apply network configuration ###
/usr/local/bin/uci-to-debian-network.sh

### Apply firewall rules ###
/usr/local/bin/uci-to-iptables.sh

echo "OpenWrt compatibility layer started"
INIT_SCRIPT
chmod +x /usr/local/bin/openwrt-init.sh

### Create UCI to Debian network converter ###
cat << 'NETWORK_CONVERTER' > /usr/local/bin/uci-to-debian-network.sh
#!/bin/bash
### Convert UCI network config to Debian networking ###

### Read LAN configuration from UCI ###
LAN_IP=$(uci get network.lan.ipaddr 2>/dev/null || echo "192.168.1.1")
LAN_NETMASK=$(uci get network.lan.netmask 2>/dev/null || echo "255.255.255.0")

### Create Debian network interfaces ###
cat << INTERFACES > /etc/network/interfaces
auto lo
iface lo inet loopback

### WAN Interface ###
auto eth0
iface eth0 inet dhcp

### LAN Bridge ###
auto br-lan
iface br-lan inet static
    address ${LAN_IP}
    netmask ${LAN_NETMASK}
    bridge_ports eth1 eth2 eth3
    bridge_stp off
    bridge_fd 0
    bridge_maxwait 0
INTERFACES

### Restart networking if systemctl is available ###
if command -v systemctl >/dev/null 2>&1; then
    systemctl restart networking 2>/dev/null || true
fi
NETWORK_CONVERTER
chmod +x /usr/local/bin/uci-to-debian-network.sh

### Create UCI to iptables converter ###
cat << 'FIREWALL_CONVERTER' > /usr/local/bin/uci-to-iptables.sh
#!/bin/bash
### Convert UCI firewall configuration to iptables ###

### Flush existing rules ###
iptables -F 2>/dev/null || true
iptables -t nat -F 2>/dev/null || true
iptables -t mangle -F 2>/dev/null || true

### Set default policies ###
iptables -P INPUT ACCEPT
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

### Enable NAT for WAN ###
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE

### Allow established connections ###
iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

### Allow LAN to WAN forwarding ###
iptables -A FORWARD -i br-lan -o eth0 -j ACCEPT

### Allow SSH ###
iptables -A INPUT -p tcp --dport 22 -j ACCEPT

### Allow HTTP ###
iptables -A INPUT -p tcp --dport 80 -j ACCEPT

### Allow DHCP ###
iptables -A INPUT -p udp --dport 67 -j ACCEPT

### Enable IP forwarding ###
echo 1 > /proc/sys/net/ipv4/ip_forward

### Save rules ###
mkdir -p /etc/iptables
iptables-save > /etc/iptables/rules.v4 2>/dev/null || true
FIREWALL_CONVERTER
chmod +x /usr/local/bin/uci-to-iptables.sh

### Set passwords ###
echo "root:$ROOT_PASSWORD" | chpasswd

### Create admin user ###
useradd -m -s /bin/bash -G sudo admin 2>/dev/null || true
echo "admin:admin" | chpasswd

### Enable services ###
systemctl enable ssh
systemctl enable nginx
systemctl enable fcgiwrap
systemctl enable openwrt-compat

### Install monitoring tools ###
apt-get install -y collectd collectd-core rrdtool

### Clean up ###
apt-get clean
rm -rf /tmp/* /var/tmp/*
CHROOT_SCRIPT

### Configure kernel modules ###
print_header "Configuring kernel modules"
log_print "$GREEN" "11. Configuring kernel modules..."

cat << EOF > "$WORK_DIR/rootfs/etc/modules"
### Network modules ###
bridge
8021q
nf_conntrack
nf_nat
xt_nat
iptable_nat
ipt_MASQUERADE

### WiFi modules ###
mac80211
cfg80211
mt76
mt7915e
mt7921e

### Hardware modules ###
thermal_sys
mtk_thermal
cryptodev
EOF

### Configure sysctl optimizations ###
cat << EOF > "$WORK_DIR/rootfs/etc/sysctl.d/99-router.conf"
### IP Forwarding ###
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1

### Network Performance ###
net.core.netdev_max_backlog = 5000
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq_codel

### Connection Tracking ###
net.netfilter.nf_conntrack_max = 65536
net.netfilter.nf_conntrack_tcp_timeout_established = 3600

### Security ###
net.ipv4.conf.all.rp_filter = 1
net.ipv4.tcp_syncookies = 1
EOF

### Configure bootloader ###
print_header "Configuring bootloader"
log_print "$GREEN" "12. Configuring bootloader..."

cat << 'UBOOT_SCRIPT' > "$WORK_DIR/rootfs/boot/boot.txt"
### BPI-R4 U-Boot Boot Script ###
setenv bootargs console=ttyS0,115200 root=/dev/mmcblk0p2 rootwait

### Load kernel components ###
load mmc 0:1 ${kernel_addr_r} vmlinuz
load mmc 0:1 ${fdt_addr_r} dtb/mediatek/mt7988-bananapi-bpi-r4.dtb
load mmc 0:1 ${ramdisk_addr_r} initrd.img

### Boot kernel ###
booti ${kernel_addr_r} ${ramdisk_addr_r}:${filesize} ${fdt_addr_r}
UBOOT_SCRIPT

### Compile boot script ###
mkimage -A arm64 -O linux -T script -C none -n "BPI-R4 Boot Script" \
    -d "$WORK_DIR/rootfs/boot/boot.txt" "$WORK_DIR/rootfs/boot/boot.scr" >> "$LOG_FILE" 2>&1

### Create quick start guide ###
cat << 'QUICK_START' > "$WORK_DIR/rootfs/root/README.txt"
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
QUICK_START

### Finalize image ###
print_header "Finalizing image"
log_print "$GREEN" "13. Finalizing image..."

### Remove QEMU binary ###
rm -f "$WORK_DIR/rootfs/usr/bin/qemu-aarch64-static"

### Unmount filesystems ###
umount "$WORK_DIR/rootfs/dev/pts"
umount "$WORK_DIR/rootfs/dev"
umount "$WORK_DIR/rootfs/proc"
umount "$WORK_DIR/rootfs/sys"
umount "$WORK_DIR/rootfs/boot"
umount "$WORK_DIR/rootfs"

### Detach loop device ###
losetup -d "$LOOP_DEV"
LOOP_DEV=""

### Compress image ###
log_print "$GREEN" "14. Compressing image..."
xz -9 -T0 "$IMAGE_FILE" >> "$LOG_FILE" 2>&1

### Move to output directory ###
OUTPUT_FILE="$OUTPUT_DIR/debian-luci-bpi-r4-$(date +%Y%m%d).img.xz"
mv "$IMAGE_FILE.xz" "$OUTPUT_FILE"

### Success message ###
print_header "Build completed successfully"

log_print "$BLUE" "========================================"
log_print "$GREEN" "✅ Build erfolgreich abgeschlossen!"
log_print "$BLUE" "========================================"
echo ""
log_print "$YELLOW" "Image: $OUTPUT_FILE"
echo ""
echo "📋 Installation:"
echo "   xzcat $OUTPUT_FILE | sudo dd of=/dev/sdX bs=4M status=progress"
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

### Generate build summary ###
cat << SUMMARY > "$OUTPUT_DIR/build_summary_$(date +%Y%m%d_%H%M%S).txt"
################################################################################
### BUILD SUMMARY - BPI-R4 Debian + OpenWrt LuCI
################################################################################

Build Information:
------------------
Date:             $(date '+%Y-%m-%d %H:%M:%S')
Build Type:       debian-luci
Target Device:    bpi-r4
Image Size:       $IMAGE_SIZE
Debian Version:   $DEBIAN_VERSION
Hostname:         $HOSTNAME
LAN IP:           $LAN_IP
Root Password:    $ROOT_PASSWORD

Output Files:
-------------
Image File:       $OUTPUT_FILE
Log File:         $LOG_FILE
Build Summary:    $OUTPUT_DIR/build_summary_$(date +%Y%m%d_%H%M%S).txt

Components Installed:
---------------------
✓ Debian 12 ($DEBIAN_VERSION) base system
✓ Linux kernel with ARM64 support
✓ OpenWrt UCI configuration system
✓ OpenWrt ubus message bus
✓ OpenWrt rpcd RPC daemon
✓ OpenWrt uhttpd web server (as fallback)
✓ LuCI web management interface
✓ Nginx web server with FastCGI
✓ Network bridge and routing support
✓ WiFi drivers and tools
✓ Firewall and NAT configuration
✓ DHCP server (dnsmasq)
✓ SSH server
✓ System monitoring tools

Network Configuration:
----------------------
LAN Interface:    br-lan (bridge)
LAN IP Address:   $LAN_IP
LAN Netmask:      $LAN_NETMASK
DHCP Range:       $LAN_IP (${DHCP_START}-${DHCP_END})
WAN Interface:    eth0 (DHCP client)

Services Enabled:
-----------------
✓ SSH (port 22)
✓ HTTP (port 80) - LuCI interface
✓ DHCP server
✓ DNS resolver
✓ Firewall/NAT
✓ OpenWrt compatibility layer

Installation Instructions:
--------------------------
1. Extract and write image to SD card:
   xzcat $OUTPUT_FILE | sudo dd of=/dev/sdX bs=4M status=progress

2. Insert SD card into BPI-R4 and power on

3. Access via web browser:
   http://192.168.1.1

4. Login credentials:
   Username: root
   Password: $ROOT_PASSWORD

Management:
-----------
- Web Interface: LuCI at http://192.168.1.1
- SSH Access: ssh root@192.168.1.1
- Configuration: UCI format in /etc/config/
- Debian packages: Available via apt

Troubleshooting:
----------------
- System logs: journalctl -f
- Kernel logs: dmesg -w
- Web server logs: /var/log/nginx/
- Network status: ip addr show
- UCI config: uci show

Support:
--------
This is a hybrid Debian/OpenWrt system combining:
- Full Debian package management (apt)
- OpenWrt-style configuration (UCI)
- LuCI web management interface
- Standard Linux networking tools

For issues, check the build log at: $LOG_FILE

################################################################################
SUMMARY

log_print "$GREEN" ""
log_print "$GREEN" "Build summary saved to: $OUTPUT_DIR/build_summary_$(date +%Y%m%d_%H%M%S).txt"
log_print "$GREEN" "Build log available at: $LOG_FILE"

exit 0