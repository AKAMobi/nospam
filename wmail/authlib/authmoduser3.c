/*
** Copyright 1998 - 1999 Double Precision, Inc.  See COPYING for
** distribution information.
*/

#include	"auth.h"
#include	"authmod.h"
#include	"debug.h"
#include	<stdio.h>
#include	<string.h>
#include	<stdlib.h>
#include	<ctype.h>

static const char rcsid[]="$Id$";

void authmod_login(int argc, char **argv, const char *service,
	const char *userid,
	const char *passwd)
{
char	*p=malloc(strlen(userid)+strlen(passwd)+3);

	auth_debug_login( 1, "username=%s", userid );
	auth_debug_login( 2, "password=%s", passwd );

	if (!p)
	{
		perror("malloc");
		authexit(1);
	}
	strcat(strcat(strcat(strcpy(p, userid), "\n"), passwd), "\n");
	authmod(argc, argv, service, AUTHTYPE_LOGIN, p);
}
