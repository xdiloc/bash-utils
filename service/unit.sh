#!/bin/bash

# @brief Переключатель состояния сервиса
# SERVICE - имя юнита systemd
# EDITOR - редактор для изменения unit-файла (vim nano micro)

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
}

# @brief Проверка существования юнита
check_exists() {
	if ! systemctl list-unit-files "$SERVICE.service" | grep -q "$SERVICE.service"; then
		echo -e "${RED}Ошибка: сервис $SERVICE не найден в системе.${NC}"
		exit 1
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
	echo "Просмотр логов (нажмите Ctrl + C для выхода)..."
	sudo journalctl -u "$SERVICE" -f
	printf "\n"
}

# @brief Проверка конфигурации юнита
# Возвращает 0 если успешно, 1 если ошибка
verify_unit() {
	check_exists
	echo "Проверка конфигурации..."
	if ! sudo systemd-analyze verify /etc/systemd/system/"$SERVICE".service >/dev/null 2>&1; then
		echo -e "${RED}Ошибка в конфигурации. Исправьте файл перед применением.${NC}"
		return 1
	fi
	echo -e "${GREEN}Конфигурация корректна.${NC}"
	return 0
}

# @brief Редактирование unit-файла сервиса
edit_unit() {
	if ! command -v "$EDITOR" >/dev/null 2>&1; then
		echo -e "${RED}Ошибка: редактор $EDITOR не найден в системе.${NC}"
		return
	fi

	sudo $EDITOR /etc/systemd/system/"$SERVICE".service

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
	local backup_dir="backup/$SERVICE"

	if [ ! -d "$backup_dir" ]; then
		mkdir -p "$backup_dir"
	fi

	cp /etc/systemd/system/"$SERVICE".service "$backup_dir/unit_$(date +%Y%m%d_%H%M%S)"
	echo "Бекап $SERVICE создан в $backup_dir"
}

# @brief Просмотр зависимостей сервиса
show_deps() {
	check_exists
	systemctl list-dependencies --no-pager "$SERVICE"
}

check_status
printf "\n"
echo "Выберите действие:"
echo "1) Запустить"
echo "2) Остановить"
echo "3) Перезапустить"
echo "4) Смотреть логи"
echo "5) Редактировать unit-файл"
echo "6) Проверить конфигурацию"
echo "7) Создать резервную копию"
echo "8) Показать зависимости (dependencies)"
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
		edit_unit
		;;
	6)
		verify_unit
		;;
	7)
		backup_unit
		;;
	8)
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
