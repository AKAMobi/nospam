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

	printf ( "license is valid? %s\n", 0==check_license_file ( "License.dat" )?"VALID":"INVALID" );
}



