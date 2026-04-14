#!/bin/bash
# Removes old revisions of snaps
# CLOSE ALL SNAPS BEFORE RUNNING THIS
set -eu

# Check if 'snap' command is available
if ! command -v snap > /dev/null 2>&1; then
	echo "Error: 'snap' command not found."
	exit 1
fi

# Function to clean up old revisions
cleanup_old_revisions() {
	# answer - ответ пользователя (y/n)
	# snapname - имя пакета snap
	# revision - номер ревизии пакета
	local answer
	local snapname
	local revision

	echo "Do you want to remove old revisions of snaps? (y/n): "
	read -r answer
	if [[ "$answer" != "y" && "$answer" != "Y" ]]; then
		echo "Cleanup canceled."
		return
	fi

	echo "Starting cleanup of old snap revisions..."
	# List all disabled revisions
	LANG=C snap list --all | awk '/disabled/{print $1, $3}' | while read -r snapname revision; do
		echo "Removing ${snapname} revision ${revision}..."
		if sudo snap remove "$snapname" --revision="$revision"; then
			echo "Successfully removed ${snapname} revision ${revision}"
		else
			echo "Failed to remove ${snapname} revision ${revision}" >&2
		fi
	done
	echo "Cleanup complete."
}

wait_for_key() {
	echo "Press any key to continue..."
	read -n 1 -s < /dev/tty
}

saved_data() {
	# Show current saved snap data
	echo -e "\n--- Snap Saved Data for Reference ---"
	if snap saved; then
		echo "snap saved - Show list of saved snapshots"
		echo "snap forget id - Delete snapshot"
	else
		echo "Could not retrieve snap saved data. Is it supported on this snapd version?"
	fi
	echo "-------------------------------------"
}

# Show current snap list
echo "Current snap list:"
snap list --all

# show data store
saved_data

# Run cleanup
cleanup_old_revisions

# Wait for user input before exiting
wait_for_key

