#!/bin/bash
# Функциональная проверка лабораторной работы № 2 (задания 1-7).
# Запуск: lab02/check/check-lab02.sh  (из любого каталога клона репозитория)
# Группы проверок: обычные; в псевдотерминале (script); в изолированном окружении hasher.
# Проверки hasher пропускаются (SKIP), если окружение недоступно.
# Переменные окружения: HSH - каталог hasher (по умолчанию ~/hasher),
#                       ART - каталог для собранных пакетов (по умолчанию ~/artifacts/lab02).
set -u

cd "$(dirname "$0")/.." || exit 2
LAB=$PWD
HSH="${HSH:-$HOME/hasher}"
ART="${ART:-$HOME/artifacts/lab02}"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

PKG=show-l93ne
NVR="$PKG-1.0-alt1"
HELLO=hello-l93ne
HELLO_NVR="$HELLO-1.0-alt2"
SRC=/usr/src
BIN="$SRC/RPM/RPMS/x86_64/$NVR.x86_64.rpm"
REPO="$HSH/repo"
ARCH=$(uname -m)
# shellcheck disable=SC1091,SC2154
PACKAGER=$(. env/hasher-config && echo "$packager")
export TERM=xterm-256color

pass=0
fail=0
skip=0

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

have_hasher() { command -v hsh > /dev/null && id -Gn | grep -qw hashman && mkdir -p "$HSH" 2> /dev/null; }
have_pts() { grep -qs '^allowed_mountpoints=.*/dev/pts' /etc/hasher-priv/system; }

# Проверка в изолированном окружении: пропускается, если hasher недоступен
hcheck() {
    if [ "$HAVE_HSH" = yes ]; then
        check "$@"
    else
        echo "SKIP  $1"
        skip=$((skip + 1))
    fi
}

# Проверка, которой нужен псевдотерминал внутри окружения
pcheck() {
    if [ "$HAVE_HSH" = yes ] && have_pts; then
        check "$@"
    else
        echo "SKIP  $1"
        skip=$((skip + 1))
    fi
}

inb() { hsh-run "$HSH" -- /bin/sh -c "$1"; }
inr() { hsh-run --rooter "$HSH" -- /bin/sh -c "$1"; }
init() { hsh --initroot-only --packager="$PACKAGER" "$HSH"; }
# Запись сеанса: пробел, пробел, выход
session() { (cd check && ./ptyrec.sh "$1" sample.txt "$2"); }
body() { sed '1d;$d' "$1"; }

# --- Задание 1 ---
t1_clear() { cmp <(printf '\033[H\033[2J') <(tput -x clear); }
t1_stty() {
    local f=logs/stty-before.txt
    grep -q 'intr = \^C' $f && grep -q ' erase = \^?' $f && grep -q 'kill = \^U' $f && grep -q 'eof = \^D' $f
}
t1_infocmp() {
    [ "$(infocmp vt100 | wc -l)" -ne "$(infocmp xterm-256color | wc -l)" ] &&
        ! diff <(infocmp -1 vt100) <(infocmp -1 xterm-256color)
}
t1_man() {
    xz -dc /usr/share/man/man1/ls.1.xz | GROFF_NO_SGR=1 nroff -man > "$TMP/ls.txt" 2> /dev/null
    grep -qP '(.)\x08\1' "$TMP/ls.txt" && grep -qP '_\x08[A-Za-z]' "$TMP/ls.txt" &&
        grep -q '4e 08 4e' logs/t1-man-hexdump.txt
}

# --- Задание 2 ---
t2_link() {
    ! gcc sources/show.c -o "$TMP/Show" 2> "$TMP/link.err" && grep -q 'undefined reference' "$TMP/link.err" &&
        grep -q 'undefined reference' logs/t2-link-error.txt &&
        gcc sources/show.c -lncurses -o "$TMP/Show"
}
t2_errors() {
    local out
    out=$("$TMP/Show" 2> "$TMP/e1") && return 1
    [ -z "$out" ] && [ -s "$TMP/e1" ] || return 1
    out=$("$TMP/Show" /no/such/file 2> "$TMP/e2") && return 1
    [ -z "$out" ] && [ -s "$TMP/e2" ]
}
t2_session() {
    session "$TMP/Show" "$TMP/host.ts" &&
        grep -q 'sample.txt' "$TMP/host.ts" && grep -q "$(head -n 1 check/sample.txt)" "$TMP/host.ts"
}
t2_stty() {
    printf '  q' | script -qec "sh -c 'stty -a > $TMP/a; $TMP/Show check/sample.txt; stty -a > $TMP/b'" /dev/null > /dev/null
    [ -s "$TMP/a" ] && diff "$TMP/a" "$TMP/b"
}

