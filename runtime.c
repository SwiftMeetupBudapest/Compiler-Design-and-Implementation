//
// runtime.c
// Minimalist "runtime" / startup support for SwiSwi
//
// Created by Arpad Goretity "H2CO3"
// for the Budapest Swift Meetup
//
// There's absolutely no warranty of any kind.
//

#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include <string.h>
#include <stdint.h>
#include <inttypes.h>
#include <limits.h>
#include <math.h>


typedef double Double;
typedef int64_t Int;

typedef struct {
	char *buf;
	Int size;
} String;

String __string_literal(char *c_string) {
	return (String){ strdup(c_string), strlen(c_string) };
}

void __string_destroy(String *str)
{
	free(str->buf);
}

extern void swimain(Int);

String intToString(Int n) {
	size_t len = snprintf(NULL, 0, "%" PRIi64, n);
	char *buf = malloc(len + 1);
	snprintf(buf, len + 1, "%" PRIi64, n);
	return (String){ buf, len };
}

String doubleToString(Double x) {
	size_t len = snprintf(NULL, 0, "%lf", x);
	char *buf = malloc(len + 1);
	snprintf(buf, len + 1, "%lf", x);
	return (String){ buf, len };
}

String getLine() {
	char buf[LINE_MAX] = { 0 };
	fgets(buf, sizeof buf, stdin);

	char *newline = strchr(buf, '\n');
	if (newline) {
		*newline = 0;
	}

	return (String){ strdup(buf), strlen(buf) };
}

Int stringToInt(String s) {
	return strtoll(s.buf, NULL, 10);
}

Double stringToDouble(String s) {
	return strtod(s.buf, NULL);
}

void print(String s) {
	fprintf(stdout, "%.*s\n", (int)s.size, s.buf);
	fflush(stdout);
}

void panic(String s) {
	fprintf(stderr, "SwiSwi PANIC: %.*s\n", (int)s.size, s.buf);
	fflush(stderr);
	abort();
}

int main(int argc, char *argv[]) {
	swimain(strtoll(argv[1], NULL, 10));
	return 0;
}
