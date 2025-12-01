# Ссылки и материалы
[openwrt.org статья](https://openwrt.org/toh/cudy/tr3000)
[OpenWRT прошивки](https://firmware-selector.openwrt.org)
[Официальные прошивки CUDY](https://www.cudy.com/ru-by/pages/download-center/tr3000-1-0)
[Статья CUDY про intermediate firmware](https://www.cudy.com/ru-by/blogs/faq/openwrt-%D0%BF%D1%80%D0%BE%D0%B3%D1%80%D0%B0%D0%BC%D0%BC%D0%BD%D0%BE%D0%B5-%D0%BE%D0%B1%D0%B5%D1%81%D0%BF%D0%B5%D1%87%D0%B5%D0%BD%D0%B8%D0%B5-%D0%B7%D0%B0%D0%B3%D1%80%D1%83%D0%B7%D0%BA%D0%B0) и прямая ссылка на [google drive с прошивками](https://drive.google.com/drive/folders/1BKVarlwlNxf7uJUtRhuMGUqeCa5KpMnj), или прямая ссылка на [TR3000 V1_20251118.zip](https://drive.google.com/file/d/1VwGAQBuANHE9gHCzzAexqTTJrv06sgXt/view?usp=drive_link)

# Установка OpenWRT
Здесь будет рассмотрена простая установка через официальный образ-посредник, так как он простой и рабочий. 
Промежуточный образ нужен, так как базовые образы проверяют загружаемые прошивки и не дают установить не подписанные (в нашем случае ванильную OpenWRT). 

В статье на openwrt есть и другие варианты, если нужно.

**! Важно**: OpenWRT не включает wifi по-умолчанию, придется подключаться шнуром на определенном этапе. Так что рекомендуется сразу подключиться проводом. 

**! Важно**: Есть версия `Cudy TR3000 v1`, он же `Cudy TR30`. И есть другая модель `Cudy TR3000 256mb v1`. Прошивки у них отличаются. В инструкции ссылки именно для TR30\3000

### Скачиваем образы
1. Скачать официальный образ-посредник [TR3000 V1_20251118.zip](https://drive.google.com/file/d/1VwGAQBuANHE9gHCzzAexqTTJrv06sgXt/view?usp=drive_link) (или [отсюда](https://www.cudy.com/ru-by/blogs/faq/openwrt-%D0%BF%D1%80%D0%BE%D0%B3%D1%80%D0%B0%D0%BC%D0%BC%D0%BD%D0%BE%D0%B5-%D0%BE%D0%B1%D0%B5%D1%81%D0%BF%D0%B5%D1%87%D0%B5%D0%BD%D0%B8%D0%B5-%D0%B7%D0%B0%D0%B3%D1%80%D1%83%D0%B7%D0%BA%D0%B0) переходим по ссылку на google disk и качаем прошивку для TR3000 V1. Важно - для 256mb версии отдельная прошивка!). Распаковываем. На момент написания файл назывался `cudy_tr3000-v1-sysupgrade_20251112_release.bin`.
2. Скачать [Cudy TR3000 v1](https://firmware-selector.openwrt.org/?version=24.10.4&target=mediatek%2Ffilogic&id=cudy_tr3000-v1) прошивку openWRT, вариант `Sysupgrade`. На момент написания `openwrt-24.10.4-mediatek-filogic-cudy_tr3000-v1-squashfs-sysupgrade.bin`

### Обновляем прошивку на посредника
3. Подключаемся к роутеру, заходим на http://192.168.10.1/ 
	- Вводим пароль
	- Кликаем next-next-next, так как мы все равно все сотрем.
4. Переходим в  General Settings > [Firmware](http://192.168.10.1/cgi-bin/luci/admin/setup#tab-config-autoupgrade)
5. В нижней опции загрузки Firmware выбираем и загружаем первый скаченный образ `cudy_tr3000-v1-sysupgrade_20251112_release`
6. Ждем окончания загрузки, примерно 2 минуты

### Обновляем прошивку на OpenWRT
7. Подключаемся к роутеру, заходим http://192.168.1.1/ 
	- Пароль пустой. Просто нажимаем ввод
8. Переходим в Система (System) > [Восстановление / Обновление (Backup / Flash Firmware)](http://192.168.1.1/cgi-bin/luci/admin/system/flash) 
9. В нижнем меню "Установить новый образ прошивки" загружаем второй скаченный образ `openwrt-24.10.4-mediatek-filogic-cudy_tr3000-v1-squashfs-sysupgrade.bin`
	- Галочку "сохранить настройки" проще снять, так как мы ничего не настраивали. 
10. Ждем также пару минут, пока роутер не перезагрузится. Если долго висит сообщение "прошивка", можно вручную зайти http://192.168.1.1/ 

### Настраиваем OpenWRT
11. Настроить пароль
	- Или жмем кнопку на желтой плашке "Go to password configuration"
	- Или заходим System > [Administration](http://192.168.1.1/cgi-bin/luci/admin/system/admin)
	- Вводим пароль, нажимаем Save
12. Настроить wifi
	- Переходим Network > [Wireless](http://192.168.1.1/cgi-bin/luci/admin/network/wireless)
	- Напротив _disabled_ строчек нажимаем Edit и настраиваем в нижней части сеть
		- ESSID - это имя вашей сети
		- В закладке wireless security выбираем Encryption (рекомендуется WPA2-PSK/WPA3-SAE)
		- Key - указываем пароль для вайфая
	- Повторяем для второй _disabled_ строки
	- Нажимаем Save & Apply
	- После сохранения напротив каждой _disabled_ строки нажимаем `enable`
	- Вайфай запущен, можно отключить шнур и подключиться по вайфай
13. Опционально - руссифицируем интерфейс
    - Заходим на страницу System > [Software](http://192.168.1.1/cgi-bin/luci/admin/system/package-manager) 
    - Нажимаем кнопку `Update lists…`
    - В Filter вбиваем luci-i18n-base-ru и напротив этого пакета нажимаем `Install...` В окне тоже нажимаем `Install`
    - После обновления страницы все будет на русском. 

Все, ваш роутер обновлен до OpenWRT выбраной версии и произведена базовая настройка.
Дальше переходим к инструкции настройки VPN.