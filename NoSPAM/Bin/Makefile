all: qns_loader wi

QNSLIB=-lsocket++ -lboost_filesystem-gcc-1_31 -lboost_date_time-gcc-s-1_31

qns_loader: qns_loader.cpp
	g++ -O2 -o qns_loader -Wall qns_loader.cpp -D_GNU_SOURCE ${QNSLIB}
	strip qns_loader

wi: wi.c
	gcc -O2 -o wi wi.c
	strip wi

clean:
	rm -f *.o wi qns_loader

qns_loader-dev: qns_loader.cpp
	g++ -g -o qns_loader-dev -Wall qns_loader.cpp -D_GNU_SOURCE ${QNSLIB}



qns_loader_old: qns_loader.c
	gcc -o qns_loader -O2 -Wall qns_loader.c -D_GNU_SOURCE
	chmod +s qns_loader

