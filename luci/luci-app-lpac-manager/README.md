# luci-app-lpac-manager — Управление eSIM-профилями под OpenWrt

## Что это

**luci-app-lpac-manager** — веб-интерфейс LuCI и консольный инструмент для управления eSIM-профилями на роутерах OpenWrt через бинарник **lpac 2.3.0**.

Пакет адаптирован для **OpenWrt 24.10.x / 25.x** и поддерживает три APDU-бэкенда:

- **QMI** — основной, для модемов в QMI-режиме (PID 9025 и др.)
- **MBIM** — для модемов в MBIM-режиме (PID 90d5 и др.)
- **AT** — резервный, через AT-порт модема

Основной сценарий — внешние съёмные eSIM-карты (9eSIM, eSIM.me) в SIM-слоте LTE/5G модема, но пакет работает и со встроенными eUICC при наличии доступа через поддерживаемый бэкенд.

---


В основе **luci-app-lpac-manager** — глубоко переработанный и сильно оптимизированный форк проекта `luci-app-epm` для OpenWrt (23-25). 

LuCi WebUI был адаптирован под новую версию `lpac 2.3.0` с поддержкой актуальных переменных окружения, полностью переписан в части архитектуры - добавлен собственный независимый скрипт-бэкенд и значительно расширен функционал (особенно в части диагностики и работы с модемами).

## 🏗 Архитектура: В чем суть отличия?

В оригинальном `epm` применяется минималистичный подход: LuCI выступает одновременно и как UI, и как backend. Lua-контроллер напрямую вызывает `/usr/lib/lpac`, и вся логика зашита в Lua.

В нашем форке реализовано строгое разделение слоев:
* **LuCI = только UI.** Отвечает исключительно за веб-интерфейс.
* **Shell = Backend.** Вся тяжелая логика вынесена в отдельный shell-скрипт `lpac-esim` (~1500 строк кода). 

**Плюсы такого подхода:** Кодовая база стала чище, отладка — в разы проще, а управление профилями теперь полноценно работает и без веб-интерфейса (через CLI или интерактивное TUI-меню по SSH).

## Что добавлено поверх epm

| Фича | `luci-app-epm` | `luci-app-lpac-manager` |
| :--- | :--- | :--- |
| **Shell backend (`lpac-esim`)** | ❌ Нет | ✅ Да (1474 строки, TUI + API) |
| **Выбор backend (QMI/MBIM/AT)** | ⚠️ Частично | ✅ Да (в веб-интерфейсе + в TUI при старте) |
| **Async операции (switch/download)** | ❌ Нет | ✅ Да (lock + result file + polling) |
| **AT-терминал в веб-интерфейсе** | ❌ Нет | ✅ Да (с preset-кнопками) |
| **Diagnostics** | ❌ Нет | ✅ Да (syslog, 4 вида сброса/reset, system check) |
| **SIM slot selector** | ❌ Нет | ✅ Да (через `AT^SWITCH_SLOT`) |
| **Интерактивный TUI (через SSH)** | ❌ Нет | ✅ Да (полноценное меню + download/delete/rename) |
| **Verbose syslog с контекстом** | ❌ Нет | ✅ Да (`[QMI /dev/cdc-wdm0] ...`) |
| **Silent mode** | ❌ Нет | ✅ Да (read-only операции не спамят в лог) |
| **Расширенные ошибки lpac** | ⚠️ Generic | ✅ Да (code + message) |
| **Timeout fallback** | ⚠️ Жёсткая зависимость | ✅ Да (безопасный fallback без `coreutils-timeout`) |
| **Proxy/TLS workaround** | ❌ Нет | ✅ Да (`unset proxy` + временный `.curlrc`) |
| **Версии в заголовке** | ❌ Нет | ✅ Да (v1.3.3 / lpac v2.3.0 / MBIM) |
| **One-shot CLI команды** | ❌ Нет | ✅ Да (`lpac-esim profiles` и т.д.) |

## 🤝 Что осталось одинаковым

Сохранен базовый функционал и удачные решения оригинала:
* **QR-сканирование** локально в браузере (через `jsQR`).
* **Базовые операции:** list, switch, delete, rename, download, notifications.
* **Конфигурация** через стандартный UCI OpenWrt.
* **LuCI tab layout:** Привычное расположение вкладок в интерфейсе.
  
---
## Возможности

### Веб-интерфейс (6 вкладок)

