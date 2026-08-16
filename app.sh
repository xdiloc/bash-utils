#!/bin/bash

nogui_pkgs=(nethogs net-tools tcpdump btop htop iotop micro bat tree cmatrix whois curl wget ntfs-3g lm-sensors bash-completion)
gui_pkgs=(caja-actions caja-seahorse gtkhash jstest-gtk sqlitebrowser qbittorrent ghex dconf-editor)
graphics_pkgs=(minder flameshot fonts-noto-color-emoji webp webp-pixbuf-loader gimp inkscape)
disk_pkgs=(smartmontools gparted gnome-disk-utility)
theme_pkgs=(orchis-gtk-theme yaru-theme-gtk yaru-theme-icon mate-themes mate-tweak ayatana-settings)
media_pkgs=(celluloid audacity obs-studio)
problem_pkgs=(carla calf-plugins)
hardware_pkgs=(cpu-x hardinfo mangohud vulkan-tools lshw lshw-gtk stress-ng)
dev_pkgs=(git make valac pluma-plugin-quickhighlight pluma-plugin-terminal)

# Цвета для консоли
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # Сброс цвета

# @brief Приостанавливает выполнение, выводит пустую строку перед и ожидает нажатия клавиши Enter
pause() {
	echo ""
	read -p "Нажмите Enter для продолжения..."
}

# @brief Выводит горизонтальную линию рамки
print_border() {
	local width=46
	local border
	printf -v border '%*s' "$width" ""
	border="${border// /=}"
	echo -e "${BLUE}$border${NC}"
}

