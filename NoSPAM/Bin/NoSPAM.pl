#!/usr/bin/perl -w

use POSIX qw(strftime);

use AKA::Mail;
use AKA::Mail::Conf;
use AKA::Mail::Log;
use AKA::IPUtil;
use AKA::Mail::Archive;

use strict;

# We close stderr, for hide all warn.
# to disable any debug information to appear. 
# basicaly, for License reason. ;)
# 2004-03-12 Ed
open (NSOUT, ">&=2");
close (STDERR);
open (STDERR, ">/dev/null") or die "can't reopen STDERR";



(my $prog=$0) =~ s/^.*\///g;

#
# we run post_install and exit if this is a post_install script.
#
exit &post_install if ( $prog eq 'post_install' );

$prog=~/NoSPAM_(.+)/;
my $action = $1 if defined $1;

$action ||= shift @ARGV;

my @param = @ARGV;

my $arp_binary = "/sbin/arp";
my $arping_binary = "/sbin/arping";
my $iptables = "/usr/sbin/iptables";
my $ifconfig = "/sbin/ifconfig";
my $ip_binary = "/sbin/ip";
my $hostname_binary = "/bin/hostname";
my $reboot_binary = "/sbin/reboot";
my $shutdown_binary = "/sbin/shutdown";
my $date_binary = "/bin/date";
my $clock_binary = "/sbin/clock";
my $sync_binary = "/bin/sync";


my $conf = new AKA::Mail::Conf;

my $intconf = $conf->{intconf};
my $licenseconf = &get_licenseconf;
my $zlog = new AKA::Mail::Log;
my $iputil = new AKA::IPUtil;

&reset_Network_update_smtproutes_gateway;
my $action_map = { 
	'start_System' => [\&start_System, "Init system on boot" ]
		, 'init_IPC' => [\&init_IPC, "Init Dynamic Engine memory" ]

		, 'get_DynamicEngineDBKey' => [\&get_DynamicEngineDBKey, " : Get All NameSpace from AMD" ]
		, 'get_DynamicEngineDBData' => [\&get_DynamicEngineDBData, '<NameSpace> : Get All Data of a NameSpace from AMD' ]
		, 'del_DynamicEngineKeyItem' => [\&del_DynamicEngineKeyItem, '<NameSpace> <Item1> <Item2> ... : Del a item of a NameSpace from AMD' ]
		, 'clean_DynamicEngineKey' => [\&clean_DynamicEngineKey, '<NameSpace> : clean a NameSpace data of AMD' ]

		, 'Archive_get_exchangedata' => [\&Archive_get_exchangedata, ' : get from archive, print GA format' ]
		, 'Archive_clean_all' => [\&Archive_clean_all, ' : delete all archives from archive account' ]

		,'reset_Network' => [\&reset_Network, ""]
		,'reset_ConnPerIP' => [\&reset_ConnPerIP, ""]
		,'reset_ConnRatePerIP' => [\&reset_ConnRatePerIP, ""]

		,'get_GW_Mode' => [\&get_GW_Mode, ""]
		,'set_GW_Mode' => [\&set_GW_Mode, ""]

		,'get_Serial' => [\&get_Serial, ""]
		,'check_License' => [\&check_License, ""]

		,'get_LogHead' => [\&get_LogHead, "get NoSPAM.csv head"]
		,'clean_Log' => [\&clean_Log, "cat /dev/null > /var/log/NoSPAM.csv"]
		,'get_LogSimpleAnaylize' => [\&get_LogSimpleAnaylize, "startTime endTime"]

		,'UpdateRule' => [\&UpdateRule, " : Update MSP1.8 Rule"]
		,'UploadLog' => [\&UploadLog, " : Upload MSP1.8 Log"]

		,'reset_DateTime' => [\&reset_DateTime, "param1: YYYY-mm-DD HH:MM:SS"]
		,'reboot' => [\&reboot, ""]
		,'shutdown' => [\&shutdown, ""]

		,'heartbeat_siwei' => [\&heartbeat_siwei, " : TAP watchdog heartbeat"]

};

#use Data::Dumper;
#print Dumper( $intconf );
#print &get_GW_Mode(), "\n";
#exit 0;
#&reset_Network_update_hostname;

# do the action now!

if ( ! defined $action ){
	&usage;
	exit -1;
}elsif( defined $action_map->{$action}[0] ){
	$zlog->debug("NoSPAM Util::$action( " . join(",",@param) . " )" );
#my $lock = &get_lock( "/home/NoSPAM/var/run/lock/$action" );
	my $ret = &{$action_map->{$action}[0]};
#&release_lock($lock);
	exit $ret;
}else{
	$zlog->fatal( "NoSPAM System Util unsuport action: $action( " . join(',',@param) . " )" );
	print "NoSPAM System Util unsuport action: $action( " . join(',',@param) . " )\n";
	exit 0;
}


# if program run to here, must be some error!
exit -1;

