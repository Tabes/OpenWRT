#!/bin/bash
# BPI-R4 Boot Fix Script
# Fügt den korrekten Bootloader zum Debian-Image hinzu
# Verwendung: sudo ./bpi-r4-boot.sh /dev/sdX

set -e

# Farben für Output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Konfiguration
DEVICE="${1:-/dev/sdb}"
WORK_DIR="/opt/builder/boot"
IMAGE_FILE="/opt/builder/output/debian-luci-bpi-r4-*.img.xz"
TEMP_DIR="/tmp/bpi-r4-fix"

# Banner
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}    BPI-R4 Boot Fix für Debian Image${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Sicherheitscheck
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}❌ Bitte als root ausführen (sudo)${NC}"
    exit 1
fi

if [ ! -b "$DEVICE" ]; then
    echo -e "${RED}❌ Gerät $DEVICE nicht gefunden${NC}"
    echo "Verwendung: $0 /dev/sdX"
    echo ""
    echo "Verfügbare Geräte:"
    lsblk -d -o NAME,SIZE,MODEL
    exit 1
fi

# Bestätigung
echo -e "${YELLOW}⚠️  WARNUNG: Alle Daten auf $DEVICE werden gelöscht!${NC}"
echo -e "Gerät: ${RED}$DEVICE${NC}"
fdisk -l "$DEVICE" | head -5
echo ""
read -p "Fortfahren? (ja/nein): " confirm
if [ "$confirm" != "ja" ]; then
    echo "Abgebrochen."
    exit 1
fi

# Arbeitsverzeichnisse erstellen
echo -e "${GREEN}1. Erstelle Arbeitsverzeichnisse...${NC}"
mkdir -p "$WORK_DIR"
mkdir -p "$TEMP_DIR"
cd "$WORK_DIR"

# Unmount falls gemounted
echo -e "${GREEN}2. Unmounte Partitionen...${NC}"
umount ${DEVICE}* 2>/dev/null || true

# Bootloader herunterladen
echo -e "${GREEN}3. Lade BPI-R4 Bootloader...${NC}"
if [ ! -f "$WORK_DIR/bpi-r4_sdmmc.img" ]; then
    echo "Downloading Frank-W's BPI-R4 Bootloader..."
    wget -q --show-progress https://github.com/frank-w/u-boot/releases/download/2024-01-bpi/bpi-r4_sdmmc.img.gz
    gunzip -f bpi-r4_sdmmc.img.gz
else
    echo "Bootloader bereits vorhanden, überspringe Download."
fi

# Kernel und Device Tree herunterladen
echo -e "${GREEN}4. Lade BPI-R4 Kernel...${NC}"
if [ ! -f "$WORK_DIR/bpi-r4-kernel.tar.gz" ]; then
    echo "Downloading BPI-R4 Kernel 6.6..."
    wget -q --show-progress -O bpi-r4-kernel.tar.gz \
        https://github.com/frank-w/BPI-Router-Linux/releases/download/6.6-main/bpi-r4_6.6.0.tar.gz
else
    echo "Kernel bereits vorhanden, überspringe Download."
fi

# SD-Karte vorbereiten
echo -e "${GREEN}5. Bereite SD-Karte vor...${NC}"

# Partitionstabelle löschen
dd if=/dev/zero of="$DEVICE" bs=1M count=100 status=progress

# Bootloader schreiben (erste 4MB)
echo -e "${GREEN}6. Schreibe BPI-R4 Bootloader...${NC}"
dd if="$WORK_DIR/bpi-r4_sdmmc.img" of="$DEVICE" bs=512 count=8192 conv=notrunc status=progress

# GPT Partitionstabelle erstellen
echo -e "${GREEN}7. Erstelle Partitionen...${NC}"
parted -s "$DEVICE" mklabel gpt
parted -s "$DEVICE" mkpart primary fat32 4MiB 260MiB
parted -s "$DEVICE" mkpart primary ext4 260MiB 100%
parted -s "$DEVICE" set 1 boot on

# Kernel muss warten bis Partitionen erkannt werden
sleep 2
partprobe "$DEVICE"
sleep 2

# Partitionen formatieren
echo -e "${GREEN}8. Formatiere Partitionen...${NC}"
mkfs.vfat -F 32 -n BOOT "${DEVICE}p1" || mkfs.vfat -F 32 -n BOOT "${DEVICE}1"
mkfs.ext4 -F -L rootfs "${DEVICE}p2" || mkfs.ext4 -F -L rootfs "${DEVICE}2"

# Mount Points
mkdir -p "$TEMP_DIR/boot"
mkdir -p "$TEMP_DIR/root"

# Partitionen mounten (probiere beide Naming-Konventionen)
if [ -b "${DEVICE}p1" ]; then
    BOOT_PART="${DEVICE}p1"
    ROOT_PART="${DEVICE}p2"
else
    BOOT_PART="${DEVICE}1"
    ROOT_PART="${DEVICE}2"
fi

mount "$BOOT_PART" "$TEMP_DIR/boot"
mount "$ROOT_PART" "$TEMP_DIR/root"

