#!/bin/sh

SOURCEHOME="/NoSPAM/"

echo "Making perl module directorys"
mkdir -p aka/usr/lib/perl5/site_perl/5.8.0/i386-linux-thread-multi/auto/AKA/
mkdir -p aka/usr/lib/perl5/site_perl/5.8.0/AKA/Mail/Police/Conf

######
#
# Perl Modules
#
########3
echo "Deleting old file..."
rm -fvr aka/usr/lib/perl5/site_perl/5.8.0/AKA/

echo "Copying source files..."
cp -Rv ${SOURCEHOME}/ContentFilter/AKA aka/usr/lib/perl5/site_perl/5.8.0/

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
rm -fvr aka/home/NoSPAM/bin/{NoSPAM,smtp_auth_proxy,UpdateRule,UploadLog}
rm -fvr aka/root/post_install

echo "Copying source files..."
cp -fv ${SOURCEHOME}/{NoSPAM.pl,smtp_auth_proxy.pl} aka/home/NoSPAM/bin
cp -fv ${SOURCEHOME}/ContentFilter/{UpdateRule.pl,UploadLog.pl} aka/home/NoSPAM/bin
cp -fv ${SOURCEHOME}/post_install.pl aka/root
cp -fv ${SOURCEHOME}/qmail-scanner-1.20/mini-ns-queue.pl aka/var/qmail/bin/ns-queue.pl
rm -f aka/var/qmail/bin/ins-queue
ln -s ns-queue aka/var/qmail/bin/ins-queue

echo "Encrypting..."
chmod 755 aka/home/NoSPAM/bin/*.pl
${SOURCEHOME}/Admin/factory/encrypt aka/home/NoSPAM/bin/*.pl
chmod 755 aka/root/*.pl
${SOURCEHOME}/Admin/factory/encrypt aka/root/*.pl
${SOURCEHOME}/Admin/factory/encrypt aka/var/qmail/bin/*.pl

echo "Compiling qns_loader & wi  source"
gcc -o aka/home/NoSPAM/bin/qns_loader ${SOURCEHOME}/qns_loader.c
rm -f aka/home/NoSPAM/bin/qins_loader
ln -s qns_loader aka/home/NoSPAM/bin/qins_loader
gcc -o aka/home/NoSPAM/bin/wi ${SOURCEHOME}/wi.c

echo "Changing qns_loader & wi permission"
chown root aka/home/NoSPAM/bin/{qns_loader,wi}
chmod +s aka/home/NoSPAM/bin/{qns_loader,wi}


