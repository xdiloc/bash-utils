#!/usr/bin/env bash

# Определяем список серверов в одном месте (нет дублирования списка)
GPG_SERVERS=(
	"https://keys.openpgp.org"
	"https://keyserver.ubuntu.com"
)

# Глобальные переменные для цветового оформления
RED="\033[31m"
GREEN="\033[32m"
RESET="\033[0m"

# @brief Создает целевую директорию для ISO-образов в домашней директории, если она не существует
# target_directory - путь к создаваемой директории
create_iso_directory() {
	local target_directory="$1"
	[ -d "$target_directory" ] && return 0
	mkdir --parents "$target_directory"
}

# @brief Универсальная функция для скачивания файлов через curl с выводом статуса
# download_url - полный URL скачиваемого файла
# output_path - путь для сохранения файла
# curl_flags - дополнительные флаги для curl (например, --silent или --progress-bar)
# description - описание загружаемого файла для вывода пользователю
download_file() {
	local download_url="$1"
	local output_path="$2"
	local curl_flags="$3"
	local description="$4"

	echo "$description"

	if curl $curl_flags --location --output "$output_path" "$download_url"; then
		echo -e "Статус загрузки: ${GREEN}[OK]${RESET}"
		return 0
	else
		echo -e "Статус загрузки: ${RED}[FAIL]${RESET}"
		return 1
	fi
}

# @brief Извлекает отпечаток и идентификатор ключа из файла подписи
# target_directory - директория с файлом подписи
# out_fingerprint - переменная для записи отпечатка
# out_identifier - переменная для записи идентификатора
extract_key_info() {
	local target_directory="$1"
	local -n out_fingerprint="$2"
	local -n out_identifier="$3"

	out_fingerprint=$(gpg --list-packets "$target_directory/SHA256SUMS.sign" 2>/dev/null | awk '/issuer fpr/{print $NF; exit}' | tr --complement --delete 'A-Fa-f0-9')
	out_identifier=$(gpg --list-packets "$target_directory/SHA256SUMS.sign" 2>/dev/null | awk '/keyid/{print $NF; exit}' | tr --complement --delete 'A-Fa-f0-9')
}

# @brief Проверяет доступность GPG-ключа на внешних серверах
# search_query - поисковый запрос (отпечаток или идентификатор ключа)
check_servers_for_key() {
	local search_query="$1"
	local server_is_available=false

	for server in "${GPG_SERVERS[@]}"; do
		echo -n "  -> Проверка на $server ... "
		local http_status_code
		http_status_code=$(curl --output /dev/null --silent --write-out "%{http_code}\n" "${server}/pks/lookup?op=index&search=0x${search_query}")
		if [ "$http_status_code" -eq 200 ]; then
			echo -e "${GREEN}[OK]${RESET}"
			server_is_available=true
		else
			echo -e "${RED}[FAIL]${RESET} (HTTP: $http_status_code)"
		fi
	done

	if [ "$server_is_available" = false ]; then
		echo "Предупреждение: ключ не подтвержден ни на одном из серверов."
	fi
}

# @brief Скачивает и импортирует GPG-ключ с серверов
# search_query - поисковый запрос (отпечаток или идентификатор ключа)
# key_fingerprint - отпечаток ключа для финальной проверки
import_gpg_key_from_servers() {
	local search_query="$1"
	local key_fingerprint="$2"

	for server in "${GPG_SERVERS[@]}"; do
		echo -n "   -> Загрузка с сервера: $server ... "
		if curl --silent "${server}/pks/lookup?op=get&search=0x${search_query}" | gpg --import >/dev/null 2>&1; then
			if gpg --list-keys "$key_fingerprint" >/dev/null 2>&1; then
				echo -e "${GREEN}[OK]${RESET}"
				return 0
			fi
		fi
		echo -e "${RED}[FAIL]${RESET}"
	done
	return 1
}

