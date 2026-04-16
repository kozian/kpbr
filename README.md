# Краткое описание
  - install-kpbr.sh - настраивает маршрутизацию по доменным именам.
    - тянет nftset.conf со списками доменов по wan и vpn
    - тянет vpn-cidrs.lst со список cidr которые нужно пускать через vpn (tg, claude etc)
    - зависит от настройки интерфейса для VPN, ниже описано как поставить amneziawg для него. 
  - update-kpbr.sh - обновляет списки nftset.conf и vpn-cidrs.lst на актуальные из репы.
  - create-nftsets.sh - опциональный скрипт для сбора nftset.conf из файлов со списками доменов (из sources/)

## source
Содержит файлы со списками CIDR/доменов, на базе которых генерируются списки для маршрутизации.
Основные файлы. Они собираются вручную из других. 
  - wan-full.lst: сборный файл всех доменов, которые должны ходить напрямую без VPN
  - vpn-full.lst: сборный файл всех доменов, которые должны ходить через VPN
  - vpn-cidrs.lst (в корне): сборный файл всех CIDR, которые должны ходить через VPN
wan-full.lst и vpn-full.lst используются для генерации nftset.conf скриптом create-nftsets.sh

Доп. файлы, информативные
  - vpn-cidr-apple-facetime.lst - списки IP для работы сервисов apple
  - vpn-cidr-claude.lst - списки IP для работы claude code
  - vpn-cidr-telegram.lst - списки ip для работы telegram
  - wan-vpnwatchers.lst - список российских сайтов из новостей о запрете к ним доступа через VPN. 

Источники (не полный список, т.к. вручную тоже добавляю)
 - https://github.com/hydraponique/roscomvpn-geosite/
 - https://github.com/itdoginfo/allow-domains/


# install-kpbr.sh - kpbr Installation Script

Автоматический скрипт установки и настройки Dnsmasq-full для OpenWrt 24.10.2 для поддержки маршрутизации по доменам. 
Использует два списка. 
  - WAN - для маршрутизации напрямую, 
  - VPN - для маршрутизации через интерфейс VPN (хардкод 'amneziawg' имя интерфейса).
Список IP и доменных имен берется из приложенных nftset.conf и vpn-cidrs.lst.

## HOWTO обновляем роутер
1. Ставим прошивку openwrt. Зависит от роутера.
3. Ставим скриптом AmneziaWG 
	`sh <(wget -O - https://raw.githubusercontent.com/Slava-Shchipunov/awg-openwrt/refs/heads/master/amneziawg-install.sh)`
4. Вручную настраиваем и включаем WiFi, создаем awg интерфейс с именем `amneziawg` и импортируем настройки awg. 
5. Накатить install-kpbr.sh
	`sh <(wget -O - https://raw.githubusercontent.com/kozian/kpbr/refs/heads/main/install-kpbr.sh)`

## Что делает скрипт

1. ✅ Удаляет dnsmasq и ставит dnsmasq-full
2. ✅ Создает nftset для VPN и WAN списков доменов
3. ✅ Настраивает dnsmasq для автоматического добавления доменов в nftset
4. ✅ Настраивает маркировку пакетов через nftables
5. ✅ Создает таблицы маршрутизации (vpnroute, wanroute)
6. ✅ Настраивает правила маршрутизации с автозапуском
7. ✅ Добавляет извесные геоблок или заблокированные CIDR в nftset

## Требования

- OpenWrt 24.10.2
- Настроенный VPN интерфейс `amneziawg`
- Доступ к репозиторию с файлами `nftset.conf` и `vpn-cirds.lst` (или сохраненные файлы в папке со скриптом)

## Установка

```bash
wget -qO- https://raw.githubusercontent.com/kozian/kpbr/refs/heads/main/install-kpbr.sh | sh
```

или скачать все и запустить

```bash
wget https://raw.githubusercontent.com/kozian/kpbr/refs/heads/main/install-kpbr.sh
wget https://raw.githubusercontent.com/kozian/kpbr/refs/heads/main/nftset.conf
wget https://raw.githubusercontent.com/kozian/kpbr/refs/heads/main/vpn-cidrs.lst
chmod +x install-kpbr.sh
./install-kpbr.sh
```

