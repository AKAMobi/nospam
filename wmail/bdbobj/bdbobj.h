#ifndef	bdbobj_h
#define	bdbobj_h

/*
** Copyright 1998 - 1999 Double Precision, Inc.  See COPYING for
** distribution information.
*/

static const char bdbobj_h_rcsid[]="$Id$";

#if HAVE_CONFIG_H
#include	"config.h"
#endif

#include	<sys/types.h>

#if HAVE_LIMITS_H
#include	<limits.h>
#endif

#include	<db.h>
#include	<stdlib.h>

#ifdef	__cplusplus
extern "C" {
#endif

struct bdbobj {
	DB	*dbf;
	int	has_dbf;

#if	DB_VERSION_MAJOR >= 2
	DBC	*dbc;
	int	has_dbc;
#endif
	} ;

void bdbobj_init(struct bdbobj *);

int bdbobj_open(struct bdbobj *, const char *, const char *);
void bdbobj_close(struct bdbobj *);

#define	bdbobj_isopen(p)	(!!(p)->has_dbf)

char	*bdbobj_fetch(struct bdbobj *, const char *, size_t, size_t *, const char *);

int	bdbobj_exists(struct bdbobj *, const char *, size_t);
int	bdbobj_delete(struct bdbobj *, const char *, size_t);
int	bdbobj_store(struct bdbobj *, const char *, size_t, const char *,
		size_t, const char *);

char	*bdbobj_firstkey(struct bdbobj *, size_t *, char **, size_t *);
char	*bdbobj_nextkey(struct bdbobj *, size_t *, char **, size_t *);

#ifdef	__cplusplus
} ;

class BDbObj {
	struct bdbobj	obj;

	BDbObj(const BDbObj &);			// Undefined
	BDbObj	&operator=(const BDbObj &);		// Undefined
	char	*do_fetch(const char *, size_t, size_t &);
	char	*do_query(const char *, size_t, size_t &, const char *);

public:
	BDbObj() { bdbobj_init(&obj); }
	~BDbObj()	{ bdbobj_close(&obj); }
	int	Open(const char *filename, const char *mode)
		{
			return (bdbobj_open(&obj, filename, mode));
		}

	int	IsOpen() { return (bdbobj_isopen(&obj)); }
	void	Close() { bdbobj_close(&obj); }
	char	*Fetch(const char *key, size_t keylen, size_t &vallen,
		const char *mode)
		{
			return (bdbobj_fetch(&obj, key, keylen, &vallen, mode));
		}
	int	Exists(const char *key, size_t keylen)
		{
			return (bdbobj_exists(&obj, key, keylen));
		}
	int	Delete(const char *key, size_t keylen)
		{
			return (bdbobj_delete(&obj, key, keylen));
		}

	int	Store(const char *key, size_t keylen, const char *val,
			size_t vallen, const char *mode)
		{
			return (bdbobj_store(&obj, key, keylen, val, vallen,
				mode));
		}

	char	*FetchFirstKeyVal(size_t &keylen, char *&val, size_t &vallen)
		{
			return (bdbobj_firstkey(&obj, &keylen, &val, &vallen));
		}
	char	*FetchNextKeyVal(size_t &keylen, char *&val, size_t &vallen)
		{
			return (bdbobj_nextkey(&obj, &keylen, &val, &vallen));
		}
} ;

#endif

#endif
