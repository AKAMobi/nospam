/*
** Copyright 1998 - 1999 Double Precision, Inc.  See COPYING for
** distribution information.
*/

#include	"authmod.h"
#include	"authwait.h"
#if	HAVE_UNISTD_H
#include	<unistd.h>
#endif
#include	<stdlib.h>
#include	<signal.h>

static const char rcsid[]="$Id$";

const char *authmodclient()
{
int	waitstat;
const	char *p;

	signal(SIGCHLD, SIG_DFL);

	while (wait(&waitstat) >= 0)
		;
	close(3);

	p=getenv("AUTHENTICATED");
	if (!p || !*p)
		authmod_fail_completely();
	return (p);
}
