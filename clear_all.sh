#!/bin/bash

# Очистка кэша пакетов APT
clean_apt_cache() {
	echo -e "\n=== cache deb ===";
	echo -e "\nContinue clear (y/n)?";
	read CONT
	if [ "$CONT" = "y" ]; then
		sudo apt-get autoclean
		sudo apt-get autoremove
		sudo apt-get clean
	fi
}

# Очистка системных логов и логов сессии
clean_logs() {
	echo -e "\n=== log list ===";

	CUR_USER=$(whoami)
	LOG_PATTERNS=( -name "*.0" -o -name "*.1" -o -name "*.gz" -o -name "*.log" -o -name "*.old" )

	echo -e "\nscan /home/$CUR_USER/";
	find "/home/$CUR_USER/" -maxdepth 1 \( -name '.xsession-errors' -o -name '.xsession-errors.old' \)

	echo -e "\nscan /var/log/";
	sudo find /var/log/ -type f \( "${LOG_PATTERNS[@]}" \)

	echo -e "\nContinue clear (y/n)?";
	read CONT
	if [ "$CONT" = "y" ]; then
		echo -e "\nclear /home/$CUR_USER/";
		find "/home/$CUR_USER/" -maxdepth 1 -name '.xsession-errors'  -delete
		find "/home/$CUR_USER/" -maxdepth 1 -name '.xsession-errors.old' -delete

		echo -e "\nclear /var/log/";
		# Очистка системного журнала (journald)
		sudo journalctl --vacuum-time=1s

		sudo find /var/log/ -type f \( "${LOG_PATTERNS[@]}" \) -delete
	fi
}

# Рекурсивное удаление пользовательского кэша
clean_user_cache() {
	echo -e "\n=== cache list ===";
	CUR_USER=$(whoami)

	echo -e "\nscan /home/$CUR_USER/.cache/";
	find "/home/$CUR_USER/.cache/" -mindepth 1 -maxdepth 1 -name '*'

	echo -e "\nContinue clear (y/n)?";
	read CONT
	if [ "$CONT" = "y" ]; then
		echo -e "\nclear /home/$CUR_USER/.cache/";
		find "/home/$CUR_USER/.cache/" -mindepth 1 -delete
	fi
}

# Удаление истории команд суперпользователя
clean_root_history() {
	echo -e "\n=== root history ==="
	echo "/root/.history"
	echo "/root/.bash_history"

	echo -e "\nContinue clear (y/n)?";
	read CONT
	if [ "$CONT" = "y" ]; then
		sudo rm -f /root/.history /root/.bash_history
	fi
}

echo 'Hello '$(whoami);
echo 'plese enter sudo password...';

if sudo -v; then
	clean_apt_cache
	clean_logs
	clean_user_cache
	clean_root_history
else
	echo "No password"
fi

sudo -k
echo -e "\n=== Cleared ===";
echo "Press any key to continue..."
read -n 1 -s
