all: qns_loader

qns_loader_old: qns_loader.c
	gcc -o qns_loader -O2 -Wall qns_loader.c -D_GNU_SOURCE
	chmod +s qns_loader

qns_loader: qns_loader.cpp
	g++ -O2 -g -o qns_loader -Wall qns_loader.cpp -D_GNU_SOURCE -lsocket++ -lboost_filesystem-gcc-1_31
