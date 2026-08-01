#!/usr/bin/env bash

# Глобальные переменные для цветового оформления
RED="\033[31m"
GREEN="\033[32m"
RESET="\033[0m"

# @brief Создает целевую директорию для ISO-образов в домашней директории, если она не существует
# p_dir - путь к создаваемой директории
create_iso_directory() {
	local p_dir="$1"
	[ -d "$p_dir" ] && return 0
	mkdir -p "$p_dir"
}

# @brief Определяет имя актуального netinst ISO-образа Debian с удаленного сервера
# p_url - URL страницы загрузки
get_latest_iso_name() {
	local p_url="$1"
	local html_content
	html_content=$(curl -sL "$p_url")
	echo "$html_content" | grep -oP 'href="debian-[^"]+-amd64-netinst\.iso"' | head -n 1 | cut -d'"' -f2
}

# @brief Скачивает файл контрольных сумм с перезаписью через curl
# p_url - базовый URL репозитория
# p_dir - целевая директория
download_checksums() {
	local p_url="$1"
	local p_dir="$2"
	curl -s -L -o "$p_dir/SHA256SUMS" "${p_url}/SHA256SUMS"
}

# @brief Скачивает файл цифровой подписи SHA256SUMS.sign с перезаписью через curl
# p_url - базовый URL репозитория
# p_dir - целевая директория
download_signature() {
	local p_url="$1"
	local p_dir="$2"
	curl -s -L -o "$p_dir/SHA256SUMS.sign" "${p_url}/SHA256SUMS.sign"
}

# @brief Всегда проверяет доступность ключа на сервере и при необходимости импортирует его
# p_dir - директория, где лежит SHA256SUMS.sign
ensure_gpg_key() {
	local p_dir="$1"
	local key_id
	local key_fpr

	# Извлекаем чистый отпечаток и ID ключа, удаляя лишние символы и скобки
	key_fpr=$(gpg --list-packets "$p_dir/SHA256SUMS.sign" 2>/dev/null | awk '/issuer fpr/{print $NF; exit}' | tr -cd 'A-Fa-f0-9')
	key_id=$(gpg --list-packets "$p_dir/SHA256SUMS.sign" 2>/dev/null | awk '/keyid/{print $NF; exit}' | tr -cd 'A-Fa-f0-9')

	if [ -z "$key_id" ]; then
		echo "Ошибка: не удалось извлечь ключ из SHA256SUMS.sign"
		return 1
	fi

	local search_query="${key_fpr:-$key_id}"
	local server_available=false

	echo " Проверка доступности ключа $key_id на серверах:"
	for server in "https://keys.openpgp.org" "https://keyserver.ubuntu.com"; do
		echo -n "   -> Проверка на $server ... "
		local http_code
		http_code=$(curl -o /dev/null -s -w "%{http_code}\n" "${server}/pks/lookup?op=index&search=0x${search_query}")
		if [ "$http_code" -eq 200 ]; then
			echo -e "${GREEN}[OK]${RESET}"
			server_available=true
		else
			echo -e "${RED}[FAIL]${RESET} (HTTP: $http_code)"
		fi
	done

	if [ "$server_available" = false ]; then
		echo "Предупреждение: ключ не подтвержден ни на одном из серверов."
	fi

	if gpg --list-keys "$key_id" >/dev/null 2>&1; then
		return 0
	fi

	echo " Ключ отсутствует локально. Запуск загрузки через curl:"
	for server in "https://keys.openpgp.org" "https://keyserver.ubuntu.com"; do
		echo -n "   -> Загрузка с сервера: $server ... "
		if curl -s "${server}/pks/lookup?op=get&search=0x${search_query}" | gpg --import >/dev/null 2>&1; then
			if gpg --list-keys "$key_id" >/dev/null 2>&1; then
				echo -e "${GREEN}[OK]${RESET}"
				return 0
			fi
		fi
		echo -e "${RED}[FAIL]${RESET}"
	done
	return 1
}

# @brief Проверяет GPG-подпись файла контрольных сумм
# p_dir - директория, где лежат SHA256SUMS и SHA256SUMS.sign
verify_signature() {
	local p_dir="$1"
	(cd "$p_dir" && gpg --verify SHA256SUMS.sign SHA256SUMS)
}