# Debian-System extrahieren
echo -e "${GREEN}9. Extrahiere Debian-System...${NC}"
if ls $IMAGE_FILE 1> /dev/null 2>&1; then
    echo "Entpacke Debian-Image..."
    xzcat $IMAGE_FILE > "$TEMP_DIR/debian.img"
    
    # Loop-Device für Image
    LOOP_DEV=$(losetup --partscan --find --show "$TEMP_DIR/debian.img")
    echo "Loop Device: $LOOP_DEV"
    
    # Warte auf Partitionen
    sleep 2
    
    # System kopieren
    echo "Kopiere Root-Filesystem..."
    if [ -b "${LOOP_DEV}p2" ]; then
        rsync -ax --info=progress2 "${LOOP_DEV}p2"/ "$TEMP_DIR/root/"
    else
        # Falls das Image keine Partitionen hat, mounte direkt
        mkdir -p "$TEMP_DIR/debian-mount"
        mount -o loop,offset=$((512*2048)) "$TEMP_DIR/debian.img" "$TEMP_DIR/debian-mount"
        rsync -ax --info=progress2 "$TEMP_DIR/debian-mount"/ "$TEMP_DIR/root/"
        umount "$TEMP_DIR/debian-mount"
    fi
    
    # Loop-Device freigeben
    losetup -d "$LOOP_DEV"
else
    echo -e "${YELLOW}⚠️  Kein Debian-Image gefunden, erstelle Basis-System...${NC}"
    # Minimal Debian-System
    debootstrap --arch=arm64 bookworm "$TEMP_DIR/root" http://deb.debian.org/debian/
fi

# Kernel und Device Tree installieren
echo -e "${GREEN}10. Installiere BPI-R4 Kernel...${NC}"
cd "$TEMP_DIR/boot"
tar -xzf "$WORK_DIR/bpi-r4-kernel.tar.gz"

# Boot-Script erstellen
echo -e "${GREEN}11. Erstelle U-Boot Boot-Script...${NC}"
cat > "$TEMP_DIR/boot/boot.cmd" << 'EOF'
# BPI-R4 Boot Script
setenv kernel Image
setenv fdtfile mt7988a-bananapi-bpi-r4.dtb
setenv bootargs "console=ttyS0,115200 root=/dev/mmcblk0p2 rootwait rw"

# Lade Kernel und Device Tree
fatload mmc 0:1 0x46000000 ${kernel}
fatload mmc 0:1 0x47000000 ${fdtfile}

# Boote System
booti 0x46000000 - 0x47000000
EOF

# Boot-Script kompilieren
mkimage -A arm64 -T script -C none -d "$TEMP_DIR/boot/boot.cmd" "$TEMP_DIR/boot/boot.scr"

# fstab anpassen
echo -e "${GREEN}12. Konfiguriere fstab...${NC}"
cat > "$TEMP_DIR/root/etc/fstab" << 'EOF'
# /etc/fstab for BPI-R4
/dev/mmcblk0p2  /       ext4    defaults,noatime  0 1
/dev/mmcblk0p1  /boot   vfat    defaults          0 2
tmpfs           /tmp    tmpfs   defaults,nosuid   0 0
EOF

# Netzwerk-Konfiguration
echo -e "${GREEN}13. Konfiguriere Netzwerk...${NC}"
cat > "$TEMP_DIR/root/etc/network/interfaces" << 'EOF'
# Network Configuration for BPI-R4
auto lo
iface lo inet loopback

# WAN Port
auto eth0
iface eth0 inet dhcp

# LAN Bridge
auto br-lan
iface br-lan inet static
    address 192.168.1.1
    netmask 255.255.255.0
    bridge_ports eth1
    bridge_stp off
    bridge_fd 0
EOF

# Root-Passwort setzen (wenn chroot möglich)
echo -e "${GREEN}14. Setze Root-Passwort...${NC}"
if [ -f "$TEMP_DIR/root/usr/bin/qemu-aarch64-static" ] || [ "$(uname -m)" = "aarch64" ]; then
    echo "root:bananapi" | chroot "$TEMP_DIR/root" chpasswd
    echo -e "${GREEN}✓ Root-Passwort gesetzt: bananapi${NC}"
else
    echo -e "${YELLOW}⚠️  Kann Root-Passwort nicht setzen (kein QEMU). Beim ersten Boot setzen!${NC}"
fi

# SSH aktivieren
mkdir -p "$TEMP_DIR/root/root/.ssh"
touch "$TEMP_DIR/root/root/.ssh/authorized_keys"
chmod 700 "$TEMP_DIR/root/root/.ssh"
chmod 600 "$TEMP_DIR/root/root/.ssh/authorized_keys"

# Aufräumen
echo -e "${GREEN}15. Finalisiere...${NC}"
sync

# Unmount
umount "$TEMP_DIR/boot"
umount "$TEMP_DIR/root"

# Aufräumen
rm -rf "$TEMP_DIR"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}✅ BPI-R4 SD-Karte erfolgreich erstellt!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${BLUE}📋 Nächste Schritte:${NC}"
echo "1. SD-Karte sicher entfernen:"
echo "   sudo eject $DEVICE"
echo ""
echo "2. In BPI-R4 einsetzen und booten"
echo ""
echo "3. Zugriff über:"
echo "   - IP: 192.168.1.1 (LAN)"
echo "   - SSH: ssh root@192.168.1.1"
echo "   - Passwort: bananapi"
echo ""
echo -e "${YELLOW}💡 Tipp:${NC}"
echo "   Boot-Switch SW1 auf SD-Karte Position prüfen!"
echo "   Serial Console: 115200 8N1 auf UART0"
echo ""
