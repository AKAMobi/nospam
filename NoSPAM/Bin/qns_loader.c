#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>

#define QNS_BINARY "/var/qmail/bin/ns-queue"
#define QINS_BINARY "/var/qmail/bin/ins-queue"

int main( int argc, char* argv[] )
{

	//execvp(argv[1], argv+1);
	//strcpy ( argv[0], QNS_BINARY );

	setuid ( 0 );
	setgid ( 0 );

	seteuid ( 0 );
	setegid ( 0 );

	if ( strstr(argv[0],"qins_loader") ){
		execvp( QINS_BINARY, argv );
	}else{
		execvp( QNS_BINARY, argv );
	}

	fprintf ( stderr, "443 qns_loader error\n" );
}

