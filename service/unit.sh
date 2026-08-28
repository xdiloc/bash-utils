#!/bin/bash

# @brief Переключатель состояния сервиса
# SERVICE - имя юнита systemd
# EDITOR - редактор для изменения unit-файла (vim nano micro)
# systemctl list-unit-files --type=service --all --no-pager

SERVICE="$1"
EDITOR="micro"

# Проверка на пустой аргумент
if [[ -z "$SERVICE" ]]; then
	echo -e "\033[0;31mОшибка: не указано имя сервиса.\033[0m"
	echo "Использование: ./unit <имя_сервиса>"
	exit 1
fi

# Цвета
ORANGE='\033[38;5;208m'
RED='\033[0;31m'
GREEN='\033[0;32m'
GRAY='\033[0;90m'
NC='\033[0m' # No Color

# @brief Проверка состояния сервиса
check_status() {
	if systemctl is-active --quiet "$SERVICE"; then
		echo -e "Статус сервиса ${ORANGE}$SERVICE${NC}: ${GREEN}включен${NC}"
	else
		echo -e "Статус сервиса ${ORANGE}$SERVICE${NC}: ${GRAY}отключен${NC}"
	fi
	local path
	path=$(systemctl show -p FragmentPath --value "$SERVICE.service")
	if [[ -n "$path" ]]; then
		echo -e "Путь: ${GRAY}$path${NC}"
	else
		echo -e "Путь: ${GRAY}не создан${NC}"
	fi
}

# @brief Проверка существования юнита в системе
check_exists() {
	if [[ "$(systemctl show -p LoadState --value "$SERVICE.service")" != "loaded" ]]; then
		echo -e "${RED}Ошибка: сервис $SERVICE не найден в системе.${NC}"
		exit 1
	fi
}

# @brief Определение пути к файлу (существующему или новому)
resolve_path() {
	local path
	path=$(systemctl show -p FragmentPath --value "$SERVICE.service")
	if [[ -z "$path" ]]; then
		# Если файла нет, предлагаем путь по умолчанию
		UNIT_PATH="/etc/systemd/system/$SERVICE.service"
	else
		UNIT_PATH="$path"
	fi
}

# @brief Запуск сервиса
start_service() {
	check_exists
	sudo systemctl start "$SERVICE"
	sudo systemctl enable "$SERVICE"
	echo "$SERVICE: ON"
}

# @brief Остановка сервиса
stop_service() {
	check_exists
	sudo systemctl stop "$SERVICE"
	sudo systemctl disable "$SERVICE"
	echo "$SERVICE: OFF"
}

# @brief Перезапуск сервиса
restart_service() {
	check_exists
	sudo systemctl restart "$SERVICE"
	echo "$SERVICE: Restarted"
}

# @brief Просмотр логов сервиса
view_logs() {
	check_exists
	echo "Выберите режим просмотра логов:"
	echo "1) В реальном времени (-f)"
	echo "2) Последние 100 записей (-n 100)"
	echo "3) Поиск по логам (-g)"
	printf "\n"
	read -p "Введите цифру: " log_choice
	printf "\n"

	case $log_choice in
		1)
			echo "Просмотр логов (нажмите Ctrl + C для выхода)..."
			sudo journalctl -u "$SERVICE" -f
			;;
		2)
			echo "Последние 100 записей:"
			sudo journalctl -u "$SERVICE" -n 100 --no-pager
			;;
		3)
			read -p "Введите паттерн для поиска: " search_term
			echo "Результаты поиска для '$search_term':"
			sudo journalctl -u "$SERVICE" --no-pager -g "$search_term"
			;;
		*)
			echo -e "${RED}Ошибка: неверный выбор${NC}"
			return
			;;
	esac
	printf "\n"
}

# @brief Проверка конфигурации юнита
# Возвращает 0 если успешно, 1 если ошибка
verify_unit() {
	resolve_path
	echo "Проверка конфигурации..."
	if ! sudo systemd-analyze verify "$UNIT_PATH" >/dev/null 2>&1; then
		echo -e "${RED}Ошибка в конфигурации. Исправьте файл перед применением.${NC}"
		return 1
	fi
	echo -e "${GREEN}Конфигурация корректна.${NC}"
	return 0
}

