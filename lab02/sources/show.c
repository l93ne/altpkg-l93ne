/*
 * Show - постраничный просмотр текстового файла.
 * Пробел - следующая страница, q или Esc - выход.
 */
#include <curses.h>
#include <stdio.h>
#include <stdlib.h>

int main(int argc, char *argv[])
{
    FILE *f;
    char *buf, *p, **lines;
    long size, i;
    int nlines = 0, top = 0, page, width, row, key;
    WINDOW *win;

    /* Ошибки диагностируются до перехода в экранный режим */
    if (argc < 2) {
        fprintf(stderr, "Usage: %s FILE\n", argv[0]);
        return 1;
    }
    f = fopen(argv[1], "r");
    if (f == NULL) {
        perror(argv[1]);
        return 2;
    }

    /* Файл целиком читается в оперативную память */
    fseek(f, 0, SEEK_END);
    size = ftell(f);
    rewind(f);
    buf = malloc(size + 1);
    if (buf == NULL || fread(buf, 1, size, f) != (size_t) size) {
        fprintf(stderr, "%s: read error\n", argv[1]);
        return 3;
    }
    buf[size] = '\0';
    fclose(f);

    /* Разбиение на строки: '\n' заменяется концом строки */
    for (i = 0; i < size; i++)
        if (buf[i] == '\n')
            nlines++;
    lines = malloc((nlines + 1) * sizeof(char *));
    if (lines == NULL) {
        fprintf(stderr, "%s: out of memory\n", argv[1]);
        return 3;
    }
    nlines = 0;
    for (p = buf, i = 0; i < size; i++) {
        if (buf[i] == '\n') {
            buf[i] = '\0';
            lines[nlines++] = p;
            p = buf + i + 1;
        }
    }
    if (p < buf + size)
        lines[nlines++] = p;    /* последняя строка без '\n' */

    initscr();                  /* переход в экранный режим */
    noecho();                   /* не отображать вводимые символы */
    cbreak();                   /* отключить построчную обработку ввода */
    curs_set(0);

    mvprintw(0, 0, "File: %s (%d lines)", argv[1], nlines);
    refresh();

    page = LINES - 1;
    width = COLS;
    win = newwin(page, width, 1, 0);    /* окно содержимого под строкой имени */
    keypad(win, TRUE);                  /* обработка функциональных клавиш */

    for (;;) {
        werase(win);
        for (row = 0; row < page && top + row < nlines; row++)
            mvwaddnstr(win, row, 0, lines[top + row], width);   /* усечение по ширине окна */
        wrefresh(win);

        key = wgetch(win);
        if (key == 'q' || key == 'Q' || key == 27)
            break;
        if ((key == ' ' || key == KEY_NPAGE) && top + page < nlines)
            top += page;
    }

    delwin(win);
    endwin();                   /* восстановление режима терминала */
    free(lines);
    free(buf);
    return 0;
}