# @brief Всегда проверяет доступность ключа на сервере и при необходимости импортирует его
ensure_gpg_key() {
	local target_directory="$1"
	local key_fingerprint
	local key_identifier

	extract_key_info "$target_directory" key_fingerprint key_identifier

	if [ -z "$key_fingerprint" ]; then
		echo "Ошибка: не удалось извлечь отпечаток ключа из SHA256SUMS.sign"
		return 1
	fi

	local search_query="${key_fingerprint:-$key_identifier}"

	echo "Проверка доступности ключа $key_fingerprint"
	check_servers_for_key "$search_query"

	if gpg --list-keys "$key_fingerprint" >/dev/null 2>&1; then
		return 0
	fi

	echo " Ключ отсутствует локально. Запуск загрузки через curl:"
	import_gpg_key_from_servers "$search_query" "$key_fingerprint"
}

# @brief Проверяет GPG-подпись файла контрольных сумм
# target_directory - директория, где лежат SHA256SUMS и SHA256SUMS.sign
verify_signature() {
	local target_directory="$1"
	echo -n "  -> Проверка подписи SHA256SUMS.sign ... "
	if (cd "$target_directory" && gpg --verify SHA256SUMS.sign SHA256SUMS >/dev/null 2>&1); then
		echo -e "${GREEN}[OK]${RESET}"
		return 0
	else
		echo -e "${RED}[FAIL]${RESET}"
		return 1
	fi
}

# @brief Проверяет целостность существующего ISO-образа по SHA256
# iso_file_path - полный путь к проверяемому файлу ISO
# target_directory - директория, где лежит файл и SHA256SUMS
verify_checksum() {
	local iso_file_path="$1"
	local target_directory="$2"
	local iso_base_name
	iso_base_name=$(basename "$iso_file_path")

	echo -n "Файл $iso_base_name найден. Проверяем контрольную сумму... "
	if (cd "$target_directory" && grep "$iso_base_name" SHA256SUMS | sha256sum --check --ignore-missing --status); then
		echo -e "${GREEN}[OK]${RESET}"
		return 0
	else
		echo -e "${RED}[FAIL]${RESET}"
		return 1
	fi
}

# @brief Отображает меню выбора доступных ISO-файлов
# iso_images_list - массив доступных образов
show_menu() {
	local -n images_reference="$1"
	echo ""
	echo "=== Доступные образы ==="
	local index_counter=1
	for iso_image in "${images_reference[@]}"; do
		echo "$index_counter) $iso_image"
		index_counter=$((index_counter + 1))
	done
	echo "$index_counter) Выход"
	echo -n "Выберите пункт (1-$index_counter): "
}

# @brief Отображает меню выбора архитектуры
show_architecture_menu() {
	echo "=== Выберите архитектуру ==="
	echo "1) amd64"
	echo "2) arm64"
	echo "3) Выход"
	echo -n "Выберите пункт (1-3): "
}

# @brief Выбирает архитектуру и возвращает её параметры через выходные переменные
# out_arch_name - имя переменной для записи выбранной архитектуры
# out_base_url - имя переменной для записи базового URL
select_architecture() {
	local -n out_arch_name="$1"
	local -n out_base_url="$2"

	show_architecture_menu
	local architecture_selection
	read -r architecture_selection

	case "$architecture_selection" in
		1)
			out_arch_name="amd64"
			out_base_url="https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/"
			return 0
			;;
		2)
			out_arch_name="arm64"
			out_base_url="https://cdimage.debian.org/debian-cd/current/arm64/iso-cd/"
			return 0
			;;
		3)
			return 1
			;;
		*)
			echo "Неверный выбор."
			return 1
			;;
	esac
}

# @brief Получает список доступных ISO-файлов с сервера
# base_url - базовый URL для загрузки
# out_images_list - массив для записи найденных образов
fetch_iso_images_list() {
	local base_url="$1"
	local -n out_images_list="$2"

	local html_content
	echo -n "Получение списка ISO-файлов с сервера... "
	html_content=$(curl --silent --location "$base_url")
	if [ -z "$html_content" ]; then
		echo -e "${RED}[FAIL]${RESET}"
		echo "Ошибка: не удалось получить данные с сервера."
		return 1
	fi
	echo -e "${GREEN}[OK]${RESET}"

	while IFS= read -r iso_image; do
		[ -n "$iso_image" ] && out_images_list+=("$iso_image")
	done < <(echo "$html_content" | grep --only-matching --perl-regexp 'class="indexcolname">\s*<a href="[^"]+\.iso">\K[^<]+' | awk '!seen[$0]++')
}

