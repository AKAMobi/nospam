#!/usr/bin/perl -w

#
# Ed Li <zixia@zixia.net> 2004-06-14
# 先将 usr/lib/perl module & post_install 做成 prepare 的安装包，然后删除这部分内容，再做 prepare 调用的安装包
#

$NSVER='2.3-12.12';

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
	next if $pkg eq 'tmp';
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
	if ( $not_tarball ){
		`cp -Raf * ../tmp` 
	}else{
		`cp -Raf post_proc.sh ../tmp` if ( -f 'post_proc.sh' );
	}

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
`find ./tmp -type f -name ".#*" -exec rm -fv {} \\;`;
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