| Вкладка | Функции |
|---------|---------|
| **eSIM Info** | EID, версия прошивки eUICC, свободная память, SM-DP+/SM-DS адреса. Статус модема: модель, оператор, технология, сигнал, состояние |
| **Profiles** | Таблица профилей (имя, ICCID, провайдер, статус). Кнопки: Switch, Delete, Rename. Перезагрузка модема |
| **Download Profile** | Загрузка нового eSIM: QR-код (сканирование камерой или файлом), LPA-строка, или SM-DP+ / Matching ID / Confirmation Code раздельно |
| **Notifications** | Уведомления eUICC. Process & Remove All (онлайн), Clear All (офлайн) |
| **Configuration** | Backend Type (QMI/AT/MBIM), пути устройств, SIM-слот, MBIM proxy. Сохранение в UCI |
| **Diagnostics** | System Check (проверка tools, версий, устройств). Системный лог. 4 уровня сброса модема |

### Заголовок страницы

На главной отображается текущая версия: `eSIM Profile Manager v1.3.2 / lpac v2.3.0 / QMI`

### Консольный режим (SSH)

**Интерактивное TUI-меню:**
```
lpac-esim
```
При запуске — выбор бэкенда (QMI/MBIM/AT), затем меню:
- Profile Management: list, switch, rename, delete, download
- Status & Diagnostics: chip info, modem monitor, full status
- Maintenance: reboot, USB reset, notifications

**Быстрые команды (one-shot):**
```sh
lpac-esim chip                    # информация о eUICC
lpac-esim profiles                # список профилей
lpac-esim switch <ICCID>          # переключить профиль
lpac-esim delete <ICCID>          # удалить disabled профиль
lpac-esim nickname <ICCID> --nickname "Имя"  # переименовать
lpac-esim reboot-modem            # перезагрузить модем
lpac-esim notif-list              # список уведомлений
lpac-esim notif-process           # обработать и удалить уведомления
lpac-esim notif-clear             # очистить офлайн
lpac-esim modem-status            # live-монитор модема
lpac-esim doctor                  # проверка окружения
```

**Загрузка профиля через CLI:**
```sh
# Диалоговый режим
lpac-esim
# → 1) Profile Management → 7) Download new eSIM profile

# One-shot
lpac-esim download --lpa 'LPA:1$сервер$код'
```

**API-режим (для скриптов и LuCI):**
```sh
lpac-esim --api chip 2>/dev/null
lpac-esim --api profiles 2>/dev/null
lpac-esim --api version 2>/dev/null
```

---

## Протестировано на

| Компонент | Версия / модель |
|-----------|----------------|
| OpenWrt | 24.10.4 |
| Роутер | RAX3000M (MediaTek Filogic 820) |
| Модем | Foxconn T99W175 (Snapdragon X55), QMI-режим (PID 9025) |
| eSIM-карта | 9eSIM removable eUICC v2.3.1 |
| lpac | 2.3.0 |
| Профили | МТС, МегаФон, Билайн, Тинькофф (T-Mobile) |

Также по данным сообщества работает на:
- OpenWrt 25.12 (Huasefei, MediaTek)
- T99W175 в MBIM-режиме (PID 90d5)
- lpac 2.3.0-r2 с MBIM-поддержкой

---

## Требования

### Обязательные пакеты

| Пакет | Зачем |
|-------|-------|
| `lpac` 2.3.0+ | Бинарник управления eUICC (отдельный пакет) |
| `luci-base` | LuCI фреймворк |
| `jq` | Парсинг JSON |
| `ca-certificates`, `ca-bundle` | TLS-сертификаты для связи с SM-DP+ серверами |

### Для QMI-режима

| Пакет | Зачем |
|-------|-------|
| `libqmi`, `qmi-utils` | QMI-протокол, утилита `qmicli` |
| `libcurl` / `libcurl4` | HTTP для загрузки профилей |

### Для MBIM-режима (опционально)

| Пакет | Зачем |
|-------|-------|
| `libmbim`, `mbim-utils` | MBIM-протокол, утилита `mbimcli` |

### Рекомендуется

| Пакет | Зачем |
|-------|-------|
| `ModemManager` | Статус модема (оператор, сигнал, технология) |
| `luci-compat` | Для OpenWrt 25.x (совместимость LuCI Lua) |

---

## Установка

### Вариант 1: OpenWrt 24.10.x (opkg, IPK)

