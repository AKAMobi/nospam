#!/usr/bin/perl -w

use strict;
use POSIX qw(strftime);

use AKA::Mail;
use AKA::Mail::Conf;
use AKA::Mail::Log;
use AKA::IPUtil;

# We close stdout, for hide all warn.
# to disable any debug information to appear. 
# basicaly, for License reason. ;)
# 2004-03-12 Ed
open (NSOUT, ">&=2");
close (STDERR);

my $arp_binary = "/sbin/arp";
my $arping_binary = "/sbin/arping";
my $iptables = "/sbin/iptables";
my $ifconfig = "/sbin/ifconfig";
my $ip_binary = "/sbin/ip";
my $hostname_binary = "/bin/hostname";
my $reboot_binary = "/sbin/reboot";
my $shutdown_binary = "/sbin/shutdown";
my $date_binary = "/bin/date";
my $clock_binary = "/sbin/clock";

(my $prog=$0) =~ s/^.*\///g;
my $action = shift @ARGV;
my @param = @ARGV;


my $conf = new AKA::Mail::Conf;
my $intconf = &get_intconf;
my $licenseconf = &get_licenseconf;
my $zlog = new AKA::Mail::Log;
my $iputil = new AKA::IPUtil;

my $action_map = { 
			'start_System' => [\&start_System, "Init system on boot" ],
			'init_IPC' => [\&init_IPC, "Init Dynamic Engine memory" ],

			'reset_Network' => [\&reset_Network, ""],
			'reset_ConnPerIP' => [\&reset_ConnPerIP, ""],
			'reset_ConnRatePerIP' => [\&reset_ConnRatePerIP, ""],
			'get_GW_Mode' => [\&get_GW_Mode, ""], 
			'set_GW_Mode' => [\&set_GW_Mode, ""], 
			'get_Serial' => [\&get_Serial, ""],
			'get_LogHead' => [\&get_LogHead, "get NoSPAM.csv head"],
			'check_License' => [\&check_License, ""],
			'reset_DateTime' => [\&reset_DateTime, "param1: YYYY-mm-DD HH:MM:SS"],
			'clean_Log' => [\&clean_Log, "cat /dev/null > /var/log/NoSPAM.csv"],
			'reboot' => [\&reboot, ""],
			'shutdown' => [\&shutdown, ""]
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
	my $lock = &get_lock( "/home/NoSPAM/var/run/lock/$action" );
	my $ret = &{$action_map->{$action}[0]};
	&release_lock($lock);
	exit $ret;
}else{
	$zlog->fatal( "NoSPAM System Util unsuport action: $action( " . join(',',@param) . " )" );
	exit 0;
}


# if program run to here, must be some error!
exit -1;

#############################
sub start_System
{
	my $ret;

	# update hostname to provent dns query
	&reset_Network_update_hostname;

	$ret = &reset_Network;
	$ret ||= &reset_ConnPerIP;
	
	# Share Memory for Dynamic Engine.
	# now we use file system db
	# $ret ||= &init_IPC;

	$zlog->log("NoSPAM System Restarted, Util init ret $ret" );

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
	print NSOUT <<_USAGE_;

$prog <action> [action params ...]
  action could be:
_USAGE_
	foreach ( keys %{$action_map} ){
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

	$ret = system( "$iptables -A INPUT -p tcp --dport 25 -j ACCEPT" );
	return -30 if ( $ret );
	$ret = system( "$iptables -A INPUT -p tcp --dport 80 -j ACCEPT" );
	return -31 if ( $ret );
	#$ret = system( $iptables, '-A', 'INPUT', '-p tcp', '--dport 110', '-j ACCEPT' );
	#return -32 if ( $ret );
	$ret = system( "$iptables -A INPUT -p tcp --dport 443 -j ACCEPT" );
	return -33 if ( $ret );


	$ret = system( "$iptables -A INPUT -p tcp -m state --state ESTABLISHED,RELATED -j ACCEPT" );
	return -40 if ( $ret );
	$ret = system( "$iptables -A INPUT -p udp -m state --state ESTABLISHED,RELATED -j ACCEPT" );
	return -41 if ( $ret );

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

	$ret = system ( "ifdown lo && ifup lo" );
	return -40 if $ret;

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

	return 0;
}

sub reset_Network_update_rcpthosts
{
	my $mode = shift;

	my $Domain = $conf->{config}->{MailServerHostname} ;
	$Domain = $1 if ( $Domain=~/^[^\.]*mail[^\.]*\.(.+)/ );
	
	return 10 unless open FD, "</var/qmail/control/rcpthosts";

	my @domains = <FD>;
	close FD;

	push ( @domains, $Domain ) if ( ! grep ( /^$Domain$/, @domains ) );
	
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

sub reset_Network_update_smtproutes_gateway
{
	my $Domain = $conf->{config}->{MailServerHostname} ;
	my $IP = $conf->{config}->{MailServerIP} ;

	my $ret=0;

	# get real email domain 
	$Domain = $1 if ( $Domain=~/^[^\.]*mail[^\.]*\.(.+)/ );

	return 10 unless ( $Domain && $IP );

	return 20 unless open ( FD, "</var/qmail/control/smtproutes" ) ;	

	my @smtproutes = <FD>;
	close ( FD );

	my $content = '';
	my $exist = 0;
	foreach ( @smtproutes ){
		if (/"^$Domain:$IP"/ ){
			$exist = 1;
		}
		$content .= "$_" 
	}

	$content .= "$Domain:$IP\n" unless ( $exist );

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
	my $MailServerGroup = 'N';

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
	
	if ( system("$iptables -I ConnPerIP -p tcp --syn --dport 25 -m iplimit --iplimit-above $ParalConn -j REJECT") ){
		return 21;
	}

	return 0;
}

sub reset_ConnRatePerIP
{
	my $ConnRate = $conf->{config}->{ConnRatePerIP} || 0;

	$zlog->debug("NoSPAM Util::reset_ConnRatePerIP to $ConnRate");

=pod
	now to do it in perl module.

	# delete link to input
	if ( system("$iptables -D INPUT -j ConnRatePerIP") ) {
		# It's ok.
	}

	# 0 means no limit
	return if ( 0==$ConnRate );

	# flush, create it if not exist
	if ( system("$iptables -F ConnRatePerIP") ) {
		if ( system("$iptables -N ConnRatePerIP") ) {
			return -10;
		}
	}

	if ( system("$iptables -I INPUT -j ConnRatePerIP") ) {
		return -20;
	}
	
	if ( system("$iptables -I ConnRatePerIP -p tcp --syn --dport 25 -m iplimit --iplimit-above $ParaConn -j REJECT >/dev/null 2>&1") ){
		return -21;
	}
=cut

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
		. ",垃圾度,垃圾原因,是否拒绝垃圾"
		. ",动作描述,动作类型,动作参数"
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

	if ( $AM->check_license_file ){
		# VALID license!
		print "<h1>通过检查！</h1>";
		return 0;
	}
	# INVALID license!
	print "<h1>未通过检查！</h1>";
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
	return system ( "$reboot_binary" );
}

sub shutdown
{
	$zlog->debug("NoSPAM Util::shutdown");
	return system ( "$shutdown_binary now" );
}

sub clean_Log
{
	return `cat /dev/null > /var/log/NoSPAM.csv`;
}


