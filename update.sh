#!/bin/bash

# Konfigurasi
APP_NAME="rust-request-bin"
SERVICE_NAME="request-bin.service"
BINARY_PATH="./target/release/$APP_NAME"

echo "------- 🚀 Memulai Update $APP_NAME -------"

# 1. Tarik kode terbaru dari Git
echo "📥 Menarik kode terbaru dari Git..."
git pull origin master

# 2. Kompilasi ulang dalam mode release (Optimasi RAM & Kecepatan)
echo "🛠️  Kompilasi ulang (mode release)..."
cargo build --release

# 3. Cek apakah kompilasi berhasil
if [ $? -eq 0 ]; then
    echo "✅ Kompilasi berhasil!"

    # 4. Memperkecil ukuran biner (Strip symbols)
    # Ini membantu menghemat penyimpanan SSD dan sedikit loading memori
    echo "✂️  Memperkecil ukuran binary..."
    strip $BINARY_PATH

    # 5. Restart service menggunakan systemd
    echo "🔄 Me-restart service $SERVICE_NAME..."
    sudo systemctl restart $SERVICE_NAME

    # 6. Verifikasi status
    echo "📊 Mengecek status service..."
    sleep 2
    systemctl status $SERVICE_NAME --no-pager | grep Active

    # 7. Tampilkan penggunaan RAM terbaru
    echo "🧠 Penggunaan RAM saat ini:"
    systemctl status $SERVICE_NAME | grep Memory

    echo "------- ✨ Update Selesai! -------"
else
    echo "❌ Gagal kompilasi! Update dibatalkan."
    exit 1
fi