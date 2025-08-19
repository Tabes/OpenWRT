#!/bin/bash
echo "🚀 Starte BPI-R4 Image Build..."
echo "Das dauert ca. 15-20 Minuten..."
echo ""
docker compose up --build
echo ""
echo "✅ Build fertig!"
echo "Image verfügbar in: output/targets/mediatek/filogic/"
echo ""
echo "Auf SD-Karte schreiben mit:"
echo "sudo dd if=output/targets/mediatek/filogic/openwrt-*-bpi-r4-sdcard.img of=/dev/sdX bs=4M status=progress"
