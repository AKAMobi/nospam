all: lib
	gcc -o a.out test.c -L. -lakalicense

lib:	license.c
	gcc -c license.c
	ar cr libakalicense.a license.o md5/*.o
	ranlib libakalicense.a