# --- Задание 3 ---
t3_make() { make -C sources clean && make -C sources && [ -x sources/Show ]; }
t3_uptodate() {
    LC_ALL=C make -C sources | grep -q 'up to date' &&
        touch sources/show.c && LC_ALL=C make -C sources | grep -q '^gcc'
}
t3_clean() { make -C sources clean && ! ls sources/Show sources/*.o; }
t3_tab() {
    [ "$(grep -cP '^\t' sources/Makefile)" -ge 2 ] &&
        [ "$(grep -P '^\t' sources/Makefile | head -c 1 | od -An -tx1 | tr -d ' ')" = 09 ]
}
t3_spaces() {
    sed 's/^\t/        /' sources/Makefile > "$TMP/Makefile.spaces"
    ! LC_ALL=C make -C sources -f "$TMP/Makefile.spaces" 2> "$TMP/make.err" &&
        grep -q 'missing separator' "$TMP/make.err" && grep -q 'missing separator' logs/t3-missing-separator.txt
}

# --- Задание 4 ---
t4_fail_log() { grep -q 'packager name violation' logs/t4-build-fail.log; }
t4_macros() { init && inb "grep -F '$PACKAGER' \$HOME/.rpmmacros"; }
t4_devel() {
    local list
    hsh-install "$HSH" libncurses-devel || return 1
    list=$(inb 'rpm -qlv libncurses-devel') || return 1
    [ "$(echo "$list" | grep -c '\.h$')" -ge 1 ] && [ "$(echo "$list" | grep -c '^l.*\.so ')" -ge 1 ]
}
t4_srpm() {
    cp -f ../lab01/sources/$HELLO-1.0.sh specs/$HELLO.spec "$HSH/chroot/.in/" &&
        inb "cp /.in/$HELLO-1.0.sh \$HOME/RPM/SOURCES/ && cp /.in/$HELLO.spec \$HOME/RPM/SPECS/ && rpmbuild -bs \$HOME/RPM/SPECS/$HELLO.spec" &&
        mkdir -p "$ART" && cp -f "$HSH/chroot$SRC/RPM/SRPMS/$HELLO_NVR.src.rpm" "$ART/"
}
t4_rebuild() {
    hsh --packager="$PACKAGER" "$HSH" "$ART/$HELLO_NVR.src.rpm" &&
        [ "$(rpm -qp --qf '%{PACKAGER}' "$REPO/$ARCH/RPMS.hasher/$HELLO_NVR.noarch.rpm")" = "$PACKAGER" ]
}

# --- Задание 5 ---
t5_tarball() {
    sources/mktarball.sh "$TMP" &&
        [ "$(tar tzf "$TMP/$PKG-1.0.tar.gz" | sort | tr '\n' ' ')" = "$PKG-1.0/ $PKG-1.0/Makefile $PKG-1.0/show.c " ]
}
t5_build() {
    cp -f "$TMP/$PKG-1.0.tar.gz" specs/$PKG.spec check/sample.txt check/ptyrec.sh "$HSH/chroot/.in/" &&
        inb "cp /.in/$PKG-1.0.tar.gz \$HOME/RPM/SOURCES/ && cp /.in/$PKG.spec \$HOME/RPM/SPECS/ && rpmbuild -ba \$HOME/RPM/SPECS/$PKG.spec > \$HOME/build.log 2>&1" &&
        grep -q 'tar -xf' "$HSH/chroot$SRC/build.log" && grep -q 'make -j' "$HSH/chroot$SRC/build.log" &&
        mkdir -p "$ART/manual" &&
        cp -f "$HSH/chroot$BIN" "$HSH/chroot$SRC/RPM/SRPMS/$NVR.src.rpm" "$ART/manual/"
}
t5_files() { [ "$(rpm -qpl "$ART/manual/$NVR.x86_64.rpm")" = /usr/bin/Show ]; }
t5_session() {
    make -C sources && session ../sources/Show "$TMP/host5.ts" || return 1
    inr "rpm -q $PKG || rpm -i $BIN" || return 1
    hsh-run --mountpoints=/dev/pts "$HSH" -- /bin/sh -c "cd /.in && sh ptyrec.sh Show sample.txt \$HOME/chroot5.ts" || return 1
    diff <(body "$TMP/host5.ts") <(body "$HSH/chroot$SRC/chroot5.ts")
}

# --- Задание 6 ---
t6_requires() {
    local req
    req=$(rpm -qp --requires "$ART/manual/$NVR.x86_64.rpm") || return 1
    echo "$req" | grep -q '^libncurses\.so\.6' && ! echo "$req" | grep -q devel &&
        ! grep -q '^Requires' specs/$PKG.spec
}
t6_fail() {
    init || return 1
    cp -f "$ART/manual/$NVR.x86_64.rpm" check/sample.txt check/ptyrec.sh "$HSH/chroot/.in/"
    ! inr "rpm -i /.in/$NVR.x86_64.rpm" 2> "$TMP/install.err" && grep -q 'libncurses\.so\.6' "$TMP/install.err"
}
t6_ok() {
    hsh-install "$HSH" libncurses6 || return 1
    cp -f "$ART/manual/$NVR.x86_64.rpm" check/sample.txt check/ptyrec.sh "$HSH/chroot/.in/"
    inr "rpm -i /.in/$NVR.x86_64.rpm" && inb "rpm -q $PKG"
}
t6_no_devel() { ! inb 'rpm -q libncurses-devel'; }
t6_run() {
    hsh-run --mountpoints=/dev/pts "$HSH" -- /bin/sh -c "cd /.in && sh ptyrec.sh Show sample.txt \$HOME/chroot6.ts" &&
        grep -q "$(head -n 1 check/sample.txt)" "$HSH/chroot$SRC/chroot6.ts"
}

# --- Задание 7 ---
t7_build() {
    hsh --packager="$PACKAGER" "$HSH" "$ART/manual/$NVR.src.rpm" &&
        [ -f "$REPO/$ARCH/RPMS.hasher/$NVR.$ARCH.rpm" ] && [ -f "$REPO/SRPMS.hasher/$NVR.src.rpm" ]
}
t7_debuginfo() { [ -f "$REPO/$ARCH/RPMS.hasher/$PKG-debuginfo-1.0-alt1.$ARCH.rpm" ]; }
t7_disjoint() {
    [ -z "$(comm -12 <(rpm -qpl "$REPO/$ARCH/RPMS.hasher/$NVR.$ARCH.rpm" | sort) \
        <(rpm -qpl "$REPO/$ARCH/RPMS.hasher/$PKG-debuginfo-1.0-alt1.$ARCH.rpm" | sort))" ]
}
t7_arch() { [ -d "$REPO/$ARCH/RPMS.hasher" ] && [ -d "$REPO/SRPMS.hasher" ]; }

if have_hasher; then HAVE_HSH=yes; else HAVE_HSH=no; fi
echo "Каталог работы: $LAB; hasher: $HAVE_HSH"

echo "== Задание 1. Терминал и управляющие последовательности"
check "1.1 последовательности очистки экрана совпадают" t1_clear
check "1.2 в stty-before.txt есть intr, erase, kill, eof" t1_stty
check "1.3 описания vt100 и xterm-256color различаются" t1_infocmp
check "1.4 двойная печать и подчёркивание в странице руководства" t1_man
echo "== Задание 2. Приложение Show"
check "2.1 без -lncurses сборка не проходит, с -lncurses проходит" t2_link
check "2.2 ошибки запуска: ненулевой код и сообщение в stderr" t2_errors
check "2.3 сеанс в псевдотерминале: имя файла и первая строка" t2_session
check "2.4 параметры терминала после завершения восстановлены" t2_stty
echo "== Задание 3. Сборка средствами make"
check "3.1 make создаёт исполняемый файл" t3_make
check "3.2 повторный make не пересобирает, после touch пересобирает" t3_uptodate
check "3.3 make clean удаляет продукты сборки" t3_clean
check "3.4 строки рецептов начинаются с байта 09" t3_tab
check "3.5 пробелы вместо табуляции: missing separator" t3_spaces
echo "== Задание 4. Окружение и сведения о сопровождающем"
check "4.1 журнал сборки без настройки содержит нарушение packager" t4_fail_log
hcheck "4.2 сопровождающий попадает в .rpmmacros окружения" t4_macros
hcheck "4.3 devel-пакет в окружении: заголовки и ссылка на .so" t4_devel
hcheck "4.4 пакет с исправленным журналом изменений собран в src.rpm" t4_srpm
echo "== Задание 5. Архив исходных текстов и spec-файл"
check "5.1 архив содержит один каталог имя-версия с исходниками" t5_tarball
hcheck "5.2 сборка: развёртывание архива и вызов make" t5_build
hcheck "5.3 в пакете ровно один файл /usr/bin/Show" t5_files
pcheck "5.4 сеансы на хосте и в окружении совпадают" t5_session
hcheck "4.5 повторная сборка успешна, сопровождающий в метаданных" t4_rebuild
echo "== Задание 6. Сборочные и эксплуатационные зависимости"
hcheck "6.1 зависимость от libncurses.so.6 вычислена, devel нет" t6_requires
hcheck "6.2 без библиотеки установка не проходит" t6_fail
hcheck "6.3 с основной библиотекой пакет устанавливается" t6_ok
hcheck "6.4 devel-пакет в окружении отсутствует" t6_no_devel
pcheck "6.5 программа запускается в окружении" t6_run
echo "== Задание 7. Локальный репозиторий и отладочный подпакет"
hcheck "7.1 автоматическая сборка: двоичный пакет и src.rpm" t7_build
hcheck "7.2 сформирован подпакет debuginfo" t7_debuginfo
hcheck "7.3 перечни файлов пакета и debuginfo не пересекаются" t7_disjoint
hcheck "7.4 каталог репозитория соответствует uname -m" t7_arch

echo "ИТОГО: пройдено $pass, не пройдено $fail, пропущено $skip"
[ "$fail" -eq 0 ]
