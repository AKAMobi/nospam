# $Id$
#
# Copyright 2000-2002 Double Precision, Inc.  See COPYING for
# distribution information.

AUTOMAKE = srcdir=${srcdir} @SHELL@ ${srcdir}/../automake.fix @AUTOMAKE@

EXTRA_DIST=ldapaddressbook.dist
noinst_LIBRARIES=libaddressbook.a
noinst_SCRIPTS=ldapsearch

libaddressbook_a_SOURCES=abookadd.c abookdel.c abookfind.c abookread.c \
	abooksearch.c ldapaddressbook.h
