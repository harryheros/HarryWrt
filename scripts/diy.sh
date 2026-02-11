#!/usr/bin/env bash
set -euo pipefail

# Put custom banner into image
mkdir -p files/etc

cat > files/etc/banner <<'EOF'
 _   _                           __        __   _   
| | | | __ _ _ __ _ __ _   _     \ \      / /__| |_ 
| |_| |/ _` | '__| '__| | | |_____\ \ /\ / / _ \ __|
|  _  | (_| | |  | |  | |_| |_____\ V  V /  __/ |_ 
|_| |_|\__,_|_|  |_|   \__, |      \_/\_/ \___|\__|
                        |___/                       
HarryWrt 24.10.5 - Lab Edition
EOF
