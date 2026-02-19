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
	echo -e "\nContinue (y/n)?"
	read -r -n 1 CONT
	if [ "$CONT" = "y" ] || [ "$CONT" = "Y" ]; then
		return 0
	else
		echo -e "\nCancelled"
		return 1
	fi
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

	CUR_USER=$(id -un)
	LOG_PATTERNS=( -name "*.0" -o -name "*.1" -o -name "*.xz" -o -name "*.gz" -o -name "*.log" -o -name "*.old" )

	echo -e "\nscan /home/$CUR_USER/";
	find "/home/$CUR_USER/" -maxdepth 1 \( -name '.xsession-errors' -o -name '.xsession-errors.old' \)

	echo -e "\nscan /var/log/";
	sudo find /var/log/ -type f \( "${LOG_PATTERNS[@]}" \)

	confirm_action || return

	echo -e "\nclear /home/$CUR_USER/";
	find "/home/$CUR_USER/" -maxdepth 1 \( -name '.xsession-errors' -o -name '.xsession-errors.old' \) -delete

	echo -e "\nclear /var/log/";
	sudo find /var/log/ -type f \( "${LOG_PATTERNS[@]}" \) -delete
}

# Очистка журнала systemd
clean_journal() {
	echo -e "\n=== journalctl ===";

	echo -e "\nJournal usage:";
	sudo journalctl --disk-usage

	confirm_action || return

	# Ротация логов, чтобы текущие логи стали архивными и подлежали удалению
	sudo journalctl --rotate
	# Очистка всех архивных логов старше 1 секунды
	sudo journalctl --vacuum-time=1s

	echo -e "\nJournal usage:";
	sudo journalctl --disk-usage
}

# Рекурсивное удаление пользовательского кэша
clean_user_cache() {
	echo -e "\n=== cache list ===";
	CUR_USER=$(id -un)
	CACHE_DIR="/home/$CUR_USER/.cache"

	check_directory "$CACHE_DIR" || return

	echo -e "\nscan $CACHE_DIR/";
	find -- "$CACHE_DIR/" -mindepth 1 -maxdepth 1 -name '*'

	confirm_action || return

	echo -e "\nclear $CACHE_DIR/";
	find -- "$CACHE_DIR/" -mindepth 1 -depth -delete
}

# Удаление истории команд суперпользователя
clean_root_history() {
	echo -e "\n=== root history ==="
	ROOT_DIR="/root"

	check_directory "$ROOT_DIR" || return

	echo "$ROOT_DIR/.history"
	echo "$ROOT_DIR/.bash_history"

	confirm_action || return

	sudo rm -f -- "$ROOT_DIR/.history" "$ROOT_DIR/.bash_history"
}

echo "Hello $(id -un)"
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
