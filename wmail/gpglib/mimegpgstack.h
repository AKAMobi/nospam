#ifndef mimegpgstack_h
#define mimegpgstack_h

/*
** Copyright 2001 Double Precision, Inc.  See COPYING for
** distribution information.
*/

static const char mimegpgstack_h_rcsid[]="$Id$";

#include "config.h"

#ifdef  __cplusplus
extern "C" {
#endif

struct mimestack {
	struct mimestack *next;
	char *boundary;
} ;

void push_mimestack(struct mimestack **, const char *);
void pop_mimestack(struct mimestack **);

struct mimestack *search_mimestack(struct mimestack *, const char *);

void pop_mimestack_to(struct mimestack **, struct mimestack *);

#ifdef  __cplusplus
} ;
#endif

#endif
