/*
** Copyright 2000 Double Precision, Inc.
** See COPYING for distribution information.
*/
#include	"config.h"
#include	<sys/types.h>
#include	<sys/socket.h>
#include	<sys/uio.h>
#include	<stdlib.h>
#include	<stdio.h>
#include	<unistd.h>

static const char rcsid[]="$Id$";

#define	q2(x)	# x
#define	q(x)	q2(x)

#define	DEF(x)	char sox_n_ ## x[] = q(x);

#if	SOX_DYNAMIC

char sox_n_init[]="SOCKSinit";

DEF(getpeername)
DEF(getsockname)
DEF(accept)
DEF(recvfrom)
DEF(connect)
DEF(listen)
DEF(select)
DEF(bind)
DEF(close)
DEF(dup)
DEF(dup2)
DEF(sendto)
DEF(read)
DEF(write)

#else
int	sox_init(char *p)
{
	return (0);
}
#endif
