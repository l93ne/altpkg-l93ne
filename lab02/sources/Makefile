# Сборка программы Show
CC = gcc
CFLAGS = -O2 -Wall
LDLIBS = -lncurses

# Цель по умолчанию: исполняемый файл
Show: show.c
	$(CC) $(CFLAGS) $< $(LDLIBS) -o $@

# Удаление продуктов сборки
clean:
	rm -f Show *.o

.PHONY: clean