# @brief Загружает вспомогательные файлы (контрольные суммы и подпись)
# base_url - базовый URL
# target_directory - целевая директория
download_verification_files() {
	local base_url="$1"
	local target_directory="$2"

	download_file "${base_url}/SHA256SUMS" "$target_directory/SHA256SUMS" "--progress-bar" "Загрузка файла контрольных сумм..."
	download_file "${base_url}/SHA256SUMS.sign" "$target_directory/SHA256SUMS.sign" "--progress-bar" "Загрузка файла цифровой подписи..."
}

# @brief Проверяет наличие локального образа, сверяет контрольную сумму и скачивает ISO при необходимости
# base_url - базовый URL
# chosen_iso_image - имя выбранного ISO-файла
# target_directory - целевая директория
# iso_file_path - полный путь к ISO-файлу
handle_iso_download_and_verify() {
	local base_url="$1"
	local chosen_iso_image="$2"
	local target_directory="$3"
	local iso_file_path="$4"

	echo "Проверка наличия и целостности локального образа..."
	if [ ! -f "$iso_file_path" ]; then
		echo "Локальный образ не найден."
	else
		if verify_checksum "$iso_file_path" "$target_directory"; then
			echo "Образ уже существует и его контрольная сумма корректна."
			return 0
		fi
		echo "Контрольная сумма не совпала. Перекачиваем файл..."
	fi

	if ! download_file "${base_url}/${chosen_iso_image}" "$target_directory/$chosen_iso_image" "--progress-bar" "Скачивание выбранного ISO-образа ($chosen_iso_image):"; then
		return 1
	fi

	echo "Финальная проверка контрольной суммы:"
	if verify_checksum "$iso_file_path" "$target_directory"; then
		echo "Загрузка завершена успешно, контрольная сумма совпадает."
	else
		echo "Ошибка: контрольная сумма скачанного файла не совпадает!"
	fi
}

# @brief Выводит список доступных ISO-файлов и обрабатывает выбор пользователя
select_and_download_iso() {
	local architecture_name=""
	local base_url=""

	if ! select_architecture architecture_name base_url; then
		return 0
	fi

	local iso_images_list=()
	if ! fetch_iso_images_list "$base_url" iso_images_list; then
		return 1
	fi

	if [ ${#iso_images_list[@]} -eq 0 ]; then
		echo " ISO-файлы не найдены."
		return 1
	fi

	local exit_option_number=$((${#iso_images_list[@]} + 1))

	show_menu iso_images_list
	local user_selection
	read -r user_selection
	echo ""

	if ! [[ "$user_selection" =~ ^[0-9]+$ ]] || [ "$user_selection" -lt 1 ] || [ "$user_selection" -gt "$exit_option_number" ]; then
		echo "Неверный выбор."
		return 1
	fi

	if [ "$user_selection" -eq "$exit_option_number" ]; then
		return 0
	fi

	local chosen_iso_image="${iso_images_list[$((user_selection - 1))]}"
	local target_directory="$HOME/iso/$architecture_name"
	local iso_file_path="$target_directory/$chosen_iso_image"

	create_iso_directory "$target_directory"
	download_verification_files "$base_url" "$target_directory"

	echo "Проверка наличия GPG-ключа..."
	ensure_gpg_key "$target_directory"

	echo "Проверка GPG-подписи файла контрольных сумм:"
	verify_signature "$target_directory"

	handle_iso_download_and_verify "$base_url" "$chosen_iso_image" "$target_directory" "$iso_file_path"
}

# @brief Ожидание нажатия клавиши для продолжения
wait_for_key() {
	echo "Нажмите любую клавишу для продолжения..."
	read -n 1 -s < /dev/tty
}

select_and_download_iso
wait_for_key