# @brief Выводит центрированный заголовок в рамке из знаков равно
# text - текст заголовка
print_header() {
	local text="$1"
	local width=46
	local len=${#text}
	local left_pad=$(( (width - len) / 2 ))
	[ $left_pad -lt 0 ] && left_pad=0

	print_border
	printf "${BLUE}%*s%s${NC}\n" $left_pad "" "$text"
	print_border
}

# @brief Проверяет, установлен ли пакет в системе
# pkg - имя пакета
is_installed() {
	[ "$(dpkg-query -W -f='${Status}' "$1" 2>/dev/null)" = "install ok installed" ]
}

# @brief Проверяет, существует ли пакет в репозиториях (без использования grep)
# pkg - имя пакета
exists_in_repo() {
	local policy
	policy=$(LC_ALL=C apt-cache --quiet=2 policy "$1")
	[[ "$policy" == *"Candidate:"* && "$policy" != *"Candidate: (none)"* ]]
}

# @brief Проверяет наличие утилиты whiptail и при необходимости устанавливает её
check_whiptail() {
	if ! command -v whiptail &> /dev/null; then
		echo -e "${YELLOW}Для работы графического интерфейса необходима утилита whiptail.${NC}"
		echo -e "${YELLOW}Утилита whiptail не найдена, выполняется установка...${NC}"
		sudo apt install -y whiptail
	fi

	if ! command -v whiptail &> /dev/null; then
		echo -e "${RED}Ошибка: не удалось установить whiptail. Продолжение работы невозможно.${NC}"
		pause
		exit 1
	fi
}

# @brief Выводит в терминал статус пакетов заданной категории
# pkgs_arr - ссылка на массив пакетов
# cat_name - название категории
print_category_status() {
	local -n pkgs_arr=$1
	local cat_name=$2

	echo -e "${BLUE}[$cat_name]${NC}"
	for pkg in "${pkgs_arr[@]}"; do
		if is_installed "$pkg"; then
			echo -e "  ${GREEN}[✔]${NC} $pkg (установлено)"
		elif exists_in_repo "$pkg"; then
			echo -e "  ${YELLOW}[ ]${NC} $pkg (доступно)"
		else
			echo -e "  ${RED}[✘]${NC} $pkg (нет в репозитории)"
		fi
	done
	echo ""
}

# @brief Выводит в терминал детальный отчет о состоянии всех пакетов по категориям
show_system_status() {
	print_header "АНАЛИЗ СОСТОЯНИЯ ПАКЕТОВ В СИСТЕМЕ"
	echo ""

	print_category_status nogui_pkgs "Консольные утилиты (NoGUI)"
	print_category_status gui_pkgs "Графические приложения (GUI)"
	print_category_status graphics_pkgs "Графика и мультимедиа"
	print_category_status disk_pkgs "Утилиты для дисков"
	print_category_status theme_pkgs "Темы оформления"
	print_category_status media_pkgs "Аудио и видео"
	print_category_status problem_pkgs "Проблемные пакеты с багом"
	print_category_status hardware_pkgs "Информация о железе"
	print_category_status dev_pkgs "Разработка"

	print_border

	pause
}

# @brief Выводит список пакетов из apt-mark showmanual за вычетом пакетов из списков установщика
show_manual_untracked() {
	print_header "РУЧНО УСТАНОВЛЕННЫЕ ПАКЕТЫ (ВНЕ СПИСКОВ)"
	echo ""

	local all_installer_pkgs=(
		"${nogui_pkgs[@]}"
		"${gui_pkgs[@]}"
		"${graphics_pkgs[@]}"
		"${disk_pkgs[@]}"
		"${theme_pkgs[@]}"
		"${media_pkgs[@]}"
		"${problem_pkgs[@]}"
		"${hardware_pkgs[@]}"
		"${dev_pkgs[@]}"
	)

	comm -23 \
		<(apt-mark showmanual | sort) \
		<(printf '%s\n' "${all_installer_pkgs[@]}" | sort -u)

	echo ""
	print_border

	pause
}

# @brief Обрабатывает выбор пакетов, проверяет наличие в системе и передает список на установку в apt
# pkgs_ref - ссылка на массив пакетов категории
# title - заголовок окна диалога
install_packages() {
	local -n pkgs_ref=$1
	local title=$2

	check_whiptail

	local items=()
	for pkg in "${pkgs_ref[@]}"; do
		if is_installed "$pkg"; then
			items+=("$pkg" "(установлено)" "ON")
		elif exists_in_repo "$pkg"; then
			items+=("$pkg" "(доступно)" "OFF")
		else
			items+=("$pkg" "(нет в репозитории)" "OFF")
		fi
	done

	local choices
	choices=$(whiptail --title "$title" --checklist \
		"Установленные пакеты зафиксированы. Отметьте новые:" 20 78 10 \
		"${items[@]}" 3>&1 1>&2 2>&3)

	[ $? -ne 0 ] && return

	choices=$(echo "$choices" | tr -d '"')
	if [ -z "$choices" ]; then
		echo -e "${YELLOW}Ничего не выбрано.${NC}"
		pause
		return
	fi

	local to_install=()
	for pkg in $choices; do
		if ! is_installed "$pkg"; then
			if exists_in_repo "$pkg"; then
				to_install+=("$pkg")
			else
				echo -e "${RED}Предупреждение: пакет '$pkg' отсутствует в репозиториях и пропущен.${NC}"
			fi
		fi
	done

	if [ ${#to_install[@]} -eq 0 ]; then
		echo -e "${YELLOW}В разделе «$title» нет задач.${NC}"
		pause
		return
	fi

	echo -e "${GREEN}Будет установлено:${NC}"
	for pkg in "${to_install[@]}"; do
		echo -e " - ${GREEN}$pkg${NC}"
	done
	echo ""

	sudo apt install "${to_install[@]}"
	pause
}

# @brief Отображает подменю выбора категорий программ для установки
install_menu() {
	check_whiptail

	local SUBCHOICE
	SUBCHOICE=$(whiptail --title "Разделы установки" --menu \
		"Выберите категорию:" 20 60 9 \
		"nogui" "Консольные утилиты (NoGUI)" \
		"gui" "Графические приложения (GUI)" \
		"graphics" "Графика и мультимедиа" \
		"disk" "Работа с дисками (Disk Utils)" \
		"theme" "Темы оформления (Themes)" \
		"media" "Аудио и видео (Media)" \
		"problem" "Проблемные пакеты с багом" \
		"hardware" "Информация о железе (Hardware)" \
		"dev" "Разработка" 3>&1 1>&2 2>&3)

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
		media)
			install_packages media_pkgs "Установка аудио и видео программ"
			;;
		problem)
			install_packages problem_pkgs "Установка проблемных пакетов"
			;;
		hardware)
			install_packages hardware_pkgs "Установка утилит для железа"
			;;
		dev)
			install_packages dev_pkgs "Установка средств разработки"
			;;
	esac
}

# @brief Отображает главное меню управления скриптом
main_menu() {
	while true; do
		CHOICE=$(whiptail --title "Менеджер установки программ" --menu \
			"Выберите действие:" 17 60 4 \
			"1" "Установка пакетов" \
			"2" "Анализ состояния системы" \
			"3" "apt-mark showmanual (вне списков)" \
			"4" "Выход" 3>&1 1>&2 2>&3)

		case $CHOICE in
			1)
				install_menu
				;;
			2)
				show_system_status
				;;
			3)
				show_manual_untracked
				;;
			4)
				exit 0
				;;
			*)
				exit 0
				;;
		esac
	done
}

main_menu