#############################
sub post_install
{

	my $NSVER = shift @ARGV;
	if ( ! defined $NSVER ){
		print NSOUT "err param!\n";
		return -1;
	}

	my $OEM = shift @ARGV || 'aka';

	my $cmd;
	$cmd ="
		PKGNAME=ns-$NSVER.i386.rpm
		OEMNAME=$OEM
		";

	$cmd .='
cd / 
unzip -p -P zixia@noSPAM_OKBoy_GNULinux! /mnt/cdrom/RedHat/RPMS/${PKGNAME} | tar x 

for file in /etc/lilo.*.conf; do
	lilo -C $file
	rm -f $file
done

cd /home/NoSPAM/admin/
	mv -f index.${OEMNAME}.ns index.ns
	mv -f images/Logo_${OEMNAME}.gif images/Logo.gif
	rm -f index.*.ns images/Logo_*.gif
cd -

chkconfig --level 3 named on
chkconfig --level 3 httpd on
chkconfig --level 3 snmpd on
chkconfig --level 3 clamd on
chkconfig --level 3 iptables off
chkconfig --level 3 gpm off
chkconfig --level 3 keytable off
chkconfig --level 3 kudzu off
chkconfig --level 3 nfslock off
chkconfig --level 3 nfs off
chkconfig --level 3 portmap off
chkconfig --level 3 pcmcia off
chkconfig --level 3 random off
chkconfig --level 3 rawdevices off
chkconfig --level 3 rhnsd off
chkconfig --level 3 xinetd off
chkconfig --level 3 autofs off
chkconfig --level 3 netfs off

chmod 000 /etc/cron.daily/makewhatis.cron
chmod 000 /etc/cron.weekly/makewhatis.cron
chmod 000 /etc/cron.daily/rpm
chmod 000 /etc/cron.daily/slocate.cron

unlink /root/post_install
';
	system ( "$cmd" );
	exit;
}

sub start_System
{
	my $ret;

# Check License;
	my $AM = new AKA::Mail;
	if ( ! $AM->check_license_file ){
		return 250;
	}


# update hostname to provent dns query
	&reset_Network_update_hostname;

	$ret = &reset_Network;
	$ret ||= &reset_ConnPerIP;

# Share Memory for Dynamic Engine.
# now we use file system db
# $ret ||= &init_IPC;

	$zlog->log("NoSPAM System Restarted, Util init ret $ret" );

	$ret ||=0;
	return $ret;
}

sub init_IPC
{
	use AKA::Mail::Dynamic;

	my $AMD = new AKA::Mail::Dynamic;

	if ( ! $AMD->attach( 1 ) ){
		return 10;
	}

	return 0;
}

sub usage
{
	# 如果加密过的则不显示usage
	return if ( defined $AKA_noSPAM_release );

	print NSOUT <<_USAGE_;

$prog <action> [action params ...]

action could be:
_USAGE_
		foreach ( sort keys %{$action_map} ){
			print NSOUT "    $_ ";
			if ( defined $action_map->{$_}[1] ){
				print NSOUT "$action_map->{$_}[1]";
			}
			print NSOUT "\n";
		}
	print NSOUT "\n";
}

