#!/bin/bash

# Function to show memory status in human-readable format
show_memory() {
	# Use LC_ALL=C to ensure consistent output regardless of system language
	local mem_info=$(LC_ALL=C free -m | grep "Mem:")
	local swap_info=$(LC_ALL=C free -m | grep "Swap:")

	local mem_total=$(echo $mem_info | awk '{print $2}')
	local mem_used=$(echo $mem_info | awk '{print $3}')
	local mem_buff=$(echo $mem_info | awk '{print $6}')
	local mem_avail=$(echo $mem_info | awk '{print $7}')
	local swap_used=$(echo $swap_info | awk '{print $3}')

	echo "--- Memory Report ---"
	echo "RAM Total:	$mem_total MB"
	echo "RAM Available:	$mem_avail MB"
	echo "RAM Used:	$mem_used MB"
	echo "RAM Cached:	$mem_buff MB"
	echo "Swap Used:	$swap_used MB"
	echo "---------------------"
}

clear_cache() {
	echo "Clearing RAM cache..."
	# Sync to flush file system buffers before clearing cache
	sync

	# Clear page cache, dentries, and inodes
	sudo sh -c "echo 3 > '/proc/sys/vm/drop_caches'"
	echo "=== RAM cache cleared ==="
}

# @brief Flushes swap by disabling and enabling it
clear_swap() {
	echo "Clearing Swap..."
	sudo swapoff -a
	echo "Swap disabled."
	sudo swapon -a
	echo "Swap enabled."
	echo "=== Swap Cleared ==="
}

# Flag to track if any operation was performed
changed=false

echo "Initial status:"
show_memory

# User prompt for Cache
read -p "Do you want to clear RAM cache? (y/n): "
if [[ $REPLY =~ ^[Yy]$ ]]; then
	clear_cache
	changed=true
fi

# User prompt for Swap
read -p "Do you want to clear Swap? (y/n): "
if [[ $REPLY =~ ^[Yy]$ ]]; then
	clear_swap
	changed=true
fi

# Only show final status if something was modified
if [ "$changed" = true ]; then
	echo -e "\nFinal system status (after changes):"
	show_memory
else
	echo -e "\nNo operations performed."
fi

echo "Press any key to continue..."

read -n 1 -s
