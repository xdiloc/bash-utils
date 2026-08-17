#!/bin/bash

# Цвета для консоли
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # Сброс цвета

# Подключаем файл конфигурации с пакетами и реестром
if [ -f "./packages.conf" ]; then
	source "./packages.conf"
else
	echo -e "${RED}Ошибка: файл конфигурации packages.conf не найден!${NC}"
	exit 1
fi

# @brief Приостанавливает выполнение и ожидает нажатия любой клавиши
pause() {
	echo ""
	read -n 1 -s -r -p "Нажмите любую клавишу для продолжения..."
	echo ""
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
	local status
	status=$(dpkg-query -W -f='${Status}' "$1" 2>/dev/null)
	[ "$status" = "install ok installed" ]
}

# @brief Проверяет, существует ли пакет в репозиториях
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
			echo -e "${GREEN}[✔]${NC} $pkg (установлено)"
		elif exists_in_repo "$pkg"; then
			echo -e "${YELLOW}[ ]${NC} $pkg (доступно)"
		else
			echo -e "${RED}[✘]${NC} $pkg (нет в репозитории)"
		fi
	done
	echo ""
}

# @brief Выводит в терминал детальный отчет о состоянии всех пакетов по категориям из реестра
show_system_status() {
	print_header "АНАЛИЗ СОСТОЯНИЯ ПАКЕТОВ В СИСТЕМЕ"
	echo ""

	for entry in "${CATEGORY_REGISTRY[@]}"; do
		local var_name="${entry%%|*}"
		local title="${entry#*|}"
		print_category_status "$var_name" "$title"
	done

	print_border
	pause
}

# @brief Выводит список пакетов из apt-mark showmanual за вычетом пакетов из списков установщика
show_manual_untracked() {
	print_header "РУЧНО УСТАНОВЛЕННЫЕ ПАКЕТЫ (ВНЕ СПИСКОВ)"
	echo ""

	local all_installer_pkgs=()
	for entry in "${CATEGORY_REGISTRY[@]}"; do
		local var_name="${entry%%|*}"
		local -n pkgs_ref=$var_name
		all_installer_pkgs+=("${pkgs_ref[@]}")
	done

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
	local exit_code
	choices=$(whiptail --title "$title" --checklist \
		"Установленные пакеты зафиксированы. Отметьте новые:" 20 78 10 \
		"${items[@]}" 3>&1 1>&2 2>&3)
	exit_code=$?

	[ $exit_code -ne 0 ] && return

	if [ -z "$choices" ]; then
		echo -e "${YELLOW}Ничего не выбрано.${NC}"
		pause
		return
	fi

	local to_install=()
	local raw_choices=()
	read -ra raw_choices <<< "$(echo "$choices" | xargs)"

	for pkg in "${raw_choices[@]}"; do
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

# @brief Отображает подменю выбора категорий программ для установки динамически из реестра
install_menu() {
	check_whiptail

	local menu_items=()
	for entry in "${CATEGORY_REGISTRY[@]}"; do
		local var_name="${entry%%|*}"
		local title="${entry#*|}"
		menu_items+=("$var_name" "$title")
	done

	local subchoice
	subchoice=$(whiptail --title "Разделы установки" --menu \
		"Выберите категорию:" 20 60 10 \
		"${menu_items[@]}" 3>&1 1>&2 2>&3)

	[ $? -ne 0 ] && return

	if [ -n "$subchoice" ]; then
		local title=""
		for entry in "${CATEGORY_REGISTRY[@]}"; do
			local var_name="${entry%%|*}"
			if [ "$var_name" = "$subchoice" ]; then
				title="${entry#*|}"
				break
			fi
		done
		install_packages "$subchoice" "Установка: $title"
	fi
}

# @brief Отображает главное меню управления скриптом
main_menu() {
	local choice
	while true; do
		choice=$(whiptail --title "Менеджер установки программ" --menu \
			"Выберите действие:" 17 60 4 \
			"1" "Установка пакетов" \
			"2" "Анализ состояния системы" \
			"3" "apt-mark showmanual (вне списков)" \
			"4" "Выход" 3>&1 1>&2 2>&3)

		case $choice in
			1)
				install_menu
				;;
			2)
				show_system_status
				;;
			3)
				show_manual_untracked
				;;
			4 | "")
				exit 0
				;;
			*)
				exit 0
				;;
		esac
	done
}

main_menu
