/*
** Copyright 2000 Double Precision, Inc.
** See COPYING for distribution information.
*/

/*
** $Id$
*/
#if	HAVE_CONFIG_H
#include	"config.h"
#endif

#include	"cgi.h"

#if	HAVE_UNISTD_H
#include	<unistd.h>
#endif

#include	<string.h>
#include	<stdlib.h>
#include	<stdio.h>

extern void error(const char *);

const char *cgirelscriptptr()
{
	const char *p=getenv("HTTPS");

	if (p && strcasecmp(p, "on") == 0)
		return (cgihttpsscriptptr());

	return (cgihttpscriptptr());
}
