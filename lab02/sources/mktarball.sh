#!/bin/sh -e
# Формирует архив исходных текстов show-l93ne-1.0.tar.gz в каталоге $1 (по умолчанию - текущий).
name=show-l93ne-1.0
src=$(cd "$(dirname "$0")" && pwd)
out=$(cd "${1:-.}" && pwd)
tmp=$(mktemp -d)
mkdir "$tmp/$name"
cp "$src/show.c" "$src/Makefile" "$tmp/$name/"
# архивируем из каталога размещения, чтобы в архив не попали лишние элементы пути
tar -C "$tmp" -czf "$out/$name.tar.gz" "$name"
rm -rf "$tmp"
echo "$out/$name.tar.gz"