```sh
# Отключить прокси если настроен
unset http_proxy https_proxy

# Обновить списки пакетов
opkg update

# Установить зависимости
opkg install luci-base jq ca-certificates ca-bundle
opkg install libqmi qmi-utils             # для QMI
opkg install libmbim mbim-utils           # для MBIM (опционально)

# Установить lpac (arch-specific, скачать или собрать)
opkg install /tmp/lpac_2.3.0_aarch64_cortex-a53.ipk

# Установить luci-app-lpac-manager
opkg install /tmp/luci-app-lpac-manager_1.3.2_all.ipk
```

### Вариант 2: OpenWrt 25.x (apk, APK)

Для OpenWrt 25.x используется менеджер пакетов `apk` вместо `opkg`. Формат пакетов — APK v3.

```sh
# Обновить
apk update

# Зависимости
apk add luci-base jq ca-certificates
apk add libqmi qmi-utils                 # для QMI
apk add libmbim mbim-utils               # для MBIM

# Установить lpac (из готового APK, arch-specific)
apk add --allow-untrusted /tmp/lpac-2.3.0-r2.apk

# Установить luci-app-lpac-manager
apk add --allow-untrusted /tmp/luci-app-lpac-manager-1.3.2.apk

# Может потребоваться для LuCI Lua-совместимости
apk add luci-compat luci-lua-runtime
```

Флаг `--allow-untrusted` необходим для пакетов, не подписанных ключом репозитория. Установка через веб-интерфейс LuCI не поддерживает этот флаг — используйте SSH.

### Вариант 3: Использование стороннего lpac (от сообщества)

Если вы нашли готовый пакет `lpac` от другого разработчика (например `lpac-2.3.0-r2.apk` для OpenWrt 25.x):

```sh
# Загрузить пакеты на роутер (через WinSCP, luci-app-filemanager или wget)
# Файлы: lpac-2.3.0-r2.apk, luci-app-lpac-manager-1.3.2.apk

# OpenWrt 25.x
apk add --allow-untrusted /tmp/lpac-2.3.0-r2.apk

# OpenWrt 24.x — если это IPK
opkg install /tmp/lpac_2.3.0-r2.ipk
```

Их пакет `lpac` ставит:
- `/usr/lib/lpac` — бинарник (ELF aarch64)
- `/usr/bin/lpac` — shell wrapper, читает UCI `/etc/config/lpac`
- `/etc/config/lpac` — UCI-конфигурация бэкендов

Наш backend `lpac-esim` находит lpac через `command -v lpac` (стандартный PATH) и вызывает его напрямую, выставляя env-переменные самостоятельно.

### Вариант 4: Ручной деплой (из ZIP-архива)

Для разработки и тестирования — без сборки IPK/APK:

```sh
cd /tmp && unzip -o luci-app-lpac-manager-v1.3.2.zip

# Backend скрипт
cp luci-app-lpac-manager/src/usr/bin/lpac-esim /usr/bin/lpac-esim
chmod +x /usr/bin/lpac-esim

# LuCI controller + шаблоны
cp luci-app-lpac-manager/src/usr/lib/lua/luci/controller/lpac_esim.lua /usr/lib/lua/luci/controller/
mkdir -p /usr/lib/lua/luci/view/lpac_esim
cp luci-app-lpac-manager/src/usr/lib/lua/luci/view/lpac_esim/*.htm /usr/lib/lua/luci/view/lpac_esim/

# JS + CSS
mkdir -p /www/luci-static/resources/lpac-esim
cp -r luci-app-lpac-manager/htdocs/luci-static/resources/lpac-esim/* /www/luci-static/resources/lpac-esim/

# Меню и ACL (только при первой установке)
cp luci-app-lpac-manager/root/usr/share/luci/menu.d/*.json /usr/share/luci/menu.d/ 2>/dev/null
cp luci-app-lpac-manager/root/usr/share/rpcd/acl.d/*.json /usr/share/rpcd/acl.d/ 2>/dev/null
cp luci-app-lpac-manager/etc/config/lpac-esim /etc/config/lpac-esim 2>/dev/null

# Очистить кэш LuCI
rm -rf /tmp/luci-modulecache /tmp/luci-indexcache*
/etc/init.d/rpcd reload 2>/dev/null
```

### После установки

1. Откройте LuCI → **Modem → eSIM Manager**
2. Вкладка **Configuration** → выберите Backend Type (QMI / MBIM / AT)
3. Укажите пути к устройствам (`/dev/cdc-wdm0`, `/dev/ttyUSB3` и т.д.)
4. **Save** → вернитесь на вкладку **eSIM Info**
5. Если всё настроено верно — увидите EID, список профилей, статус модема