# @brief Просмотр содержимого unit-файла
cat_unit() {
	resolve_path
	if [[ ! -f "$UNIT_PATH" ]]; then
		echo -e "${RED}Ошибка: файл юнита не найден по пути $UNIT_PATH${NC}"
		return
	fi
	echo -e "Содержимое файла ${ORANGE}$UNIT_PATH${NC}:"
	sudo cat "$UNIT_PATH"
}

# @brief Редактирование unit-файла сервиса
edit_unit() {
	resolve_path
	if ! command -v "$EDITOR" >/dev/null 2>&1; then
		echo -e "${RED}Ошибка: редактор $EDITOR не найден в системе.${NC}"
		return
	fi

	sudo $EDITOR "$UNIT_PATH"

	# Если проверка не пройдена, завершаем работу функции
	if ! verify_unit; then
		return
	fi

	# Запрос на применение изменений
	echo "Выполнить 'systemctl daemon-reload' для обновления конфигурации? [y/N]"
	read -n 1 -r confirm
	printf "\n"

	if [[ $confirm =~ ^[Yy]$ ]]; then
		sudo systemctl daemon-reload
		echo "daemon-reload выполнен успешно."
	fi
}

# @brief Создание бекапа текущего unit-файла
backup_unit() {
	check_exists
	resolve_path
	local backup_dir="backup/$SERVICE"

	if [ ! -d "$backup_dir" ]; then
		mkdir -p "$backup_dir"
	fi

	cp "$UNIT_PATH" "$backup_dir/unit_$(date +%Y%m%d_%H%M%S)"
	echo "Бекап $SERVICE создан в $backup_dir"
}

# @brief Просмотр зависимостей сервиса
show_deps() {
	check_exists
	systemctl list-dependencies --no-pager "$SERVICE"
}

# @brief Удаление юнита (остановка, отключение, удаление файла и daemon-reload)
remove_unit() {
	resolve_path
	if [[ ! -f "$UNIT_PATH" ]]; then
		echo -e "${RED}Ошибка: файл юнита не найден по пути $UNIT_PATH${NC}"
		return
	fi

	echo -e "${RED}Внимание! Сервис $SERVICE будет полностью удален (остановлен, отключен и файл будет стерт).${NC}"
	read -p "Продолжить? [y/N]: " confirm
	if [[ ! $confirm =~ ^[Yy]$ ]]; then
		echo "Отменено."
		return
	fi

	sudo systemctl stop "$SERVICE" 2>/dev/null
	sudo systemctl disable "$SERVICE" 2>/dev/null
	sudo rm -f "$UNIT_PATH"
	sudo systemctl daemon-reload
	echo -e "${GREEN}Юнит $SERVICE успешно удален.${NC}"
}

# @brief Управление файлом юнита
manage_unit_file() {
	resolve_path
	echo "Управление файлом юнита:"
	echo "1) Посмотреть файл (cat)"
	echo "2) Отредактировать (micro)"
	echo "3) Проверить синтаксис (verify)"
	echo "4) Создать бэкап (backup)"
	echo "5) Удалить unit"
	echo "0) Назад"
	printf "\n"
	read -p "Введите цифру: " sub_choice
	printf "\n"

	case $sub_choice in
		1)
			cat_unit
			;;
		2)
			edit_unit
			;;
		3)
			verify_unit
			;;
		4)
			backup_unit
			;;
		5)
			remove_unit
			;;
		0)
			return
			;;
		*)
			echo -e "${RED}Ошибка: неверный ввод${NC}"
			;;
	esac
	printf "\n"
}

check_status
printf "\n"
echo "Выберите действие:"
echo "1) Запустить"
echo "2) Остановить"
echo "3) Перезапустить"
echo "4) Смотреть логи"
echo "5) Управление файлом юнита"
echo "6) Показать зависимости (dependencies)"
echo "0) Выход"
printf "\n"
read -p "Введите цифру: " choice
printf "\n"

case $choice in
	1)
		start_service
		;;
	2)
		stop_service
		;;
	3)
		restart_service
		;;
	4)
		view_logs
		;;
	5)
		manage_unit_file
		;;
	6)
		show_deps
		;;
	0)
		exit 0
		;;
	*)
		echo -e "${RED}Ошибка: неверный ввод${NC}"
		;;
esac

read -n 1 -s -r -p "Нажмите любую клавишу для выхода..."
printf "\n"
