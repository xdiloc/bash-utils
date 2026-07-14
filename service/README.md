## Быстрого и удобного управления systemd-сервисами прямо из терминала.

### Основные возможности
✅ Проверка статуса сервиса
✅ Запуск, остановка и перезапуск
✅ Просмотр логов в реальном времени
✅ Редактирование unit-файлов
✅ Создание резервных копий конфигураций

### Настройка
Внутри скрипта `unit.sh` можно изменить следующие параметры:
* `SERVICE="$1"` — принимает имя сервиса как первый аргумент командной строки.
* `EDITOR="micro"` — задает текстовый редактор, который будет использоваться для редактирования конфигурационных файлов.

### Ссылки для скачивания
wget [https://raw.githubusercontent.com/xdiloc/bash-utils/main/service/unit.sh](https://raw.githubusercontent.com/xdiloc/bash-utils/main/service/unit.sh)
wget [https://raw.githubusercontent.com/xdiloc/bash-utils/main/service/addunit.sh](https://raw.githubusercontent.com/xdiloc/bash-utils/main/service/addunit.sh)

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
