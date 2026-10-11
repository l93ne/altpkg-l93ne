#!/bin/bash
# Функциональная проверка лабораторной работы № 1 (задания 2-7).
# Запуск: lab01/check/check-lab01.sh  (из любого каталога клона репозитория)
# Переменные окружения: HSH - каталог hasher (по умолчанию ~/hasher),
#                       ART - каталог для собранных пакетов (по умолчанию ~/artifacts/lab01).
set -u

cd "$(dirname "$0")/.." || exit 2
HSH="${HSH:-$HOME/hasher}"
ART="${ART:-$HOME/artifacts/lab01}"

PKGS="rpm-build rpmdevtools hasher hasher-priv git-core gcc make tree diffutils openssh-clients shellcheck libncurses-devel"
LIB=libpng16
DEVEL=libpng-devel
HEADER=/usr/include/libpng16/png.h
NULLPKG=null-l93ne
PKG=hello-l93ne
NVR="$PKG-1.0-alt1"
NULLRPM="/usr/src/RPM/RPMS/noarch/$NULLPKG-1.0-alt1.noarch.rpm"
RPM="/usr/src/RPM/RPMS/noarch/$NVR.noarch.rpm"
AUTO="$HSH/repo/x86_64/RPMS.hasher/$NVR.noarch.rpm"

pass=0
fail=0

check() {
    local name=$1
    shift
    if "$@" > /dev/null 2>&1; then
        echo "PASS  $name"
        pass=$((pass + 1))
    else
        echo "FAIL  $name"
        fail=$((fail + 1))
    fi
}

# Команда в изолированном окружении от имени сборщика и служебного суперпользователя
inb() { hsh-run "$HSH" -- /bin/sh -c "$1"; }
inr() { hsh-run --rooter "$HSH" -- /bin/sh -c "$1"; }
# Команды hasher обращаются к сетевому репозиторию; при разовом сбое повторяем один раз
retry() { "$@" || { sleep 10 && "$@"; }; }

# --- Задание 2 ---
t2_repos() { apt-repo | grep -q 'p11'; }
t2_packages() {
    local p
    for p in $PKGS; do rpm -q "$p" || return 1; done
}
t2_service() { [ "$(systemctl is-enabled hasher-privd)" = enabled ] && [ "$(systemctl is-active hasher-privd)" = active ]; }
t2_files() {
    [ -s env/repos.txt ] && [ -s env/host-packages.txt ] &&
        [ "$(wc -l < env/host-packages.txt)" -eq "$(rpm -qa | wc -l)" ]
}

# --- Задание 3 ---
t3_devel_files() {
    local list
    list=$(rpm -qlv "$DEVEL") || return 1
    [ "$(echo "$list" | grep -c '\.h$')" -ge 1 ] && [ "$(echo "$list" | grep -c '^l.*\.so ')" -ge 1 ]
}
t3_owner() { [ "$(rpm -qf --qf '%{NAME}' "$HEADER")" = "$DEVEL" ]; }
t3_provides() { [ "$(rpm -q --whatprovides --qf '%{NAME}' "$LIB")" = "$LIB" ]; }
t3_logs() {
    local f
    for f in t3-requires.txt t3-provides.txt t3-whatrequires.txt t3-files-main.txt t3-files-devel.txt t3-qf.txt; do
        [ -s "logs/$f" ] || return 1
    done
}

# --- Задание 4 ---
t4_groups() {
    local u g
    u=$(id -un)
    g=" $(id -Gn) "
    [[ $g == *" hashman "* && $g == *" ${u}_a "* && $g == *" ${u}_b "* ]]
}
t4_init_log() { grep -q 'Created RPM build directory tree' logs/t4-hsh-init.log; }
t4_init() { [ -d "$HSH/chroot" ] || retry hsh --initroot-only "$HSH"; }
t4_users() {
    local b r
    b=$(inb 'id -un') && r=$(inr 'id -un') && [ "$b" = builder ] && [ "$r" = root ] && [ "$b" != "$r" ]
}
# shellcheck disable=SC2016
t4_tree() { inb 'for d in BUILD SOURCES SPECS RPMS SRPMS; do test -d "$HOME/RPM/$d" || exit 1; done'; }
t4_utility() { retry hsh-install "$HSH" tree && inb 'which tree'; }

# --- Задание 5 ---
t5_build() {
    cp -f "specs/$NULLPKG.spec" "$HSH/chroot/.in/" &&
        inb "cp /.in/$NULLPKG.spec \$HOME/RPM/SPECS/ && rpmbuild -ba \$HOME/RPM/SPECS/$NULLPKG.spec" &&
        inb "test -f $NULLRPM && test -f /usr/src/RPM/SRPMS/$NULLPKG-1.0-alt1.src.rpm"
}
t5_empty() { [ "$(inb "rpm -qpl $NULLRPM" 2> /dev/null | grep -c '^/')" -eq 0 ]; }
t5_meta() { [ "$(inb "rpm -qp --qf '%{NAME} %{VERSION} %{RELEASE} %{LICENSE}' $NULLRPM")" = "$NULLPKG 1.0 alt1 GPL-3.0-or-later" ]; }
t5_install() {
    inr "rpm -q $NULLPKG || rpm -i $NULLRPM" && inr "rpm -q $NULLPKG" && ! inr "which $NULLPKG"
}

