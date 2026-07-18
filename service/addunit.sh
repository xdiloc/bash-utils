#!/bin/bash

# @brief Создает скрипт-обертку для запуска unit-сервиса
# SERVICE_NAME - имя сервиса (например, mihomo)
# TARGET_FILE - имя создаваемого файла (например, mihomo.sh)
create_wrapper() {
	SERVICE_NAME="$1"
	TARGET_FILE="${SERVICE_NAME}.sh"

	# Проверка аргумента
	if [[ -z "$SERVICE_NAME" ]]; then
		echo "Ошибка: не указано имя сервиса."
		echo "Использование: ./addunit.sh <имя_сервиса>"
		exit 1
	fi

	# Проверка на существование файла
	if [[ -f "$TARGET_FILE" ]]; then
		echo "Ошибка: файл $TARGET_FILE уже существует."
		exit 1
	fi

	# Создание файла с содержимым
	cat <<EOF > "$TARGET_FILE"
#!/bin/bash
./unit.sh $SERVICE_NAME
EOF

	# Установка прав на исполнение
	chmod +x "$TARGET_FILE"

	echo "Файл $TARGET_FILE успешно создан для сервиса $SERVICE_NAME."
}

# @brief Получает список юнитов и выводит интерактивное меню
list_units() {
	local services
	# Загружаем список сервисов
	mapfile -t services < <(systemctl list-unit-files --type=service --no-legend --no-pager | awk '{print $1}' | sed 's/\.service$//')

	PS3="Выберите номер сервиса (или 'q' для выхода): "
	select service in "${services[@]}"; do
		# Проверяем, ввел ли пользователь q до того, как select обработает ввод
		if [[ "$REPLY" == "q" ]]; then
			echo "Выход."
			exit 0
		fi

		# Если выбор корректный
		if [[ -n "$service" ]]; then
			create_wrapper "$service"
			break
		else
			echo "Неверный выбор."
		fi
	done
}

# Основная логика
if [[ -n "$1" ]]; then
	create_wrapper "$1"
else
	list_units
fi
