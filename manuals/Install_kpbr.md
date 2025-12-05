# install-kpbr.sh - kpbe Installation Script
## Предусловия
1. На роутере установлена OpenWRT. См. инструкцию для роутера, например для [CUDY TR3000](./CUDY-TR3000.md). 
2. На роутере настроен VPN. См. инструкцию [amnezia wg](./Install_amneziaWG.md).

## Установка
Все команды исполняются на роутере через SSH. 
Пароль - тот же какой был установлен при настройке роутера. 
```
ssh root@192.168.1.1
```

### Онлайн установка (рекоммендуется)

Скрипт сам скачает листы из репозитория и все установит.

```bash
wget -qO- https://raw.githubusercontent.com/kozian/kpbr/refs/heads/main/install-kpbr.sh | sh
```

### Оффлайн установка

Скачать файлы и подложить на роутер можно вручную, если есть такая необходимость. 
Или если есть желание посмотреть файлы перед установкой. 

```bash
wget https://raw.githubusercontent.com/kozian/kpbr/refs/heads/main/install-kpbr.sh
wget https://raw.githubusercontent.com/kozian/kpbr/refs/heads/main/nftset.conf
wget https://raw.githubusercontent.com/kozian/kpbr/refs/heads/main/vpn-cidrs.lst
chmod +x install-kpbr.sh
./install-kpbr.sh
```

## Проверка работы
### Проверка конфигурации
Команды, который показывают все созданные 

```bash
# Проверка nftsets
nft list set inet fw4 vpn_domain_set
nft list set inet fw4 wan_domain_set

# Проверка правил маршрутизации
ip rule show

# Проверка таблиц маршрутизации
ip route show table vpnroute
ip route show table wanroute

# Проверка конфигурации dnsmasq
dnsmasq --test
```

Проверить работу PBR можно через echo-сервисы. 
В тестовых целях ifconfig.me добавлен в список VPN, а ifconfig.io - WAN. 
`curl https://ifconfig.me`  - должен показать IP VPN
`curl https://ifconfig.io`  - должен показать IP WAN
`curl https://ip.kozian.cc` - должен показать IP маршрута по-умолчанию


## Автоматическое обновление

Скрипт `update-kpbr.sh` позволяет автоматически обновлять конфигурационные файлы из репозитория.

### Ручной запуск

```bash
sh <(wget -O - https://raw.githubusercontent.com/kozian/kpbr/refs/heads/main/update-kpbr.sh)
```

### Настройка автоматического обновления через cron

1. подключаемся по SSH `ssh root@192.168.1.1`
2. Сохраняем скрипт 
`cd /root && wget https://raw.githubusercontent.com/kozian/kpbr/refs/heads/main/update-kpbr.sh && chmod +x ./update-kpbr.sh`
3. Переходим в веб-консоль, раздел `System` (`Система`) > [Scheduled Tasks (Планировщик)](http://192.168.1.1/cgi-bin/luci/admin/system/crontab)
4. Вставить cron-строку по желаемой частоте обновлений
  - Каждый день в 3:00 ночи: `0 3 * * * /root/update-kpbr.sh >> /var/log/kpbr-update.log 2>&1`
  - Каждые 6 часов `0 */6 * * * /root/update-kpbr.sh >> /var/log/kpbr-update.log 2>&1`
  - Каждую неделю в воскресенье в 2:00 `0 2 * * 0 /root/update-kpbr.sh >> /var/log/kpbr-update.log 2>&1`
  - или подредактировать частоту по своему усмотрению
5. `Save` (`Сохранить`)

Более детально см. README.md в корне репозитория. Там покрыты темы
- Логов 
- Резервных копий списков