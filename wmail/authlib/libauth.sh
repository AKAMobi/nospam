# $Id$

SHELL="$1"
srcdir="$2"

tr ' ' '\012' | $SHELL ${srcdir}/libauth1.sh | $SHELL ${srcdir}/libauth2.sh \
	| $SHELL ${srcdir}/libauth1.sh

