#!/usr/bin/perl -w
$NSVER='2.0-4.23';

`chmod +s aka/home/NoSPAM/bin/wi aka/home/NoSPAM/bin/qns_loader`;
`rm -fr Dist/*.rpm`;
`rm -fr tmp`;
`mkdir tmp`;

#@tarballs = qw(qmail kernel network);
@tarballs = qw(qmail vpopmail wmail);

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
	`cp -Raf * ../tmp` if ( $not_tarball );
	chdir '..';
	
	chdir 'tmp';
	if ( -f 'post_proc.sh' ){
		print "Setting file mod & permissions for $pkg...\n";
		`sh post_proc.sh`;
		unlink 'post_proc.sh';
	}
	chdir '..';
}

print "Cleaning CVS & README info...\n";
`find ./tmp | grep CVS | xargs rm -fr`;
chdir 'tmp';
unlink 'README';

print "Modifying file owner & mode...\n";
`chown -R nospam home/NoSPAM/{etc,spool,log,var} home/vpopmail/domains var/qmail/control`;
`chown -R ssh home/ssh`;
`chmod -R o+rx home/{NoSPAM,ssh,vpopmail,wmail} var/qmail/control`;

print "Tar to NoSPAM prepare package...\n";
`tar czvf ../Dist/ks-$NSVER.i386.rpm root/post_install usr/lib`;
unlink 'root/post_install';
`rm -fr usr/lib`;

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
#`rm -fr tmp`;

