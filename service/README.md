## Быстрого и удобного управления systemd-сервисами прямо из терминала.

### Основные возможности
- [x] Проверка статуса сервиса
- [x] Запуск, остановка и перезапуск
- [x] Просмотр логов в реальном времени
- [x] Редактирование unit-файлов
- [x] Создание резервных копий конфигураций

### Настройка
Внутри скрипта `unit.sh` можно изменить следующие параметры:
* `SERVICE="$1"` — принимает имя сервиса как первый аргумент командной строки.
* `EDITOR="micro"` — задает текстовый редактор, который будет использоваться для редактирования конфигурационных файлов.

### Ссылки для скачивания
[unit.sh](https://raw.githubusercontent.com/xdiloc/bash-utils/main/service/unit.sh)
```bash
wget https://raw.githubusercontent.com/xdiloc/bash-utils/main/service/unit.sh
```
[addunit.sh](https://raw.githubusercontent.com/xdiloc/bash-utils/main/service/addunit.sh)
```bash
wget https://raw.githubusercontent.com/xdiloc/bash-utils/main/service/addunit.sh
```

### Перед использованием убедитесь, что скрипты имеют права на исполнение:
```bash
chmod +x unit.sh addunit.sh
```

### Голый запуск (управление сервисом)
```bash
./unit.sh name
```

### Создание файла-обертки для сервиса
```bash
./addunit.sh name
```

### Запуск созданного файла:
```bash
./name.sh
```
