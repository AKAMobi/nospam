#include <stdio.h>
#include <stdlib.h>

#include "license.h"

int
main (argc, argv) 
	register int argc; 
	register char *argv[]; 
{ 
	unsigned char prodno[1024];
	unsigned char license[1024];

	get_prodno ( prodno );
	printf ( "prodno: %s\n", prodno );

	check_license_file ( "/home/NoSPAM/etc/License.dat" );
}



