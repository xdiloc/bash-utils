#!/bin/bash

nogui_pkgs=(nethogs net-tools tcpdump btop htop iotop micro bat tree cmatrix whois wget ntfs-3g lm-sensors)
gui_pkgs=(gtkhash sqlitebrowser qbittorrent ghex flameshot)
graphics_pkgs=(webp webp-pixbuf-loader inkscape)
disk_pkgs=(smartmontools gparted gnome-disk-utility)
theme_pkgs=(orchis-gtk-theme yaru-theme-gtk yaru-theme-icon mate-themes mate-tweak)

# @brief Приостанавливает выполнение и ожидает нажатия клавиши Enter
pause() {
	echo ""
	read -p "Нажмите Enter для продолжения..."
}

# @brief Проверяет, установлен ли пакет в системе
# pkg - имя пакета
is_installed() {
	[ "$(dpkg-query -W -f='${Status}' "$1" 2>/dev/null)" = "install ok installed" ]
}

# @brief Выводит в терминал детальный отчет о состоянии всех пакетов по категориям
show_system_status() {
	echo "=================================================="
	echo "       АНАЛИЗ СОСТОЯНИЯ ПАКЕТОВ В СИСТЕМЕ         "
	echo "=================================================="
	echo ""

	print_category_status() {
		local -n pkgs_arr=$1
		local cat_name=$2

		echo "[$cat_name]"
		for pkg in "${pkgs_arr[@]}"; do
			if is_installed "$pkg"; then
				echo "  [✔] $pkg (установлено)"
			else
				echo "  [ ] $pkg (отсутствует)"
			fi
		done
		echo ""
	}

	print_category_status nogui_pkgs "Консольные утилиты (NoGUI)"
	print_category_status gui_pkgs "Графические приложения (GUI)"
	print_category_status graphics_pkgs "Графика и мультимедиа"
	print_category_status disk_pkgs "Утилиты для дисков"
	print_category_status theme_pkgs "Темы оформления"

	echo "=================================================="
	pause
}

# @brief Обрабатывает выбор пакетов, проверяет наличие в системе и передает список на установку в apt
# pkgs_ref - ссылка на массив пакетов категории
# title - заголовок окна диалога
install_packages() {
	local -n pkgs_ref=$1
	local title=$2

	local items=()
	for pkg in "${pkgs_ref[@]}"; do
		if is_installed "$pkg"; then
			items+=("$pkg" "(установлено)" "ON")
		else
			items+=("$pkg" "" "OFF")
		fi
	done

	# Проверка наличия обязательной утилиты whiptail для работы интерфейса
	if ! command -v whiptail &> /dev/null; then
		echo "Для работы графического интерфейса необходима утилита whiptail."
		echo "Утилита whiptail не найдена, выполняется установка..."
		sudo apt install -y whiptail
	fi

	# Повторная проверка после попытки установки
	if ! command -v whiptail &> /dev/null; then
		echo "Ошибка: не удалось установить whiptail. Продолжение работы невозможно."
		pause
		return 1
	fi

	local choices
	choices=$(whiptail --title "$title" --checklist \
		"Установленные пакеты зафиксированы. Отметьте новые:" 20 78 10 \
		"${items[@]}" 3>&1 1>&2 2>&3)

	[ $? -ne 0 ] && return

	choices=$(echo "$choices" | tr -d '"')
	if [ -z "$choices" ]; then
		echo "Ничего не выбрано."
		pause
		return
	fi

	local to_install=()
	for pkg in $choices; do
		if ! is_installed "$pkg"; then
			to_install+=("$pkg")
		fi
	done

	if [ ${#to_install[@]} -eq 0 ]; then
		echo "нет задач"
		pause
		return
	fi

	echo "Будет установлено:"
	for pkg in "${to_install[@]}"; do
		echo " - $pkg"
	done
	echo ""

	sudo apt install "${to_install[@]}"
	pause
}

# @brief Отображает главное меню управления скриптом
main_menu() {
	while true; do
		CHOICE=$(whiptail --title "Менеджер установки программ" --menu \
			"Выберите действие:" 16 60 3 \
			"1" "Установка пакетов" \
			"2" "Анализ состояния системы" \
			"3" "Выход" 3>&1 1>&2 2>&3)

		case $CHOICE in
			1)
				# Подменю выбора категории программ
				SUBCHOICE=$(whiptail --title "Разделы установки" --menu \
					"Выберите категорию:" 16 60 5 \
					"nogui" "Консольные утилиты (NoGUI)" \
					"gui" "Графические приложения (GUI)" \
					"graphics" "Графика и мультимедиа" \
					"disk" "Работа с дисками (Disk Utils)" \
					"theme" "Темы оформления (Themes)" 3>&1 1>&2 2>&3)

				case $SUBCHOICE in
					nogui)
						install_packages nogui_pkgs "Установка NoGUI программ"
						;;
					gui)
						install_packages gui_pkgs "Установка GUI программ"
						;;
					graphics)
						install_packages graphics_pkgs "Установка графических утилит"
						;;
					disk)
						install_packages disk_pkgs "Утилиты для дисков"
						;;
					theme)
						install_packages theme_pkgs "Установка тем оформления"
						;;
				esac
				;;
			2)
				show_system_status
				;;
			3)
				exit 0
				;;
			*)
				exit 0
				;;
		esac
	done
}

main_menu