## Структура файлов после установки
```
/etc/
├── nftables.d/
│   ├── sets.nft          # NFT sets для доменов
│   ├── rules.nft         # Правила маркировки пакетов
│   └── vpn-cirds.lst     # Список CIDR для маршрутиации через vpn
├── dnsmasq.d/
│   └── nftset.conf       # Список доменов для nftset
├── iproute2/
│   └── rt_tables         # Таблицы маршрутизации
├── hotplug.d/
│   └── iface/
│       └── 25-firewall-user  # Автозапуск правил
└── firewall.user         # Скрипт firewall включает правила маршрутизации и добавляет CIDR
```

## Конфигурация

Если нужно изменить настройки, отредактируйте переменные в начале скрипта:

```bash
# Откуда скачивать nftset и CIDR файлы
REPO_URL="https://raw.githubusercontent.com/kozian/kpbr/refs/heads/main/"
NFTSET_FILE="nftset.lst"
CIDR_FILE="vpn-cidrs.lst"

# Наименование интерфейса для VPN
VPN_INTERFACE="amneziawg"
```

## Проверка работы

После установки проверьте настройки:

Можно проверить скриптом из репы
```bash
sh <(wget -O - https://raw.githubusercontent.com/kozian/kpbr/refs/heads/main/test-kpbr.sh)
```

Или вручную 
1. Проверка настройки nft 
  - nftset должны обе быть, будут наполняться по мерее использования. 
  - chain mangle_prerouting должен содержать правила маркировки для обоих сетов
  - если что-то не так - смотрим /etc/nftables.d/ set.nft rules.nft

```bash
nft list set inet fw4 vpn_domain_set
nft list set inet fw4 wan_domain_set
nft list chain inet fw4 mangle_prerouting
```

2. ip rules должны показывать лукапы из wanroute и vpnroute по маркировкам. Если нет - /etc/firewall.user смотрим наличие правил.
```bash
ip rule show
```

3. таблицы маршрутизации должны содержать default записи.
  - vpnroute на интерфейс vpn (amneziawg по инструкции)
  - wanroute на интерфейс WAN порта и gateway вышестоящего роутера\провайдера
  - если что-то отсутствует - смотрим /etc/firewall.user, возожно там ошибка. Например не тот интерфейс или IP. 

```bash
ip route show table vpnroute
ip route show table wanroute
```

4. Проверяем корректность конфигураций dnsmasq
  - важно! Если применить нерабочую конфигурацию - dnsmasq упадет и вы потеряете DHCP. Нужно будет явно указать IP для wifi\lan соединения на компе чтобы подключиться. 
  - скрипты установки и апдейта проверяют это перед применением. 
  - важно - проверять все конфиги. В нашем случае самое важное - nftset.conf, т.к. наличие там кривых имен может поломать сервис.

```bash
dnsmasq --test
dnsmasq --test --conf-file=/etc/dnsmasq.d/nftset.conf
```

5. Проверить работу PBR можно через echo-сервисы. 
  - Для теста можно использовать ip.kozian.cc - добавлен в список VPN
  - Сервисы ifconfig.io\ifconfig.me и некоторые другие чекеры добавлены в список WAN, чтобы не давать палить VPN. 
  - Важно! Curl не сработает с самого роутера. На нем запросы не идут через prerouting и не маркируются.