---

## Настройка бэкендов

### QMI (по умолчанию)

Для модемов в QMI-режиме (T99W175 PID 9025, и др.):

| Параметр | Значение |
|----------|----------|
| Backend Type | QMI |
| QMI Device | `/dev/cdc-wdm0` |
| SIM Slot | 1 |

### MBIM

Для модемов в MBIM-режиме (T99W175 PID 90d5):

| Параметр | Значение |
|----------|----------|
| Backend Type | MBIM |
| MBIM Device | `/dev/cdc-wdm0` |
| MBIM Proxy | Enabled |
| AT Device | `/dev/ttyUSB2` (для перезагрузки через AT) |

Рекомендация от сообщества: для T99W175 в режиме 90d5 с USB2.0/USB3.0 использовать MBIM + AT reboot (`AT+CFUN=1,1`).

### AT (резервный)

| Параметр | Значение |
|----------|----------|
| Backend Type | AT |
| AT Device | `/dev/ttyUSB3` |

---

## Переменные окружения lpac 2.3.0

Backend-скрипт `lpac-esim` автоматически выставляет нужные переменные. Для ручного вызова `lpac` из SSH:

```sh
# QMI
LPAC_APDU=qmi LPAC_HTTP=curl \
LPAC_APDU_QMI_DEVICE=/dev/cdc-wdm0 \
LPAC_APDU_QMI_UIM_SLOT=1 \
lpac chip info

# MBIM
LPAC_APDU=mbim LPAC_HTTP=curl \
LPAC_APDU_MBIM_DEVICE=/dev/cdc-wdm0 \
LPAC_APDU_MBIM_USE_PROXY=1 \
lpac chip info

# AT
LPAC_APDU=at LPAC_HTTP=curl \
LPAC_APDU_AT_DEVICE=/dev/ttyUSB3 \
lpac chip info

# Debug (полный trace HTTP и APDU)
LIBEUICC_DEBUG_HTTP=1 LIBEUICC_DEBUG_APDU=1 lpac profile list
```

---

## Архитектура

```
Browser → LuCI (uhttpd) → lpac_esim.lua (io.popen) → lpac-esim --api → JSON → Browser
                                                          ↓
                                                   lpac (бинарник) → eUICC
```

Два компонента в пакете:
- **`/usr/bin/lpac-esim`** — backend-скрипт (~1400 строк POSIX shell), TUI + API
- **LuCI WebUI** — Lua controller (~550 строк) + 7 HTM + 9 JS + CSS

Бинарник `/usr/bin/lpac` — отдельный пакет, ищется через `command -v lpac`.
Никаких промежуточных wrapper-скриптов.

### API-эндпоинты (21)

| Тип | Эндпоинты |
|-----|-----------|
| GET | profiles, chip, modem_status, notif_list, lock_status, config, connectivity, syslog, runlog, version |
| POST | switch, reboot_modem, notif_clear, notif_process, download, delete, nickname, save_config, soft_reset, usb_reset, uicc_reset |

Async-операции (switch, download, reboot, notif_process) выполняются в фоне. Frontend поллит `lock_status` до получения результата.

---

## Диагностика проблем

### Базовые проверки

```sh
# Модем виден?
mmcli -L
ls -la /dev/cdc-wdm0

# Backend работает?
lpac-esim --api chip 2>/dev/null | head -c 100

# Версия lpac
lpac version
```

### Логи

```sh
# Syslog
logread | grep lpac-esim | tail -20

# Подробный лог инициализации
cat /tmp/lpac-esim/run.log

# Результат последнего download
cat /tmp/lpac-esim/download.json
```

### Проблемы с TLS / загрузкой профилей

```sh
# Отключить прокси
unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY

# Проверить TLS к SM-DP+ серверу
curl -v --connect-timeout 10 https://rsp.truphone.com/ 2>&1 | head -10

# Если ошибка mbedTLS — проверить CA
ls -la /etc/ssl/certs/ca-certificates.crt
opkg install ca-certificates ca-bundle

# Если CA не помогает — curl на OpenWrt собран с mbedTLS, который
# может не верифицировать некоторые SM-DP+ сертификаты.
# Backend автоматически применяет workaround при download.
```

### Проблемы с прокси

Если на роутере настроен HTTP-прокси (sing-box, clash, v2ray и т.д.):
```sh
# Проверить
env | grep -i proxy

# Backend автоматически делает unset перед вызовом lpac.
# Но opkg/wget могут не работать через прокси.
# Для opkg update:
unset http_proxy https_proxy
opkg update
```

