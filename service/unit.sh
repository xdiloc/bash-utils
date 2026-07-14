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

# @brief Запуск сервиса
start_service() {
	sudo systemctl start "$SERVICE"
	sudo systemctl enable "$SERVICE"
	echo "Gateway: ON"
}

# @brief Остановка сервиса
stop_service() {
	sudo systemctl stop "$SERVICE"
	sudo systemctl disable "$SERVICE"
	echo "Gateway: OFF"
}

# @brief Перезапуск сервиса
restart_service() {
	sudo systemctl restart "$SERVICE"
	echo "Gateway: Restarted"
}

# @brief Просмотр логов сервиса
view_logs() {
	echo "Просмотр логов (нажмите Ctrl + C для выхода)..."
	sudo journalctl -u "$SERVICE" -f
	printf "\n"
}

# @brief Редактирование unit-файла сервиса
edit_unit() {
	if ! command -v "$EDITOR" >/dev/null 2>&1; then
		echo -e "${RED}Ошибка: редактор $EDITOR не найден в системе.${NC}"
		return
	fi

	sudo $EDITOR /etc/systemd/system/"$SERVICE".service

	echo "Проверка конфигурации..."
	if ! sudo systemd-analyze verify /etc/systemd/system/"$SERVICE".service >/dev/null 2>&1; then
		echo -e "${RED}Ошибка в конфигурации. Исправьте файл перед применением.${NC}"
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

check_status
printf "\n"
echo "Выберите действие:"
echo "1) Запустить"
echo "2) Остановить"
echo "3) Перезапустить"
echo "4) Смотреть логи"
echo "5) Редактировать unit-файл"
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
	0)
		exit 0
		;;
	*)
		echo -e "${RED}Ошибка: неверный ввод${NC}"
		;;
esac

read -n 1 -s -r -p "Нажмите любую клавишу для выхода..."
printf "\n"
