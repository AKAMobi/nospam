#!/usr/bin/perl -w

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
print "Tar to NoSPAM...\n";
`tar czvf ../Dist/ns-1.2-3.18.i386.rpm *`;
chdir '..';
`rm -fr tmp`;