# @brief Проверяет целостность существующего ISO-образа по SHA256
# p_iso - полный путь к проверяемому файлу ISO
# p_dir - директория, где лежит файл и SHA256SUMS
verify_checksum() {
	local p_iso="$1"
	local p_dir="$2"
	local iso_base
	iso_base=$(basename "$p_iso")
	(cd "$p_dir" && grep "$iso_base" SHA256SUMS | sha256sum --check --ignore-missing --status)
}

# @brief Скачивает ISO-образ с отображением прогресс-бара через curl
# p_url - базовый URL репозитория
# p_iso - имя файла ISO-образа
# p_dir - целевая директория
download_iso() {
	local p_url="$1"
	local p_iso="$2"
	local p_dir="$3"
	curl -# -L -o "$p_dir/$p_iso" "${p_url}/${p_iso}"
}

# @brief Основная логика выполнения скрипта
getdeb() {
	local iso_dir="$HOME/iso"
	local base_url="https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/"
	local iso_name
	local iso_path

	echo -n "Проверка и подготовка директории ($iso_dir)... "
	create_iso_directory "$iso_dir"
	echo -e "${GREEN}[OK]${RESET}"

	echo -n "Определение актуального релиза Debian... "
	iso_name=$(get_latest_iso_name "$base_url")

	if [ -z "$iso_name" ]; then
		echo -e "${RED}[FAIL]${RESET}"
		echo "Ошибка: не удалось определить свежий релиз ISO."
		return 1
	fi
	echo -e "${GREEN}[OK]${RESET} ($iso_name)"

	iso_path="$iso_dir/$iso_name"

	echo -n "Загрузка файла контрольных сумм... "
	if ! download_checksums "$base_url" "$iso_dir"; then
		echo -e "${RED}[FAIL]${RESET}"
		return 1
	else
		echo -e "${GREEN}[OK]${RESET}"
	fi

	echo -n "Загрузка файла цифровой подписи... "
	if ! download_signature "$base_url" "$iso_dir"; then
		echo -e "${RED}[FAIL]${RESET}"
		return 1
	else
		echo -e "${GREEN}[OK]${RESET}"
	fi

	echo "Проверка наличия GPG-ключа..."
	if ! ensure_gpg_key "$iso_dir"; then
		echo -e "${RED}[FAIL]${RESET}"
		echo "Ошибка: не удалось загрузить GPG-ключ Debian ни с одного из серверов."
		return 1
	fi
	echo -e "Статус GPG-ключа: ${GREEN}[OK]${RESET}"

	echo "Проверка GPG-подписи файла контрольных сумм:"
	if verify_signature "$iso_dir"; then
		echo -e "Статус проверки подписи: ${GREEN}[OK]${RESET}"
	else
		echo -e "${RED}[FAIL]${RESET}"
		echo "Ошибка: цифровая подпись SHA256SUMS.sign недействительна!"
		return 1
	fi

	echo "Проверка наличия и целостности локального образа..."
	if [ ! -f "$iso_path" ]; then
		echo "Локальный образ не найден."
	else
		echo -n "Файл $iso_name найден. Проверяем контрольную сумму... "
		if verify_checksum "$iso_path" "$iso_dir"; then
			echo -e "${GREEN}[OK]${RESET}"
			echo "Образ уже существует и его контрольная сумма корректна."
			echo "Загрузка не требуется. Работа завершена успешно."
			return 0
		fi
		echo -e "${RED}[FAIL]${RESET}"
		echo "Контрольная сумма не совпала. Перекачиваем файл..."
	fi

	echo "Скачивание свежего ISO-образа:"
	if ! download_iso "$base_url" "$iso_name" "$iso_dir"; then
		echo -e "${RED}[FAIL]${RESET}"
		return 1
	fi
	echo -e "Статус загрузки: ${GREEN}[OK]${RESET}"

	echo -n "Финальная проверка контрольной суммы... "
	if verify_checksum "$iso_path" "$iso_dir"; then
		echo -e "${GREEN}[OK]${RESET}"
		echo "Загрузка завершена успешно, контрольная сумма совпадает."
		return 0
	fi
	echo -e "${RED}[FAIL]${RESET}"
	echo "Ошибка: контрольная сумма скачанного файла не совпадает!"
	return 1
}

# @brief Ожидание нажатия клавиши для продолжения
# Ожидание ввода пользователя перед выходом
wait_for_key() {
	echo "Нажмите любую клавишу для продолжения..."
	read -n 1 -s < /dev/tty
}

getdeb
# Ожидание ввода пользователя перед выходом
wait_for_key
