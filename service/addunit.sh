#!/bin/bash

# @brief Создает скрипт-обертку для запуска unit-сервиса
# SERVICE_NAME - имя сервиса (например, mihomo)
# TARGET_FILE - имя создаваемого файла (например, mihomo.sh)

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
