#!/usr/bin/perl -Tw

open (STDERR, ">/dev/null") or die "can't open STDERR\n";

$ENV{'PATH'} = '/bin:/sbin:/usr/bin:/usr/sbin';
delete @ENV{'IFS', 'CDPATH', 'ENV', 'BASH_ENV'};


my $tty = `/usr/bin/tty`;
if ( $tty =~ m#([^/^\r^\n]+)$# ){
	$tty = $1;
}else{
	print STDOUT "Permission denied.\n";
	sleep 5;
	exit -1;
}

if ( 'ttyS0' ne $tty && 'tty1' ne $tty && 'tty2' ne $tty && 'tty3' ne $tty && 'tty4' ne $tty ){
	print STDOUT "Permission denied.\n";
	sleep 5;
	exit -1;
}

$SIG{ALRM} = sub { print "\tTime out, Bye Bye.\n"; exit 0; };
while ( 1 ){
	alarm 300;
	system ( 'clear' );
	print STDOUT <<_MENU_;

	Menu:

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
		system ( '/home/NoSPAM/bin/wi reboot' );
	}elsif ( 3==$cmd ){
		system ( '/home/NoSPAM/bin/wi shutdown' );
	}

	print STDOUT "\tOK, Press Enter to continue...";
	<STDIN>;
}
print STDOUT "\tOK, Bye Bye.\n";
sleep 5;
exit 0;

sub restore_default()
{
	system ( 'cat /home/NoSPAM/etc/NoSPAM.default.conf > /home/NoSPAM/etc/NoSPAM.conf; chown nospam /home/NoSPAM/etc/NoSPAM.conf' );
	system ( 'cat /home/NoSPAM/etc/ADMINFILE.default > /home/vpopmail/domains/localhost.localdomain/ADMINFILE; chown nospam /home/vpopmail/domains/localhost.localdomain/ADMINFILE' );
}
