all: GAsign

CC = gcc -O2 -Wall
LIB = rsaref.a


GAsign: GAsign.o sign.o $(LIB)
	$(CC) -o GAsign GAsign.o sign.o $(LIB)
	
clean:
	rm GAsign GAsign.o

GAsign.o:
	$(CC) -c GAsign.c
