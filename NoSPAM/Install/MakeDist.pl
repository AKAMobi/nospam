#!/usr/bin/perl -w
$NSVER='1.3-4.7';

`chmod +s aka/home/NoSPAM/bin/wi aka/home/NoSPAM/bin/qns_loader`;
`rm -fr Dist/*.rpm`;
`rm -fr tmp`;
`mkdir tmp`;

@tarballs = qw(qmail kernel network);

opendir(DIR, ".") || die "can't opendir .: $!\n";
@pkgs = grep { !/^\./ && (!/[A-Z]/) } readdir(DIR);
closedir DIR;

foreach $pkg ( @pkgs ){
	unless (-d $pkg){
		print "Skip file $pkg.\n";
		next;
	}
	print "Processing $pkg ...\n";
	chdir $pkg;
	$not_tarball = 1;
	foreach $tarball ( @tarballs ){
		if ( $pkg =~ /^$tarball$/ ){
			print "  $tarball is a tarball\n";
			chdir '../tmp';
			`tar zxvf ../$pkg/$pkg.ns`;
			chdir "../$pkg";
			$not_tarball = 0;
			last;
		}
	}
	`cp -Ra * ../tmp` if ( $not_tarball );
	chdir '..';
}

print "Cleaning CVS info...\n";
`find ./tmp | grep CVS | xargs rm -fr`;
chdir 'tmp';

print "Tar to NoSPAM prepare package...\n";
`tar czvf ../Dist/ns-prep-$NSVER.i386.rpm root/post_install usr/lib/perl5/site_perl/5.8.0/AKA/Loader.pm usr/lib/perl5/site_perl/5.8.0/i386-linux-thread-multi/auto/AKA/Loader/Loader.so`;
unlink 'root/post_install';

print "Tar to NoSPAM...\n";
`tar cvf ../Dist/ns-$NSVER.i386.rpm *`;
chdir '../Dist';
print "Zip & Encrypt to NoSPAM...\n";
`zip -P zixia\@noSPAM_OKBoy_GNULinux! ns-$NSVER.i386.rpm.zip ns-$NSVER.i386.rpm`;
print "Rename to NoSPAM...\n";
unlink "ns-$NSVER.i386.rpm";
rename "ns-$NSVER.i386.rpm.zip", "ns-$NSVER.i386.rpm";
chdir '..';
print "Clean tmp files...\n";
`rm -fr tmp`;
