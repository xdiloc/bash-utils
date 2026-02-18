#!/bin/bash

echo "Clearing RAM cache..."
# Clear page cache, dentries, and inodes
sudo sh -c "echo 3 > '/proc/sys/vm/drop_caches'"
echo "RAM cache cleared."

# Disable swap
sudo swapoff -a
echo "Swap disabled."

# Enable swap
sudo swapon -a
echo "Swap enable."

echo "=== RAM cache and Swap Cleared ===";
echo "Press any key to continue..."

read -n 1 -s
