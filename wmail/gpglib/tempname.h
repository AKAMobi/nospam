#ifndef tempname_h
#define tempname_h
/*
** Copyright 2001 Double Precision, Inc.  See COPYING for
** distribution information.
*/

static const char tempname_h_rcsid[]="$Id$";

#include "config.h"

#ifdef  __cplusplus
extern "C" {
#endif

#define TEMPNAMEBUFSIZE	64

int mimegpg_tempfile(char *);

#ifdef  __cplusplus
} ;
#endif

#endif
