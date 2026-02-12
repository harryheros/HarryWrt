#!/usr/bin/env bash
set -euo pipefail

mkdir -p files/etc/config

cat > files/etc/config/system <<'EOF'
config system
    option hostname 'HarryWrt'
    option timezone 'HKT-8'
    option zonename 'Asia/Hong_Kong'
EOF

cat > files/etc/banner <<'EOF'
---------------------------------------------------------------
 _   _                           _  _   _  ____  _____
| | | | __ _ _ __ _ __ _   _    | || | | ||  _ \|_   _|
| |_| |/ _` | '__| '__| | | |   | || |_| || |_) | | |
|  _  | (_| | |  | |  | |_| |   |__   _  ||  _ <  | |
|_| |_|\__,_|_|  |_|   \__, |      |_| |_||_| \_\ |_|
                       |___/
---------------------------------------------------------------
 HarryWrt 24.10.5 | Lab Edition | Pure Performance
 Minimal Bloatware | Built for Stability
---------------------------------------------------------------
EOF

echo "DIY script executed successfully."
