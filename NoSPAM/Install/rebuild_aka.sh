#!/bin/sh

# cpperl src.pl dst.pl
cpperl()
{
	echo "cpperl $1 to $2..."
	echo '#!/usr/bin/perl -X' > $2;
	echo 'open (NSOUT, ">&=2"); close STDERR;' >> $2;
	echo 'my $AKA_noSPAM_release = 1;' >> $2;
	cat $1 >> $2;
}

SOURCEHOME="/NoSPAM/"

echo "Making perl module directorys"
mkdir -p aka/usr/lib/perl5/site_perl/5.8.0/i386-linux-thread-multi/auto/AKA/
mkdir -p aka/usr/lib/perl5/site_perl/5.8.0/AKA/Mail/Police/Conf
mkdir -p aka/root
mkdir -p aka/home/NoSPAM/bin
mkdir -p aka/var/qmail/bin

######
#
# Perl Modules
#
########3
echo "Deleting old file..."
rm -fvr aka/usr/lib/perl5/site_perl/5.8.0/AKA/

echo "Copying source files..."
cp -Rv ${SOURCEHOME}/Lib/AKA aka/usr/lib/perl5/site_perl/5.8.0/

echo "Deleteing Loader source & CVS:"
rm -fvr aka/usr/lib/perl5/site_perl/5.8.0/AKA/Loader
find aka/usr/lib/perl5/site_perl/5.8.0/AKA | grep CVS | xargs rm -fr

echo "Encrypting..."
find aka/usr/lib/perl5/site_perl/5.8.0/AKA | grep pm$ | grep -v CVS | grep -v Loader | xargs ${SOURCEHOME}/Admin/factory/encrypt 


######
#
# NoSPAM Utils
#
########3
echo "Deleting old file..."
rm -fvr aka/home/NoSPAM/bin/{NoSPAM,ns-daemon,smtp_auth_proxy,UpdateRule,UploadLog}
rm -fvr aka/root/post_install

echo "Copying source files..."
cpperl ${SOURCEHOME}/Bin/NoSPAM.pl aka/home/NoSPAM/bin/NoSPAM.pl
cpperl ${SOURCEHOME}/Bin/ns-daemon.pl aka/home/NoSPAM/bin/ns-daemon.pl
cpperl ${SOURCEHOME}/Bin/ga-daemon.pl aka/home/NoSPAM/bin/ga-daemon.pl
cpperl ${SOURCEHOME}/Bin/smtp_auth_proxy.pl aka/home/NoSPAM/bin/smtp_auth_proxy.pl
cpperl ${SOURCEHOME}/Bin/rrdgraph.pl aka/home/NoSPAM/bin/rrdgraph.pl
chmod 755 aka/home/NoSPAM/bin/*.pl
cpperl ${SOURCEHOME}/Bin/NoSPAM.pl aka/root/post_install.pl
chmod 755 aka/root/*.pl

cpperl ${SOURCEHOME}/Bin/ns-queue.pl aka/var/qmail/bin/ns-queue.pl
chmod 755 aka/var/qmail/bin/ns-queue.pl

#rm -f aka/var/qmail/bin/ins-queue
#ln -s ns-queue aka/var/qmail/bin/ins-queue

echo "Encrypting..."
${SOURCEHOME}/Admin/factory/encrypt aka/home/NoSPAM/bin/*.pl
${SOURCEHOME}/Admin/factory/encrypt aka/root/*.pl
${SOURCEHOME}/Admin/factory/encrypt aka/var/qmail/bin/*.pl

echo "Compiling qns_loader & wi  source"
gcc -O2 -o aka/home/NoSPAM/bin/qns_loader ${SOURCEHOME}/Bin/qns_loader.c -D_GNU_SOURCE
gcc -o aka/home/NoSPAM/bin/wi ${SOURCEHOME}/Bin/wi.c

echo "Changing qns_loader & wi permission"
chown root aka/home/NoSPAM/bin/{qns_loader,wi}
chmod +s aka/home/NoSPAM/bin/{qns_loader,wi}
chmod -R o+r aka/* 

echo "Cleaning cvs rubbish"
find aka -type f -name ".#*" -exec rm -fv {} \;

