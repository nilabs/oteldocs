#!/bin/bash

VENV_PATH="$HOME/.venvs/myenv"

# Проверка на существование venv
# Проверяем, существует ли окружение
if [ ! -d "$VENV_PATH" ]; then
    echo "Ошибка: Виртуальное окружение не найдено в $VENV_PATH"
    exit 1
fi

# Активируем виртуальное окружение
source "$VENV_PATH/bin/activate"



# --- НАСТРОЙКИ (ЗАПОЛНИТЕ СВОИМИ ДАННЫМИ) ---
REMOTE_USER="sergey"
REMOTE_HOST="31.58.79.232"
REMOTE_DIR="/var/www/html/"  # Путь на сервере, куда копировать сайт
SSH_PORT="22"                    # Порт SSH (обычно 22)

# Директория сборки MkDocs (обычно "site")
LOCAL_BUILD_DIR="site"

# --- ПРОВЕРКА НАЛИЧИЯ ИНСТРУМЕНТОВ ---
if ! command -v rsync &> /dev/null; then
    echo "Ошибка: rsync не установлен. Установите его: sudo apt install rsync"
    exit 1
fi

if ! command -v mkdocs &> /dev/null; then
    echo "Ошибка: mkdocs не установлен. Проверьте виртуальное окружение."
    exit 1
fi

# --- СБОРКА САЙТА ---
echo "1/2: Сборка сайта MkDocs..."
# Флаг --strict остановит сборку при любых предупреждениях (рекомендуется для CI/CD)[citation:1]
mkdocs build --strict --clean

# Проверяем, что сборка прошла успешно
if [ $? -ne 0 ]; then
    echo "Ошибка: Сборка MkDocs завершилась с ошибкой."
    exit 1
fi

# --- СИНХРОНИЗАЦИЯ ЧЕРЕЗ RSYNC ---
echo "2/2: Синхронизация с сервером ${REMOTE_HOST}..."

# Основные флаги:
# -a (archive) — сохраняет права, время, символические ссылки
# -v (verbose) — подробный вывод
# -z (compress) — сжатие при передаче
# --delete — удаляет файлы на сервере, которых нет в локальной сборке[citation:3][citation:16]
# --exclude — исключает ненужные файлы (например, .git)
rsync -avzO --delete --no-group\
    -e "ssh -p ${SSH_PORT}" \
    --exclude='.git' \
    --exclude='.DS_Store' \
    "${LOCAL_BUILD_DIR}/" "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DIR}"

# Проверяем статус rsync
if [ $? -eq 0 ]; then
    echo "✅ Успешно! Сайт обновлён: https://${REMOTE_HOST}"
else
    echo "❌ Ошибка: rsync завершился с кодом $?"
    exit 1
fi

#-------------------------------------------------------------------------
BUILD_DIR="site"
BACKUP_DIR="./backups"
TIMESTAMP=$(date '+%Y%m%d-%H%M%S')
ARCHIVE_NAME="site-${TIMESTAMP}.tar.gz"

# Создаём директорию для бэкапов, если её нет
mkdir -p "$BACKUP_DIR"

# Архивируем содержимое site/ (без самой папки в архиве)
tar -czf "${BACKUP_DIR}/${ARCHIVE_NAME}" -C "$BUILD_DIR" .

if [ $? -eq 0 ]; then
    echo "✅ Архив создан: ${BACKUP_DIR}/${ARCHIVE_NAME}"
else
    echo "❌ Ошибка архивации"
    exit 1
fi