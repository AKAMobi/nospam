#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#define QNS_BINARY "/var/qmail/bin/ns-queue"

int main( int argc, char* argv[] )
{
	//execvp(argv[1], argv+1);
	//strcpy ( argv[0], QNS_BINARY );

	setuid ( 0 );
	setgid ( 0 );

	seteuid ( 0 );
	setegid ( 0 );

	execvp( QNS_BINARY, argv );

	fprintf ( stderr, "443 qns_loader error\n" );
}

