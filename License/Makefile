all: lib
	gcc -g -o demo demo.c -L. -lakalicense

lib:	license.c
	(cd md5; make)
	gcc -g -c license.c
	ar cr libakalicense.a license.o md5/*.o
	ranlib libakalicense.a


clean:
	rm -f demo *.a *.o