### USB-устройства

```sh
# Какие USB-устройства подключены
lsusb -t

# AT-порты
ls /dev/ttyUSB*

# QMI/MBIM device
ls /dev/cdc-wdm*
```

---

## Отличия от luci-app-epm

| Аспект | luci-app-epm | luci-app-lpac-manager |
|--------|-------------|----------------------|
| Бэкенд-логика | В Lua controller | В отдельном shell backend |
| Wrapper lpac | Обходит wrapper, дублирует env в Lua | Backend строит env, wrapper не нужен |
| timeout | Жёсткая зависимость `coreutils-timeout` | Fallback без timeout |
| Async-операции | Нет выделенного async pipeline | lock + result file + polling |
| Диагностика | Нет | System Check + syslog + 4 уровня reset |
| TUI (SSH) | Нет | Интерактивное меню + one-shot команды |
| Ошибки lpac | Generic сообщения | Реальный lpac code + message |
| Syslog | Логирует всё подряд | Silent для read-only, verbose для write |
| Proxy/TLS | Не обрабатывает | Автоматический unset прокси + TLS workaround |

---

## Именование пакета

Проект назван **`luci-app-lpac-manager`** для разделения с:
- `luci-app-epm` — аналогичный проект от другого разработчика
- `luci-app-lpac-esim` — предыдущие версии этого проекта
- `luci-app-epm-qmi` — ранняя версия с привязкой только к QMI

---

## Известные ограничения

- **mbedTLS на OpenWrt 24.x** может не верифицировать TLS-сертификаты SM-DP+ серверов даже при установленных `ca-certificates`. Backend автоматически применяет workaround (временный `.curlrc` с `insecure`) на время загрузки профиля
- **После переключения профиля** модем перезагружается 30-60 секунд — данные временно недоступны
- **QR-код привязан к EID** — код, выпущенный для другой eUICC-карты, не подойдёт (ошибка "EID doesn't match")
- **HTTP-прокси** — если настроен на роутере, backend автоматически отключает его перед обращением к SM-DP+
- **CSRF** — не применяется (осознанный компромисс для совместимости со старыми LuCI)

---

## Совместимость

### Работает

- OpenWrt 24.10.x (opkg, IPK)
- OpenWrt 25.x (apk, APK) — с `luci-compat`
- aarch64 (MediaTek Filogic, Qualcomm)
- T99W175 QMI-режим (9025) + 9eSIM
- T99W175 MBIM-режим (90d5) — по данным сообщества
- lpac 2.3.0 / 2.3.0-r2

### Не гарантируется

- Встроенные eUICC без SIM-слота (vendor-specific доступ)
- Модемы с нестандартным UIM-доступом
- Legacy uqmi-only интеграции
- Десктопные Linux-дистрибутивы

---

## Участие в разработке

Приветствуются:
- Баг-репорты и feature requests через Issues
- Pull requests
- Тестирование на других модемах и eUICC-картах
- Помощь с OpenWrt packaging (Makefile для feeds)
- Документация и переводы

### В планах
- Telegram-бот для удалённого управления модемом и eSIM
- SMS-канал управления через smstools3
- MBIM download тестирование
- Proper TLS fix (curl с OpenSSL вместо mbedTLS)

---

## Благодарности

- **[estkme-group](https://github.com/estkme-group/lpac)** — за lpac
- **[OpenWrt](https://openwrt.org/)** и сообщество разработчиков LuCI
- **[9eSIM](https://9esim.com/)** — за доступные removable eUICC-карты
- **https://github.com/stich86/luci-app-epm** — за исходный код epm WebUI в качестве скелета
- Участники сообщества, тестирующие eSIM на встраиваемых устройствах

---

## Лицензия

MIT




# LuCI Web Interface for managing eSIM profiles via lpac 2.3.0 (QMI/AT)

## What is this?

**luci-app-lpac-manager** is a LuCI web interface for OpenWrt that provides eSIM profile management through **lpac 2.3.0**.

This variant is specifically adapted for **OpenWrt 24.10.x** and focuses on:

- **native QMI** as the primary LPAC APDU backend
- **AT** as a fallback backend
- modern **lpac 2.3.0** environment variables and runtime behavior
- external eSIM cards installed in a modem SIM/UIM slot, such as **9eSIM** in modules like **T99W175**

This package is intentionally separated from older builds to distinguish it from earlier `uqmi` / `mbim` oriented variants like luci-app-epm.

---
