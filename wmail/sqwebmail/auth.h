/*
** Copyright 1998 - 2001 Double Precision, Inc.  See COPYING for
** distribution information.
*/


/*
** $Id$
*/
#ifndef	auth_h
#define	auth_h

extern int prelogin(const char *);
extern const char *login(const char *, const char *, int *);

extern const char *login_returnaddr();
extern const char *login_fromhdr();

extern int login_changepwd(const char *, const char *, const char *, int *);

#endif
