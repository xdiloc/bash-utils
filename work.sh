#!/bin/bash

# @brief Переключатель состояния сервиса
# SERVICE - имя юнита systemd

SERVICE="work"

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
}

# @brief Редактирование unit-файла сервиса
edit_unit() {
	if command -v micro >/dev/null 2>&1; then
		sudo micro /etc/systemd/system/"$SERVICE".service

		# Запрос на применение изменений
		echo -e "\nПрименить изменения (выполнить daemon-reload)? [y/N]"
		read -n 1 -r confirm

		if [[ $confirm =~ ^[Yy]$ ]]; then
			sudo systemctl daemon-reload
			echo "daemon-reload выполнен успешно."
		fi
	else
		echo -e "${RED}Ошибка: редактор micro не найден в системе.${NC}"
	fi
}

check_status
echo -e "\nВыберите действие:"
echo "1) Запустить"
echo "2) Остановить"
echo "3) Перезапустить"
echo "4) Смотреть логи"
echo "5) Редактировать unit-файл"
echo "0) Выход"
read -p "Введите цифру: " choice

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
