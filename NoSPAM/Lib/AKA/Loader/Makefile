#
# AKA Perl Module Encrypt System
# Base on Filter::decrypt
#
# Author: Ed Li <zixia@zixia.net>
# Date: 2004-03-09
#

all: Loader.xs
	/usr/bin/perl /usr/lib/perl5/5.8.0/ExtUtils/xsubpp  -typemap /usr/lib/perl5/5.8.0/ExtUtils/typemap  Loader.xs > Loader.xsc && mv Loader.xsc Loader.c
	gcc -c   -D_REENTRANT -D_GNU_SOURCE -DTHREADS_HAVE_PIDS -DDEBUGGING -fno-strict-aliasing -I/usr/local/include -D_LARGEFILE_SOURCE -D_FILE_OFFSET_BITS=64 -I/usr/include/gdbm -O2 -march=i386 -mcpu=i686 -g   -DVERSION=\"1.20\" -DXS_VERSION=\"1.20\" -fPIC "-I/usr/lib/perl5/5.8.0/i386-linux-thread-multi/CORE"  -DBYPASS Loader.c
	LD_RUN_PATH="" gcc  -shared Loader.o  -o Loader.so     
	chmod 755 Loader.so

install:
	mv Loader.so /usr/lib/perl5/site_perl/5.8.0/i386-linux-thread-multi/auto/Filter/decrypt/Loader.so
	# decrypt.bs empty, zero size file, need to copy?
clean:
	rm -f Loader.so Loader.c Loader.o
