#!/bin/bash

# ./create-all-nftsets.sh                  - создаст nftset.conf с доменами wan\vpn и доменами ifcofnig для тестов
# ./create-all-nftsets.sh --no-test-hosts  - создаст nftset.conf с доменами wan\vpn без тестовых доменов
# ./create-all-nftsets.sh my-set.txt       - создаст my-set.txt с доменами wan\vpn

# Функция для обработки доменов из файла
process_domain_file() {
    local input_file="$1"
    local nftset_name="$2"

    # Проверка существования файла
    if [ ! -f "$input_file" ]; then
        echo "Ошибка: файл '$input_file' не найден" >&2
        return 1
    fi

    # Обработка каждого домена
    while IFS= read -r domain; do
        # Пропускаем пустые строки
        if [ -n "$domain" ]; then
            echo "nftset=/${domain}/4#inet#fw4#${nftset_name}"
        fi
    done < "$input_file"
}

NFTSET="nftset.conf"
ADD_TEST_HOSTS=true

# Парсинг аргументов командной строки
for arg in "$@"; do
    if [ "$arg" == "--no-test-hosts" ]; then
        ADD_TEST_HOSTS=false
    else
        # Если аргумент не опция, считаем его именем файла
        NFTSET="$arg"
    fi
done

# Очистка списка сетов
> ${NFTSET}

# Хосты для теста VPN/WAN (добавляются только с опцией --test-hosts)
if [ "$ADD_TEST_HOSTS" = true ]; then
    # Хосты для теста VPN
    echo "nftset=/ifconfig.me/4#inet#fw4#vpn_domain_set" >> ${NFTSET}

    # Хосты для теста WAN
    echo "nftset=/ifconfig.io/4#inet#fw4#wan_domain_set" >> ${NFTSET}
    echo "nftset=/kozian.ru/4#inet#fw4#wan_domain_set" >> ${NFTSET}
fi

# ip.kozian.cc - будет работать по дефолт пути
# ifconfig.me - всегда через VPN
# ifconfig.io - всегда через WAN

process_domain_file ./source/vpn-full.lst vpn_domain_set >> ${NFTSET}
process_domain_file ./source/wan-full.lst wan_domain_set >> ${NFTSET}
