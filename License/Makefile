all: lib
	gcc -o a.out test.c -L. -lmd5

lib:	mddriver.c md5c.c 
	gcc -c mddriver.c md5c.c
	ar cr libmd5.a mddriver.o md5c.o
	ranlib libmd5.a


