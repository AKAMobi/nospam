all: lib
	gcc -o demo demo.c -L. -lakalicense

lib:	license.c
	(cd md5; make)
	gcc -c license.c
	ar cr libakalicense.a license.o md5/*.o
	ranlib libakalicense.a


