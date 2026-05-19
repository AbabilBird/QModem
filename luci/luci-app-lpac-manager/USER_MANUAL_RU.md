# luci-app-lpac-manager — Руководство пользователя

**Версия:** 1.3.2  
**Пакет:** `luci-app-lpac-manager`  
**Оборудование:** OpenWrt 24.x + модем с eSIM (T99W175, X55, и др.) + eUICC карта

---

## 1. Веб-интерфейс (LuCI)

### Доступ
Modem → eSIM Manager (или `http://192.168.1.1/cgi-bin/luci/admin/modem/lpac-esim`)

### Вкладки

**eSIM Info** — информация о чипе и модеме
- EID, версия прошивки eUICC, свободная память
- Модель модема, оператор, сигнал, технология, состояние

**Profiles** — управление профилями
- Список профилей с ICCID, провайдером, статусом
- **Switch** — переключить на профиль (модем перезагрузится, 30-60 сек)
- **Delete** — удалить disabled профиль (необратимо, двойное подтверждение)
- **Rename** — изменить nickname профиля
- **Reboot Modem** — полная перезагрузка модема

**Download Profile** — загрузка нового eSIM
- Вставить LPA-код: `LPA:1$сервер$код`
- Или загрузить QR-картинку (декодируется в браузере)
- Или ввести SM-DP+ / Matching ID / Confirmation Code по отдельности
- Загрузка занимает 60-120 секунд

**Notifications** — уведомления eUICC
- **Process & Remove All** — отправить уведомления операторам и удалить (нужен интернет)
- **Clear All (Offline)** — удалить без отправки

**Configuration** — настройки
- Backend Type: QMI / AT / MBIM
- Device paths, SIM slot, MBIM proxy

**Diagnostics** — диагностика
- **System Check** — результат инициализации (tools, версии, devices)
- **System Log** — syslog с фильтром по modem/lpac событиям
- **Soft Reset** — radio off/on без USB
- **USB Reset** — переподключение USB порта
- **SIM Reset** — power cycle SIM слота
- **Hard Reboot** — полная перезагрузка ОС модема

---

## 2. Командная строка (SSH)

### Интерактивный режим

```sh
lpac-esim
```

Запускает TUI-меню с выбором backend (QMI/MBIM/AT) и разделами:
1. Profile Management (list, switch, rename, delete, download)
2. Status & Diagnostics (chip info, modem monitor)
3. Maintenance & Resets (reboot, USB reset, notifications)

### Быстрые команды (one-shot)

```sh
# Информация о чипе
lpac-esim chip

# Список профилей
lpac-esim profiles

# Переключить профиль (по ICCID, номеру или AID)
lpac-esim switch 897010260225401535

# Удалить профиль (только disabled)
lpac-esim delete 897010260225401535

# Переименовать профиль
lpac-esim nickname 897010260225401535 --nickname "МегаФон основной"

# Перезагрузить модем
lpac-esim reboot-modem

# Уведомления
lpac-esim notif-list
lpac-esim notif-clear
lpac-esim notif-process

# Статус модема (live monitor)
lpac-esim modem-status

# Проверка окружения
lpac-esim doctor
```

### Загрузка профиля через CLI

```sh
# Через TUI-диалог (рекомендуется)
lpac-esim
# → 1) Profile Management → 7) Download new eSIM profile

# Через one-shot команду
lpac-esim download --lpa 'LPA:1$mno-09.esimservices.com$CE1A9672-C8DA4B4C-A2349338-00C1CD38'
```

### Прямой вызов lpac (без обёртки)

```sh
# Проверить версию
lpac version

# Chip info
LPAC_APDU=qmi LPAC_HTTP=curl \
LPAC_APDU_QMI_DEVICE=/dev/cdc-wdm0 \
LPAC_APDU_QMI_UIM_SLOT=1 \
lpac chip info

# Профили
LPAC_APDU=qmi LPAC_HTTP=curl \
LPAC_APDU_QMI_DEVICE=/dev/cdc-wdm0 \
LPAC_APDU_QMI_UIM_SLOT=1 \
lpac profile list

# Download с debug
LPAC_APDU=qmi LPAC_HTTP=curl \
LPAC_APDU_QMI_DEVICE=/dev/cdc-wdm0 \
LPAC_APDU_QMI_UIM_SLOT=1 \
LIBEUICC_DEBUG_HTTP=1 \
LIBEUICC_DEBUG_APDU=1 \
lpac profile download -a 'LPA:1$сервер$код' 2>&1

# MBIM режим
LPAC_APDU=mbim LPAC_HTTP=curl \
LPAC_APDU_MBIM_DEVICE=/dev/cdc-wdm0 \
LPAC_APDU_MBIM_USE_PROXY=1 \
lpac chip info
```

---



## 3. Диагностика проблем

```sh
# Модем виден?
mmcli -L

# QMI device на месте?
ls -la /dev/cdc-wdm0

# Backend скрипт работает?
lpac-esim --api chip 2>/dev/null | head -c 100

# Syslog
logread | grep lpac-esim | tail -20

# Run.log (подробный лог инициализации)
cat /tmp/lpac-esim/run.log

# Последний результат download
cat /tmp/lpac-esim/download.json

# Проверить TLS к SM-DP+ серверу
unset http_proxy https_proxy
curl -v --connect-timeout 10 https://rsp.truphone.com/ 2>&1 | head -10

# Если TLS не проходит — временный workaround
echo "insecure" > /root/.curlrc
# после теста: rm /root/.curlrc
```

---

## 4. Известные ограничения

- **mbedTLS на OpenWrt 24.x** может не верифицировать сертификаты SM-DP+ серверов. Backend автоматически создаёт временный `.curlrc` с `insecure` на время download
- **После switch** модем ребутится 30-60 сек. В это время profiles/modem-status недоступны — это нормально
- **Download привязан к EID** — если QR-код выпущен для другой eUICC карты, сервер откажет с ошибкой "EID doesn't match"
- **Прокси** — если на роутере настроен HTTP-прокси, backend автоматически отключает его перед вызовом lpac
