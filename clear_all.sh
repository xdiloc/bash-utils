#!/bin/bash

# Проверяет существование директории перед выполнением действий
check_directory() {
	local dir_path="$1"
	if [ -z "$dir_path" ] || [ ! -d "$dir_path" ]; then
		echo "Directory $dir_path not found."
		return 1
	fi
	return 0
}

# Подтверждение действия пользователем
confirm_action() {
	local CONT
	read -p "Continue (y/n)? " CONT
	if [[ "$CONT" =~ ^[yY]$ ]]; then
		return 0
	fi
	echo "Cancelled"
	return 1
}

# Очистка кэша пакетов APT
clean_apt_cache() {
	echo -e "\n=== cache deb ===";
	confirm_action || return
	sudo apt-get autoclean -y
	sudo apt-get autoremove -y
	sudo apt-get clean -y
}

# Очистка системных логов и логов сессии
clean_logs() {
	echo -e "\n=== log list ===";

	local LOG_PATTERNS=( -name "*.0" -o -name "*.1" -o -name "*.xz" -o -name "*.gz" -o -name "*.old" )

	echo -e "\nscan $HOME/";
	find "$HOME/" -maxdepth 1 \( -name '.xsession-errors' -o -name '.xsession-errors.old' \)

	echo -e "\nscan /var/log/";
	sudo find /var/log/ -type f \( "${LOG_PATTERNS[@]}" -o -name "*.log" \)

	confirm_action || return

	echo -e "\nclear $HOME/";
	# Обнуление пользовательских логов сессии без удаления файлов
	find "$HOME/" -maxdepth 1 \( -name '.xsession-errors' -o -name '.xsession-errors.old' \) -delete

	echo -e "\nclear /var/log/";
	# Удаление архивных и сжатых логов
	sudo find /var/log/ -type f \( "${LOG_PATTERNS[@]}" \) -delete
	# Обнуление активных .log файлов
	sudo find /var/log/ -type f -name "*.log" -exec truncate -s 0 -- {} +
}

# Очистка журнала systemd
clean_journal() {
	echo -e "\n=== journalctl ===";

	echo -e "\nJournal usage:";
	sudo journalctl --disk-usage

	confirm_action || return

	# Ротация логов, чтобы текущие логи стали архивными и подлежали удалению
	sudo journalctl --rotate
	# Очистка архивных логов
	sudo journalctl --vacuum-time=5m

	echo -e "\nJournal usage:";
	sudo journalctl --disk-usage
}

# Рекурсивное удаление пользовательского кэша
clean_user_cache() {
	echo -e "\n=== cache list ===";
	local CACHE_DIR="$HOME/.cache"

	check_directory "$CACHE_DIR" || return

	echo -e "\nscan $CACHE_DIR/";
	find -- "$CACHE_DIR/" -mindepth 1 -maxdepth 1 -name '*'

	confirm_action || return

	echo -e "\nclear $CACHE_DIR/";
	find -- "$CACHE_DIR/" -mindepth 1 -depth -delete
}

# Очищает файлы истории команд root.
clean_root_history() {
	echo -e "\n=== root history ==="
	local ROOT_DIR="/root"

	check_directory "$ROOT_DIR" || return

	echo "$ROOT_DIR/.history"
	echo "$ROOT_DIR/.bash_history"

	confirm_action || return

	# Использует truncate для обнуления.
	[ -f "$ROOT_DIR/.history" ] && sudo truncate -s 0 -- "$ROOT_DIR/.history"
	[ -f "$ROOT_DIR/.bash_history" ] && sudo truncate -s 0 -- "$ROOT_DIR/.bash_history"
}

echo "User: $(id -un)"
echo "Home: $HOME"
echo 'plese enter sudo password...';

if sudo -v; then
	clean_apt_cache
	clean_logs
	clean_journal
	clean_user_cache
	clean_root_history
else
	echo "no access..."
fi

sudo -k
echo -e "\n=== Cleared ===";
echo "Press any key to continue..."
read -n 1 -s