```bash
`curl https://ifconfig.me`  - должен показать IP WAN
`curl https://ip.kozian.cc` - должен показать IP VPN
```

## Автоматическое обновление

Скрипт `update-kpbr.sh` позволяет автоматически обновлять конфигурационные файлы из репозитория.

### Что делает скрипт обновления

- 📥 Скачивает новые версии файлов `nftset.conf` и `vpn-cidrs.lst` из репозитория
- 🔍 Проверяет наличие изменений (если изменений нет - выходит)
- 💾 Создает резервные копии текущих файлов с временной меткой
- 🔄 Обновляет файлы
- ✅ Валидирует конфигурацию (тест dnsmasq + выполнение firewall.user)
- ⚠️ В случае ошибок - откатывается к предыдущей версии
- 📝 Логирует все действия в `/var/log/kpbr-update.log`

### Ручной запуск
```bash
sh <(wget -O - https://raw.githubusercontent.com/kozian/kpbr/refs/heads/main/update-kpbr.sh)
```

### Настройка автоматического обновления через cron

1. Скачать скрипт
```bash
wget https://raw.githubusercontent.com/kozian/kpbr/refs/heads/main/update-kpbr.sh
chmod +x update-kpbr.sh
```

2. Настроить cron
  - Переходим в веб-консоль, раздел `System` (`Система`) > [Scheduled Tasks (Планировщик)](http://192.168.1.1/cgi-bin/luci/admin/system/crontab)
  - Вставить cron-строку по желаемой частоте обновлений (ниже)
  - `Save` (`Сохранить`)

Также можно на самом роутере через `crontab -e`

3. примеры строк для регулярного обновления
```bash
# Проверка обновлений каждый день в 3:00 ночи
0 3 * * * /root/update-kpbr.sh >> /var/log/kpbr-update.log 2>&1

# Проверка обновлений каждые 6 часов
0 */6 * * * /root/update-kpbr.sh >> /var/log/kpbr-update.log 2>&1

# Проверка обновлений каждую неделю в воскресенье в 2:00
0 2 * * 0 /root/update-kpbr.sh >> /var/log/kpbr-update.log 2>&1
```

**Примечание:** Убедитесь, что путь к скрипту корректный. В примерах выше используется `/root/update-kpbr.sh`.

### Проверка логов обновления

```bash
# Просмотр лога обновлений
cat /var/log/kpbr-update.log
```

### Резервные копии

Скрипт автоматически создает резервные копии перед обновлением:

- `/etc/dnsmasq.d/nftset.conf_YYYYMMDD_HHMMSS.bak`
- `/etc/nftables.d/vpn-cidrs.lst_YYYYMMDD_HHMMSS.bak`

Хранятся последние 5 резервных копий для каждого файла. Старые копии автоматически удаляются.

### Ручной откат к резервной копии

Если нужно вернуться к предыдущей версии вручную:

```bash
# Посмотреть доступные резервные копии
ls -la /etc/dnsmasq.d/*.bak
ls -la /etc/nftables.d/*.bak

# Восстановить из резервной копии (замените TIMESTAMP на нужную дату)
cp /etc/dnsmasq.d/nftset.conf_TIMESTAMP.bak /etc/dnsmasq.d/nftset.conf
cp /etc/nftables.d/vpn-cidrs.lst_TIMESTAMP.bak /etc/nftables.d/vpn-cidrs.lst

# Перезапустить сервисы
/etc/init.d/dnsmasq restart
/etc/firewall.user
```

## Troubleshooting

### Ошибка: "Could not detect WAN gateway or interface"

Убедитесь, что у вас настроен default route:
```bash
ip route
```

### Ошибка: "Failed to download nftset list"

Проверьте доступность репозитория:
```bash
wget https://raw.githubusercontent.com/kozian/kpbr/refs/heads/main/nftset.conf
```

### Ошибка при установке dnsmasq-full

Возможно нужно больше места. Проверьте:
```bash
df -h
```

### Обновление не работает

Проверьте лог для деталей:
```bash
cat /var/log/kpbr-update.log
```

Убедитесь, что скрипт имеет права на выполнение:
```bash
chmod +x /root/update-kpbr.sh
```

## Удаление

Для отката изменений:

```bash
# Удалить созданные файлы
rm -f /etc/nftables.d/sets.nft
rm -f /etc/nftables.d/rules.nft
rm -f /etc/dnsmasq.d/nftset.conf
rm -f /etc/firewall.user
rm -f /etc/hotplug.d/iface/25-firewall-user

# Удалить правила из rt_tables
sed -i '/vpnroute/d' /etc/iproute2/rt_tables
sed -i '/wanroute/d' /etc/iproute2/rt_tables

# Удалить правила маршрутизации
ip rule del fwmark 0x1 lookup vpnroute
ip rule del fwmark 0x2 lookup wanroute

# Перезапустить сервисы
/etc/init.d/firewall restart
/etc/init.d/dnsmasq restart
```

## Лицензия

Скрипт распространяется "как есть" без каких-либо гарантий.
Сделано с помощью claude code.
