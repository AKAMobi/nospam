/*
** Copyright 1998 - 2003 Double Precision, Inc.
** See COPYING for distribution information.
*/

/*
** $Id$
*/
#if HAVE_LIBFCGI
#include <stdlib.h>
#include "fcgi_stdio.h"
#else
#include	<stdio.h>
#endif

void cginocache()
{
	printf("Cache-Control: no-store\n");
	printf("Pragma: no-cache\n");
}

/* MSIE sucks */

void cginocache_msie()
{
	printf("Cache-Control: private\n");
	printf("Pragma: private\n");
}
