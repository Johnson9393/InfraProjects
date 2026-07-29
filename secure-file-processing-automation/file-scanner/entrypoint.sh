#!/bin/sh

# Exit immediately if any command fails.
set -e

echo "========================================"
echo "Starting File Scanner Container..."
echo "========================================"

# Create required runtime directories.
echo "[1/6] Creating runtime directories..."
mkdir -p /var/run/clamav
mkdir -p /var/log/clamav

# Set required permissions for ClamAV.
echo "[2/6] Setting permissions..."
chown -R clamav:clamav /var/run/clamav
chown -R clamav:clamav /var/log/clamav
chown -R clamav:clamav /var/lib/clamav

# Download virus signatures if they don't exist.
echo "[3/6] Checking virus database..."

if [ ! -f /var/lib/clamav/main.cvd ]; then
    echo "Virus database not found. Downloading latest signatures..."
    freshclam
else
    echo "Virus database already exists."
fi

# Start the ClamAV daemon.
echo "[4/6] Starting ClamAV daemon..."
clamd --foreground >/dev/null 2>&1 &

# Wait until the ClamAV socket is ready.
echo "[5/6] Waiting for ClamAV daemon..."

while [ ! -S /var/run/clamav/clamd.ctl ]
do
    sleep 1
done

echo "ClamAV daemon is ready."

# Start the Python application.
echo "[6/6] Starting Python worker..."
exec python -u main.py