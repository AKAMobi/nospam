#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#define NOSPAM_BINARY "/home/NoSPAM/bin/NoSPAM"

int main( int argc, char* argv[] )
{
	//execvp(argv[1], argv+1);
	//strcpy ( argv[0], QNS_BINARY );

	setuid ( 0 );
	setgid ( 0 );

	seteuid ( 0 );
	setegid ( 0 );

	execvp( NOSPAM_BINARY, argv );

	exit ( 250 );
}