# --- Задание 6 ---
t6_build() {
    cp -f "sources/$PKG-1.0.sh" "specs/$PKG.spec" "$HSH/chroot/.in/" &&
        inb "cp /.in/$PKG-1.0.sh \$HOME/RPM/SOURCES/ && cp /.in/$PKG.spec \$HOME/RPM/SPECS/ && rpmbuild -ba \$HOME/RPM/SPECS/$PKG.spec" &&
        mkdir -p "$ART/manual" &&
        cp -f "$HSH/chroot$RPM" "$HSH/chroot/usr/src/RPM/SRPMS/$NVR.src.rpm" "$ART/manual/"
}
t6_files() { [ "$(inb "rpm -qpl $RPM")" = "/usr/bin/$PKG" ]; }
t6_requires() {
    ! grep -q '^Requires' "specs/$PKG.spec" &&
        [ "$(inb "rpm -qp --requires $RPM" | grep -v '^rpmlib')" = /bin/sh ]
}
t6_run() {
    inr "rpm -q $PKG || rpm -i $RPM" && inr "$PKG" 2> /dev/null | diff - check/expected.txt
}
t6_remove() { inr "rpm -e $PKG" && ! inr "which $PKG" && ! inr "$PKG"; }

# --- Задание 7 ---
# Проверки sisyphus_check, неприменимые при локальной сборке, отключаются явно,
# чтобы результат не зависел от содержимого ~/.hasher/config
t7_build() { retry hsh --no-sisyphus-check=packager,changelog,buildhost,gpg "$HSH" "$ART/manual/$NVR.src.rpm" && [ -f "$AUTO" ]; }
t7_nvr() {
    [ "$(rpm -qp --qf '%{NAME}-%{VERSION}-%{RELEASE}' "$AUTO")" = "$(rpm -qp --qf '%{NAME}-%{VERSION}-%{RELEASE}' "$ART/manual/$NVR.noarch.rpm")" ]
}
t7_files() { diff <(rpm -qpl "$ART/manual/$NVR.noarch.rpm" | sort) <(rpm -qpl "$AUTO" | sort); }
payload_sum() { rpm2cpio "$1" | cpio -i --quiet --to-stdout "./usr/bin/$PKG" | sha256sum; }
t7_sha() { [ "$(payload_sum "$ART/manual/$NVR.noarch.rpm")" = "$(payload_sum "$AUTO")" ]; }
t7_envs() {
    local host chroot only
    [ -d "$HSH/chroot" ] || retry hsh --initroot-only "$HSH" || return 1
    host=$(rpm -qa --qf '%{NAME}\n' | sort -u)
    chroot=$(inb "rpm -qa --qf '%{NAME}\n'" | sort -u)
    only=$(comm -23 <(echo "$host") <(echo "$chroot"))
    [ "$(echo "$chroot" | wc -l)" -lt "$(echo "$host" | wc -l)" ] && echo "$only" | grep -qx git-core
}

echo "== Задание 2. Сборочное окружение хост-системы"
check "2.1 репозитории ветки p11 подключены" t2_repos
check "2.2 пакеты курса установлены" t2_packages
check "2.3 служба hasher-privd включена и запущена" t2_service
check "2.4 env/repos.txt и env/host-packages.txt актуальны" t2_files
echo "== Задание 3. Классификация зависимостей ($LIB / $DEVEL)"
check "3.1 в devel-пакете есть заголовки и ссылка на .so" t3_devel_files
check "3.2 заголовок принадлежит devel-пакету" t3_owner
check "3.3 whatprovides возвращает основной пакет" t3_provides
check "3.4 журналы команд сохранены" t3_logs
echo "== Задание 4. Изолированное сборочное окружение"
check "4.1 пользователь в группах hashman, *_a, *_b" t4_groups
check "4.2 в журнале есть создание дерева сборки RPM" t4_init_log
check "4.3 окружение развёрнуто" t4_init
check "4.4 сборщик и суперпользователь различаются" t4_users
check "4.5 дерево BUILD SOURCES SPECS RPMS SRPMS" t4_tree
check "4.6 утилита tree доступна в окружении" t4_utility
echo "== Задание 5. Пакет минимальной структуры ($NULLPKG)"
check "5.1 собраны двоичный пакет и пакет с исходным кодом" t5_build
check "5.2 перечень файлов пакета пуст" t5_empty
check "5.3 метаданные соответствуют преамбуле" t5_meta
check "5.4 пакет установлен, исполняемого файла нет" t5_install
echo "== Задание 6. Пакет с функциональностью ($PKG)"
check "6.1 пакет собран" t6_build
check "6.2 в пакете ровно один файл в /usr/bin" t6_files
check "6.3 зависимость /bin/sh вычислена, в spec не объявлена" t6_requires
check "6.4 вывод программы совпадает с эталоном" t6_run
check "6.5 после удаления программа недоступна" t6_remove
echo "== Задание 7. Воспроизводимость сборки"
check "7.1 автоматическая сборка из src.rpm" t7_build
check "7.2 имя, версия и релиз совпадают" t7_nvr
check "7.3 перечни файлов совпадают" t7_files
check "7.4 контрольные суммы исходного файла совпадают" t7_sha
check "7.5 в окружении меньше пакетов, чем в хост-системе" t7_envs

echo "ИТОГО: пройдено $pass, не пройдено $fail"
[ "$fail" -eq 0 ]
