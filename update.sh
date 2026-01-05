#!/bin/bash

# Konfigurasi
APP_NAME="rust-request-bin"
SERVICE_NAME="request-bin.service"
BINARY_PATH="./target/release/$APP_NAME"

echo "------- 🚀 Memulai Build & Deploy Lokal $APP_NAME -------"

# 1. Kompilasi ulang dalam mode release (Optimasi RAM & Kecepatan)
# Cargo hanya akan melakukan rebuild jika ada perubahan pada file .rs Anda
echo "🛠️  Mengecek dan mengompilasi kode existing (mode release)..."
cargo build --release

# 2. Cek apakah kompilasi berhasil
if [ $? -eq 0 ]; then
    echo "✅ Kompilasi berhasil!"

    # 3. Memperkecil ukuran biner (Strip symbols)
    # Sangat penting untuk menjaga kesehatan SSD bekas Anda
    echo "✂️  Memperkecil ukuran binary (strip symbols)..."
    strip $BINARY_PATH

    # 4. Restart service menggunakan systemd
    echo "🔄 Me-restart service $SERVICE_NAME..."
    sudo systemctl restart $SERVICE_NAME

    # 5. Verifikasi status
    echo "📊 Mengecek status service..."
    sleep 2
    systemctl status $SERVICE_NAME --no-pager | grep Active

    # 6. Tampilkan penggunaan RAM terbaru
    echo "🧠 Penggunaan RAM saat ini:"
    systemctl status $SERVICE_NAME | grep Memory

    echo "------- ✨ Deploy Selesai! -------"
else
    echo "❌ Gagal kompilasi! Cek kembali kode Rust Anda."
    exit 1
fi