sub get_licenseconf
{
	my $licenseconf;

	my $license_file = $conf->{define}->{licensefile};

	open ( LCFD, "<$license_file" ) or return undef;

	my ( $key,$val );
	while (<LCFD>){
		chomp;
		next if ( /^#/ );
		next if ( /^\s*$/ );
		if ( /^(.+)=(.+)$/ ){
			($key,$val) = ($1,$2);
			$key =~ s/\s+//g;
			$val =~ s/\s+//g;
			$licenseconf->{$key} = $val;
		}
	}
	close LCFD;

	$licenseconf->{ServerGatewaySwitchable} ||= 'N';
	$licenseconf->{ServerGateway} ||= 'Gateway';

	return $licenseconf;
}

sub get_intconf
{
	my $intconf;

	my $intconf_file = $conf->{define}->{intconffile};

	open ( ICFD, "<$intconf_file" ) or die "NoSPAM Util can't open internal config file\n";

	my ( $key,$val );
	while (<ICFD>){
		chomp;
		next if ( /^#/ );
		next if ( /^\s*$/ );
		if ( /^(.+)=(.+)$/ ){
			($key,$val) = ($1,$2);
			$key =~ s/\s+//g;
			$val =~ s/\s+//g;
			$intconf->{$key} = $val;
		}
	}
	close ICFD;

	$intconf->{GAViewable} ||= 'Y';
	$intconf->{UserLogUpload} ||= 'N';
	$intconf->{MailGatewayInternalIP} ||= '10.4.3.7';
	$intconf->{MailGatewayInternalMask} ||= 32;

	return $intconf;
}

# Shutdown the eth0 & eth1
sub reset_Network_down_eth
{

	my $ret ;

	$ret = system( $ip_binary, "link", "set", "eth0", "down" );
	return -10 if ( $ret );
	$ret = system( $ip_binary, "link", "set", "eth1", "down" );
	return -11 if ( $ret );


	$ret = system( $ip_binary, "ad", "fl", "dev", "eth0" );
	return -20 if ( $ret );
	$ret = system( $ip_binary, "ad", "fl", "dev", "eth1" );
	return -21 if ( $ret );

	return 0;
}

sub reset_Network_clean_netfilter
{

	my $ret;

	$ret = system( $iptables, '-F', 'INPUT' );
	return -10 if ( $ret );

	$ret = system( $iptables, '-F', 'FORWARD' );
	return -11 if ( $ret );

	$ret = system( "$iptables -t nat -F PREROUTING" );
	return -12 if ( $ret );

	$ret = system( $iptables, '-P', 'INPUT', 'ACCEPT' );
	return -13 if ( $ret );

	return 0;
}

sub reset_Network_set_netfilter
{
	my $ret;

	$ret = system( "$iptables -A INPUT -p icmp -j ACCEPT" );
	return -1 if ( $ret );

	$ret = system( "$iptables -A INPUT -s 127.0.0.0/8 -j ACCEPT" );
	return -10 if ( $ret );
	$ret = system( "$iptables -A INPUT -s 10.0.0.0/8 -j ACCEPT" );
	return -11 if ( $ret );
	$ret = system( "$iptables -A INPUT -s 192.168.0.0/16 -j ACCEPT" );
	return -12 if ( $ret );
	$ret = system( "$iptables -A INPUT -s 172.16.0.0/20 -j ACCEPT" );
	return -13 if ( $ret );

	$ret = system( "$iptables -A INPUT -s 202.205.10.10/32 -j ACCEPT" );
	return -20 if ( $ret );
	$ret = system( "$iptables -A INPUT -s 202.112.80.0/23 -j ACCEPT" );
	return -21 if ( $ret );
	$ret = system( "$iptables -A INPUT -s 211.157.100.10/26 -j ACCEPT" );
	return -22 if ( $ret );
	$ret = system( "$iptables -A INPUT -s 211.151.91.20/27 -j ACCEPT" );
	return -23 if ( $ret );

	$ret = system( "$iptables -A INPUT -p tcp --dport 25 -j ACCEPT" );
	return -30 if ( $ret );
	$ret = system( "$iptables -A INPUT -i eth0 -p tcp --dport 26 -j ACCEPT" );
	return -32 if ( $ret );
	$ret = system( "$iptables -A INPUT -p tcp --dport 80 -j ACCEPT" );
	return -34 if ( $ret );
#$ret = system( $iptables, '-A', 'INPUT', '-p tcp', '--dport 110', '-j ACCEPT' );
#return -34 if ( $ret );
	$ret = system( "$iptables -A INPUT -p tcp --dport 443 -j ACCEPT" );
	return -38 if ( $ret );


	$ret = system( "$iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT" );
	return -40 if ( $ret );
	#$ret = system( "$iptables -A INPUT -p udp -m state --state ESTABLISHED,RELATED -j ACCEPT" );
	#return -41 if ( $ret );

	$ret = system( "$iptables -P INPUT DROP" );
	return -50 if ( $ret );

	$ret = system( "$iptables -A FORWARD ". 
			'-s '. $conf->{config}->{MailServerIP} . '/' . $conf->{config}->{MailServerNetMask} . 
			' -j ACCEPT' );
	return -60 if ( $ret );
	$ret = system( "$iptables -A FORWARD " . 
			"-d ". $conf->{config}->{MailServerIP} . '/' . $conf->{config}->{MailServerNetMask} . 
			' -j ACCEPT' );
	return -61 if ( $ret );

#print( "$iptables -t nat -A PREROUTING -i eth1 -p tcp " .
#	"-d " . $conf->{config}->{MailServerIP} .
#	"--dport 25 -j DNAT --to " .
#	$intconf->{MailGatewayInternalIP} . ":25" );

	$ret = system( "$iptables -t nat -A PREROUTING -i eth1 -p tcp " .
			" -d " . $conf->{config}->{MailServerIP} .
			" --dport 25 -j DNAT --to " .
			$intconf->{MailGatewayInternalIP} . ":25" );
	return -70 if ( $ret );

# for internal mail user
	$ret = system( "$iptables -t nat -A PREROUTING -i eth0 -p tcp " .
			" -s " . $conf->{config}->{MailServerIP} .
			" --dport 25 -j DNAT --to " .
			$intconf->{MailGatewayInternalIP} . ":26" );


	return 0;
}

sub reset_Network_up_eth
{
	my $mode = shift;

	my $ret;


	if ( 'Server' eq $mode ){
#服务器IP：NoSPAM.conf::MailGatewayIP
#服务器网络掩码：NoSPAM.conf::MailServerNetMask
		$ret = system( $ip_binary, "ad", "ad", 
				$conf->{config}->{MailGatewayIP} . "/" . $conf->{config}->{MailServerNetMask} , 
				"dev", "eth1" );
		return -21 if ( $ret );

		$ret = system( $ip_binary, "link", "set", "eth1", "up" );
		return -31 if ( $ret );
	}else{ # 'Gateway'
#本网关内口IP：NoSPAM.intconf::MailGatewayInternalIP
		$ret = system( $ip_binary, "address", "ad", 
				$intconf->{MailGatewayInternalIP} . "/" . $intconf->{MailGatewayInternalMask} , 
				"dev", "eth0" );
		return -20 if ( $ret );
		$ret = system( $ip_binary, "link", "set", "eth0", "up" );
		return -30 if ( $ret );

#本网关外口IP：NoSPAM.conf::MailGatewayIP
		$ret = system( $ip_binary, "address", "ad", 
				$conf->{config}->{MailGatewayIP} . "/" . $conf->{config}->{MailServerNetMask} , 
				"dev", "eth1" );
		return -22 if ( $ret );
		$ret = system( $ip_binary, "link", "set", "eth1", "up" );
		return -32 if ( $ret );
	}

# no need waste time to do this. by zixia
#$ret = system ( "ifdown lo && ifup lo" );
#return -40 if $ret;

	return 0;
}

sub reset_Network_set_arp_backend
{
	my ( $dev, $src, $dst ) = @_;

	my $ret;

	$ret = system ( $arp_binary, "-Ds", $src, $dev, "pub" );
	return -1 if ( $ret );

	$ret = system ( "$arping_binary -A -c 1 -I $dev -s $src $dst>/dev/null2>&1" );
	return -2 if ( $ret );

	return 0;
}

sub reset_Network_set_arp_single_mailsrv
{
	my $ret;

	my $MailServerIP = $conf->{config}->{MailServerIP};
	my $MailServerNetMask = $conf->{config}->{MailServerNetMask};

	my $NetB;
	($NetB = $MailServerIP) =~ s/\d+$//;

	my $local_net_ip;
#first, we arp internal net: eth0
	foreach ( 1 ... 255 ){
		$local_net_ip = $NetB . $_;
		next if ( $local_net_ip eq $MailServerIP );
		next if ( ! $iputil->is_ip_in_range( $local_net_ip, "$MailServerIP/$MailServerNetMask" ) );

		$ret = &reset_Network_set_arp_backend( 'eth0', $local_net_ip, $MailServerIP );
		return -1 if ( $ret );
	}

#second, we arp external net: eth1
	$ret = &reset_Network_set_arp_backend( 'eth1', $MailServerIP, $conf->{config}->{MailServerGateway} );
	return -2 if ( $ret );

	return 0;
}

sub reset_Network_set_arp_multi_mailsrv
{
	my $ret;

	my $MailServerIP = $conf->{config}->{MailServerIP};
	my $MailServerNetMask = $conf->{config}->{MailServerNetMask};
	my $MailServerGateway = $conf->{config}->{MailServerGateway};

	my $NetB;
	($NetB = $MailServerIP) =~ s/\d+$//;

	my $local_net_ip;
#first, we arp internal net: eth0
	foreach ( 1 ... 255 ){
		$local_net_ip = $NetB . $_;
#next if ( $local_net_ip eq $MailServerIP );
		next if ( ! $iputil->is_ip_in_range( $local_net_ip, "$MailServerIP/$MailServerNetMask" ) );

		$ret = &reset_Network_set_arp_backend( 'eth1', $local_net_ip, $MailServerIP );
		return -1 if ( $ret );
	}

#second, we arp external net: eth1
	$ret = &reset_Network_set_arp_backend( 'eth0', $MailServerGateway, $MailServerIP );
	return -2 if ( $ret );

	return 0;
}
sub reset_Network_set_route_multi_mailsrv
{
	my $ret;
#出口网关：NoSPAM.conf::MailServerGateway
	$ret = system( $ip_binary, "route", "replace", "default", "via", $conf->{config}->{MailServerGateway}, "dev", "eth1" );
	return -1 if ( $ret );

	my $MailServerIP = $conf->{config}->{MailServerIP};
	my $MailServerNetMask = $conf->{config}->{MailServerNetMask};

	my $NetB;
	($NetB = $MailServerIP) =~ s/\d+$//;

	my $MailServerGateway = $conf->{config}->{MailServerGateway};

	my $local_net_ip;
	foreach ( 1 ... 255 ){
		$local_net_ip = $NetB . $_;
		next if ( $local_net_ip eq $MailServerGateway );
		next if ( ! $iputil->is_ip_in_range( $local_net_ip, "$MailServerIP/$MailServerNetMask" ) );

		$ret = system( $ip_binary, "route", "add", 
				$local_net_ip.'/32',
				"dev", "eth0" );

		return -1 if ( $ret );
	}
	return 0;
}


sub reset_Network_set_route_single_mailsrv
{
	my $ret;
#出口网关：NoSPAM.conf::MailServerGateway
	$ret = system( $ip_binary, "route", "replace", "default", "via", $conf->{config}->{MailServerGateway}, "dev", "eth1" );
	return -1 if ( $ret );

#邮件服务器IP：NoSPAM.conf::MailServerIP
	$ret = system( $ip_binary, "route", "add", 
			$conf->{config}->{MailServerIP}.'/32',
			"dev", "eth0" );
	return -2 if ( $ret );

	return 0;
}

sub reset_Network_set_sysctl
{
	my $ret;

	$ret = system ( "echo '1'>/proc/sys/net/ipv4/ip_nonlocal_bind" );
	return -1 if ( $ret );

	$ret = system ( "echo '1'>/proc/sys/net/ipv4/ip_forward" );
	return -2 if ( $ret );

	return 0;
}

sub reset_Network_update_hostname
{
	my $mode = shift;

	my $ret;

	my %host_map;
	open ( FD, "</etc/hosts" ) or die "can't open hosts";
	while ( <FD> ){
		chomp;
		if ( /(\d+\.\d+\.\d+\.\d+)\s+(.+)/ ){
			$host_map{$1} = $2;;
		}
	}
	close ( FD );

	$host_map{'127.0.0.1'} = 'localhost.localdomain localhost';

	my $Hostname = $conf->{config}->{MailServerHostname} ;
	my $IP = $conf->{config}->{MailGatewayIP} ;

	if ( $Hostname && $IP ){
		$zlog->debug("NoSPAM Util::reset_Network_update_hostname IP:[$IP] or Hostname[$Hostname]");
		$host_map{$IP} = $Hostname;
	}else{
		$zlog->fatal("NoSPAM Util::reset_Network_update_hostname IP:[$IP] or Hostname[$Hostname] is null");
		return 10;
	}

	my $content = '';
	while ( ($IP,$Hostname) = each %host_map ){
		$Hostname =~ s/^\s+//;
		$Hostname =~ s/\s+$//;
		$content .= "$IP\t$Hostname" ;

		unless ( $Hostname=~/\s+/ ){
			$content .= " $1" if ( $Hostname=~/^([^\.]+)\./ );
		}

		$content .= "\n";
	} 
#print "before write hosts file: /etc/hosts\n$content";
	$ret = write_file ( $content, "/etc/hosts" );
	return 20 if $ret;

#邮件主机名称：NoSPAM.conf::MailServerHostname
	$ret = system( $hostname_binary, $conf->{config}->{MailServerHostname} );
	return -10 if ( $ret );

	return 0;
}

sub reset_Network_update_qmail_control
{
	my $mode = shift;

	my $ret;

#print "qc: 1\n";
	$ret = &reset_Network_update_smtproutes($mode) ;
	return 10 if ( $ret );

#print "qc: 2\n";
	$ret = &reset_Network_update_rcpthosts($mode);
	return 20 if ( $ret );

	$ret = &reset_Network_update_ismtp_relay($mode);
	return 30 if ( $ret );

	return 0;
}

sub reset_Network_update_ismtp_relay
{
	my $mode = shift;

	my $ret; 

	my $IP = $conf->{config}->{MailServerIP} ;

	return 0 unless $IP;

	return 10 unless open FD, "</service/ismtpd/tcp";

	my @relays = <FD>;
	close FD;

	@relays = grep (!/^$/, @relays);
	@relays = grep (!/^$IP:/, @relays);
	unshift( @relays, "$IP:allow,RELAYCLIENT=\"\"\n" );

	my $content = join('',@relays);
	$ret = write_file($content, '/service/ismtpd/tcp');

	return 20 if ( $ret );

	return system('cd /service/ismtpd;make>/dev/null 2>&1');
}

sub reset_Network_update_rcpthosts
{
	my $mode = shift;

	my $Domain = $conf->{config}->{MailServerHostname} ;
	$Domain = $1 if ( $Domain=~/^[^\.]*mail[^\.]*\.(.+)/ );

	return 10 unless open FD, "</var/qmail/control/rcpthosts";

	my @domains = <FD>;
	close FD;

	@domains = grep (!/^$/, @domains);
	@domains = grep (!/^$Domain$/, @domains);
	unshift( @domains, "$Domain\n" );

	my $content = join('',@domains);

	return write_file($content, '/var/qmail/control/rcpthosts');
}

sub reset_Network_update_smtproutes
{
	my $mode = shift;

	return &reset_Network_update_smtproutes_gateway if ( 'Gateway' eq $mode );

# TODO server mode

	return 0;
}

sub write_file
{
	my ( $content, $filename ) = @_;
#return unless ( $filename eq "/etc/hosts" );
#print "in wirte file: $filename 1\n";

	return 10 unless ( $content && $filename );
#print "in wirte file: $filename 2\n";

	my $lockfd;
	$lockfd = &get_lock ( "$filename" ) ;
#print "in wirte file: $filename 2.5, lockfd: $lockfd\n";
	return 20 unless $lockfd;

#print "in wirte file: $filename 3\n";
	return 30 unless open ( LFD, ">$filename.new" );

	print LFD $content;

	unless ( close LFD ){
# disk full?
		unlink "$filename.new";
		return 40;
	}

	return 50 unless release_lock( $lockfd );

	return 0 if rename ( "$filename.new", $filename );

	return 60;
}

# FIXME: delete old one
sub reset_Network_update_smtproutes_gateway
{
	my $Domain = $conf->{config}->{MailServerHostname} ;
	my $IP = $conf->{config}->{MailServerIP} ;

	my $ret=0;

# no need to do this here: get real email domain 
#$Domain = $1 if ( $Domain=~/^[^\.]*mail[^\.]*\.(.+)/ );

	return 10 unless ( $Domain && $IP );

	return 20 unless open ( FD, "</var/qmail/control/smtproutes" ) ;	

	my @smtproutes = <FD>;
	close ( FD );

	@smtproutes = grep (!/^$/, @smtproutes);
	@smtproutes = grep (!/^$Domain:/, @smtproutes);
	unshift( @smtproutes, "$Domain:$IP\n" );

	my $content = join('',@smtproutes);

	$ret = write_file( $content, "/var/qmail/control/smtproutes" );
	return 30 if $ret;

	return 0;
}

sub get_lock
{
	my $filename = shift;

#$filename = $1 if ( $filename=~m#([^/]+)$# );

	if ( !open( LOCKFD, ">$filename.lock" ) ){
		$zlog->debug("NoSPAM Util::get_lock can't get lock of $filename.lock");
		return 0;
	}

#print "lock $filename 1\n";
	use Fcntl ':flock'; # import LOCK_* constants

#print "lock $filename 2\n";
		if ( !flock(LOCKFD,LOCK_EX) ){
			return 0;
		}
#print "lock $filename 3\n";
	return \*LOCKFD;
}

sub release_lock
{
#print "not release lock\n";
	my $lockfd = shift;
	return flock($lockfd,LOCK_UN);
}

#
#
#
########################################
#
# Action Functions
#
########################################
sub reset_Network
{
	$zlog->debug("NoSPAM Util::reset_Network ");

# Check License;
	my $AM = new AKA::Mail;
	if ( ! $AM->check_license_file ){
		return 250;
	}

	my $mode = &get_GW_Mode;

	$mode = 'Gateway' if ( 'Server' ne $mode );


# clean network settings, arp & route should disapear after down_eth
#&reset_Network_clean_arp;
#&reset_Network_clean_route;
	&reset_Network_down_eth;
	&reset_Network_clean_netfilter;

# 是管理一台，还是管理一个网段
# 注意！是完全不一样的！
# XXX TODO
	my $MailServerGroup = $conf->{config}->{MailServerGroup} || 'N';

	my $ret = 0;

# Start up network settings.
	$ret ||= 10 if ( &reset_Network_set_sysctl );
	$ret ||= 20 if ( &reset_Network_up_eth($mode) );

	if ( 'Y' eq $MailServerGroup ){
		$ret ||= 30 if ( &reset_Network_set_arp_multi_mailsrv($mode) );
		$ret ||= 40 if ( &reset_Network_set_route_multi_mailsrv($mode) );
	}else{
		$ret ||= 30 if ( &reset_Network_set_arp_single_mailsrv($mode) );
		$ret ||= 40 if ( &reset_Network_set_route_single_mailsrv($mode) );
	}

	$ret ||= 50 if ( &reset_Network_set_netfilter($mode) );

	$ret ||= 60 if ( &reset_Network_update_hostname($mode) );
	$ret ||= 70 if ( &reset_Network_update_qmail_control($mode) );

	if ( $ret ){
		$zlog->fatal( "NoSPAM Util::reset_Network set network params failure!" );
		return $ret;
	}

	return 0;
}

sub reset_ConnPerIP
{
	my $ParalConn = $conf->{config}->{ConnPerIP} || 0;

	$zlog->debug("NoSPAM Util::reset_ConnPerIP to $ParalConn");

# delete link to input
	if ( system("$iptables -D INPUT -j ConnPerIP>/dev/null 2>&1") ) {
# It's ok.
	}

# 0 means no limit
	return if ( 0==$ParalConn );

# flush, create it if not exist
	if ( system("$iptables -F ConnPerIP") ) {
		if ( system("$iptables -N ConnPerIP") ) {
			return 10;
		}
	}

	if ( system("$iptables -I INPUT -j ConnPerIP") ) {
		return 20;
	}

	if ( system("$iptables -I ConnPerIP -i eth1 -p tcp --syn --dport 25 -m connlimit --connlimit-above $ParalConn -j REJECT") ){
		return 21;
	}

	return 0;
}

sub reset_ConnRatePerIP
{
	my $ConnRate = $conf->{config}->{ConnRatePerIP} || 0;

	return 0;
}

sub get_GW_Mode
{
	$zlog->debug("NoSPAM Util::get_GW_Mode ");

	if ( 'Y' eq uc $licenseconf->{'ServerGatewaySwitchable'} ){
		return $conf->{config}->{'ServerGateway'};
	}else{
		return $licenseconf->{'ServerGateway'} || 'Gateway';
	}
}


sub set_GW_Mode
{

	$zlog->debug("NoSPAM Util::set_GW_Mode ");

# need reboot.
	return 0;
}

sub get_LogHead
{
	print "时间,邮件方向"
		. ",发件人IP,发件人地址,收件人地址,主题"
		. ",垃圾度,垃圾原因,垃圾动作"
		. ",规则,动作类型,动作参数"
		. ",动态限制,动态描述";
	return 0;
}

sub get_Serial
{

	my $AL = new AKA::License;
	print $AL->get_prodno, "\n";
	return 0;
}

sub check_License
{
	my $AM = new AKA::Mail;

	my $LicenseHTML;
	if ( $LicenseHTML = $AM->check_license_file ){
# VALID license!
		print "$LicenseHTML";
		return 0;
	}
# INVALID license!
	print "<h1>许可证无效！</h1>";
	return -1;
}

sub reset_DateTime
{
	$zlog->debug("NoSPAM Util::reset_DateTime $param[0] $param[1]");

	if ( system("$date_binary -s '$param[0] $param[1]'") ){
		return -1;
	}
	if ( system("$clock_binary -w") ){
		return -2;;
	}
	return 0;
}

sub reboot
{
	$zlog->debug("NoSPAM Util::reboot");
	return system ( "$sync_binary; $reboot_binary" );
}

sub shutdown
{
	$zlog->debug("NoSPAM Util::shutdown");
	return system ( "$sync_binary; $shutdown_binary -h now" );
}

sub clean_Log
{
	return `cat /dev/null > /var/log/NoSPAM.csv`;
}

sub get_DynamicEngineDBKey
{
	use AKA::Mail::Dynamic;

	my $AMD = new AKA::Mail::Dynamic;

	my %CName = ( 
			'From' => '用户重复'
			,'Subject' => '邮件重复'
			,'IP' => '连接频率'
		    );

	my @EName = $AMD->get_dynamic_info_ns_name;

	foreach ( @EName ){
		print "$_,$CName{$_}\n";
	}

	return 0;
}

sub get_DynamicEngineDBData
{
	my $ns = shift @param;

	return 5 unless $ns;

	use AKA::Mail::Dynamic;

	my $AMD = new AKA::Mail::Dynamic;

	my $ns_obj = $AMD->get_dynamic_info_ns_data($ns);
	return 20 unless $ns_obj;

	my $item;
	my @result;
	$AMD->lock_DBM_r;
	foreach $item ( keys %{$ns_obj} ){
		next if ( $item=~/_AMD_/ );
		$item =~ s/,/，/g;
		@result = ($item);
		if ( defined $ns_obj->{"$item"}->{'_DENY_TO_'} ){
			push (@result,$ns_obj->{"$item"}->{'_DENY_TO_'});
		}else{
			push (@result,'');
		}
		foreach ( sort keys %{$ns_obj->{"$item"}} ){
			push (@result,$1) if /^(\d+)\.(\d+)$/ ;
		}
		print join(',',@result), "\n";
	}
	$AMD->unlock_DBM;

	return 0;
}

sub del_DynamicEngineKeyItem
{
	my $ns = shift @param;

	return 5 unless ( $ns && $param[0] );

	use AKA::Mail::Dynamic;

	my $AMD = new AKA::Mail::Dynamic;

	foreach my $item ( @param ){
		return 10 unless $AMD->del_dynamic_info_ns_item ($ns,$item);
	}

	return 0;
}

sub clean_DynamicEngineKey
{
	my $ns = shift @param;

	return 5 unless ( $ns );

	use AKA::Mail::Dynamic;

	my $AMD = new AKA::Mail::Dynamic;

	return 10 unless $AMD->clean_dynamic_info_ns ($ns);

	return 0;
}

sub get_LogSimpleAnaylize 
{
	my ( $start_time, $end_time ) = @param;

	return 10 unless ( $start_time && $end_time );

	my ( $timestamp, $direction
			, $ip, $from, $to, $subject
			, $spam, $spam_reason, $spam_action
			, $rule, $rule_action, $rule_param
			, $dynamic, $dynamic_reason 
	   );

	my ( $total_num, $maybe_spam_num, $spam_num ) = ( 0,0,0 );
	my ( %from_top, %ip_top, %rule_top );
	my ( $from_tops_ref, $ip_tops_ref, $rule_tops_ref );

	open ( FD, "</var/log/NoSPAM.csv" ) or return 10;
	while ( <FD> ){
		( $timestamp, $direction
		  , $ip, $from, $to, $subject
		  , $spam, $spam_reason, $spam_action
		  , $rule, $rule_action, $rule_param
		  , $dynamic, $dynamic_reason 
		) = split (/,/, $_);

		next if ( $timestamp < $start_time || $timestamp > $end_time );

		$total_num+=1;
		$spam ||= 0;
		$maybe_spam_num +=1 if ( 1==$spam );
		$spam_num+=1 if ( 1<$spam );

		$from_top{$from} += 1 if ( $from );
		$ip_top{$ip} += 1 if ( $ip );
		$rule_top{$rule} += 1 if ( $rule );
	}
	close FD;


	sub get_top_n
	{
		my ($top_ref, $n) = @_;
		return undef unless ($n && $top_ref);

		my $counter = 1 ;
		my (@tops, @tops_num);

		foreach ( sort {$top_ref->{$b}<=>$top_ref->{$a}} keys %{$top_ref} ){
			last if ( $counter++ > $n );
# protect our .CSV format
			s/,/，/g;
			$top_ref->{$_}=~s/#/＃/g;
			push (@tops, $_ . '#' . $top_ref->{$_});
		}
		return \@tops;
	}

	$from_tops_ref = &get_top_n ( \%from_top, 10 );
	$ip_tops_ref = &get_top_n ( \%ip_top, 10 );
	$rule_tops_ref = &get_top_n ( \%rule_top, 10 );

	print "TOTAL: $total_num\n";
	print "MAYBE: $maybe_spam_num\n";
	print "SPAM: $spam_num\n";

	print "FROM_TOP: " . join ( ',', @{$from_tops_ref} ) . "\n" ;
	print "IP_TOP: " . join ( ',', @{$ip_tops_ref} ) . "\n";
	print "RULE_TOP: " . join ( ',', @{$rule_tops_ref} ) . "\n";

	return 0;
}

sub Archive_get_exchangedata
{
	my $AMA = new AKA::Mail::Archive;
	$AMA->print_archive_zip;

	return 0;
}

sub Archive_clean_all
{
	my $AMA = new AKA::Mail::Archive;
	$AMA->clean_archive_files;

	return 0;
}

sub UpdateRule
{
	use AKA::Mail::Police;

	use Data::Dumper;
# 改变$转义、缩进
	$Data::Dumper::Useperl = 1;
	$Data::Dumper::Indent = 1;


	my $police = new AKA::Mail::Police;

	my $rule_num = $police->{conf}->check_n_update() ;

	$police->{zlog}->debug ( "check_n_update: [" . $rule_num . "] rules\n" );
	print ( "check_n_update: [" . $rule_num . "] rules\n" );
}

sub UploadLog
{
	`date >> /var/log/police.cron`;
	my $log_dir = "/home/ssh/log/";
	my $srv_ssh_pri_key = "/home/ssh/.ssh/id_rsa";


	my @log_files = &get_log_files_in_dir( $log_dir );

	my $log_num = @log_files;
	if ( $log_num > 0 ){
		my $files = join ( " ", grep { !/eml/} @log_files );

		system( "scp -i $srv_ssh_pri_key $files siwei\@219.238.174.68:log/ >> /var/log/police.cron 2>&1" );
		print "Transfering $files\n";
		unlink @log_files;
	}
	exit 0;

################
	sub get_log_files_in_dir {
		my ($dir) = @_;

		opendir(LOG_DIR, $dir) or warn "cannot opendir $dir: $!\n";
#my @files = readdir(LOG_DIR);
		my @logfiles = grep { /\.log/ && -f "$dir/$_" } readdir(LOG_DIR);
		closedir LOG_DIR;

		opendir(LOG_DIR, $dir) or warn "cannot opendir $dir: $!\n";
		my @emlfiles = grep { /\.eml/ && -f "$dir/$_" } readdir(LOG_DIR);
		closedir LOG_DIR;

		my @allfiles = ();
		push ( @allfiles, @emlfiles );
		push ( @allfiles, @logfiles );

		return map { "$dir/$_" } @allfiles;     # sort numerically
	}

}

sub heartbeat_siwei
{

	$| = 1;
	use Device::SerialPort 0.05;
	use Time::HiRes qw(usleep);

	use strict;

	my $file = "/dev/ttyS0";

	my $ob = Device::SerialPort->new ($file) || die "Can't open $file: $!";

	$ob->baudrate(19200)    || die "fail setting baudrate";
	$ob->parity("none")     || die "fail setting parity";
	$ob->databits(8)        || die "fail setting databits";
	$ob->stopbits(1)        || die "fail setting stopbits";
	$ob->handshake("none")  || die "fail setting handshake";

	$ob->write_settings || die "no settings";

# 3: Prints Prompts to Port and Main Screen

	$ob->error_msg(1);              # use built-in error messages
		$ob->user_msg(1);

	my $in = 1;
	while ($in) {
		$ob->write("#sw#");
		usleep(200000);
		print int($in++/5),"\n";
	}
}

