#!/usr/bin/perl -w

my $tty = `/usr/bin/tty`;
if ( $tty =~ m#([^/^\r^\n]+)$# ){
	$tty = $1;
}else{
	print "Permission denied.\n";
	exit -1;
}

if ( 'tty1' ne $tty ){
	print "Permission denied.\n";
	exit -1;
}

while ( 1 ){
	system ( 'clear' );
	print <<_MENU_;

	CLI Menu:

	1. restore default settings.
	2. reboot.
	3. shutdown.
	4. quit.

	
_MENU_

	$cmd = <STDIN>;
	chomp $cmd;

	last if ( 4==$cmd );

	if ( 1==$cmd ){
		&restore_default;
	}elsif ( 2==$cmd ){
		system ( '/sbin/reboot' );
	}elsif ( 3==$cmd ){
		system ( '/sbin/shutdown -h now' );
	}

	print "\tOK, Press Enter to continue...";
	<STDIN>;
}
exit 0;

sub restore_default()
{
	system ( 'cat /home/NoSPAM/etc/NoSPAM.default.conf > /home/NoSPAM/etc/NoSPAM.conf; chown nospam /home/NoSPAM/etc/NoSPAM.conf' );
}
