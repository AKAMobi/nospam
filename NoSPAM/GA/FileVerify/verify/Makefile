GAverify: GAverify.o verify.o
	gcc -g -o GAverify GAverify.o verify.o rsaref.a
GAverify.o: GAverify.c
	gcc -g -I. -c GAverify.c
clean:
	rm -f GAverify.o GAverify
