#!/usr/bin/perl -w

#
# 邮件网关管理接口
# Company: AKA Information & Technology Co., Ltd.
# Author: Ed Lee
# Email: zixia@zixia.net
# Date: 2004-04-15
#
# Copyright 2004. All rights reserved.
#


use strict;

use POSIX qw(strftime);

use AKA::Mail;
use AKA::Mail::Conf;
use AKA::Mail::Log;
use AKA::IPUtil;
use AKA::Mail::Archive;


# We close stderr, for hide all warn.
# to disable any debug information to appear. 
# basicaly, for License reason. ;)
# 2004-03-12 Ed
# XXX
open (NSOUT, ">&=2");
#exit 0;
#close (STDERR);
#open (STDERR, ">/dev/null") or die "can't reopen STDERR";



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
my $ifconfig_binary = "/sbin/ifconfig";
my $ip_binary = "/sbin/ip";
my $hostname_binary = "/bin/hostname";
my $reboot_binary = "/sbin/reboot";
my $shutdown_binary = "/sbin/shutdown";
my $date_binary = "/bin/date";
my $clock_binary = "/sbin/clock";
my $sync_binary = "/bin/sync";
my $brctl_binary = "/usr/sbin/brctl";
my $vadddomain_binary = "/home/vpopmail/bin/vadddomain";
my $vdeldomain_binary = "/home/vpopmail/bin/vdeldomain";

use constant ERR_OPEN_FILE	=> 0x0008;
use constant ERR_WRITE_FILE	=> 0x0009;
use constant ERR_LOCK_FILE	=> 0x000A;
use constant ERR_SYSTEM_CALL	=> 0x000B;
use constant ERR_NETFILTER_CALL	=> 0x000C;
use constant ERR_PARAM_LACK	=> 0x000D;

my $conf = new AKA::Mail::Conf;

my $intconf = $conf->{intconf};
my $licenseconf = $conf->{licconf}; #&get_licenseconf;
my $zlog = new AKA::Mail::Log;
my $iputil = new AKA::IPUtil;

my $action_map = { 
	 	  'start_System' => [\&start_System, "Init system on boot" ]

		, 'get_DynamicEngineDBKey' => [\&get_DynamicEngineDBKey, " : Get All NameSpace from AMD" ]
		, 'get_DynamicEngineDBData' => [\&get_DynamicEngineDBData, '<NameSpace> : Get All Data of a NameSpace from AMD' ]
		, 'del_DynamicEngineKeyItem' => [\&del_DynamicEngineKeyItem, '<NameSpace> <Item1> <Item2> ... : Del a item of a NameSpace from AMD' ]
		, 'clean_DynamicEngineKey' => [\&clean_DynamicEngineKey, '<NameSpace> : clean a NameSpace data of AMD' ]

		, 'reset_DynamicEngine_IPConcur' => [\&reset_ConnPerIP, ' : reset IP Concur conn' ]
		
		, 'Archive_get_exchangedata' => [\&Archive_get_exchangedata, ' : get from archive, print GA format' ]
		, 'Archive_clean_all' => [\&Archive_clean_all, ' : delete all archives from archive account' ]

		, 'MailQueue_getList' => [\&MailQueue_getList, ' : list all mail from mail queue' ]
		, 'MailQueue_delID' => [\&MailQueue_delID, ' <SID1> ... : del from mail queue' ]
		, 'MailQueue_delAll' => [\&MailQueue_delAll, ' : del all mail from mail queue' ]
		, 'MailQueue_getMail' => [\&MailQueue_getMail, ' <SID> : get mail content from mail queue' ]

		, 'VirtualDomain_add' => [\&VirtualDomain_add, ' <MailDomain1> ... : add virtual mail domain' ]
		, 'VirtualDomain_del' => [\&VirtualDomain_del, ' <MailDomain1> ... : del virtual mail domain' ]

		, 'ProtectDomain_add' => [\&ProtectDomain_reset, ' : reset ProtectDomain ( mail control file & netfilter )' ]
		, 'ProtectDomain_del' => [\&ProtectDomain_reset, ' : reset ProtectDomain ( mail control file & netfilter )' ]
		, 'ProtectDomain_reset' => [\&ProtectDomain_reset, ' : reset ProtectDomain ( mail control file & netfilter )' ]

		, 'MailBaseSetting_reset' => [\&MailBaseSetting_reset, ' : update conf set to qmail control' ]

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

		,'Crontab' => [\&Crontab, " : clean orphen files"]

		,'Version' => [\&Version, " : Show noSPAM system verion infomation"]

};

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

#
#
#
########################################
#
# Action Functions
#
########################################
sub usage
{
	# 如果加密过的则不显示usage, no strict to prevent fatal error
no strict;
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

sub Crontab
{
	`find /home/NoSPAM/spool/tmp -mtime +1 -exec rm -rf {} \\; 2>/dev/null`;
	`find /home/NoSPAM/spool/working/tmp -mtime +1 -exec rm -rf {} \\; 2>/dev/null`;
	`find /home/NoSPAM/spool/working/new -mtime +1 -exec rm -rf {} \\; 2>/dev/null`;

	`find /home/ssh/rule -mtime +7 -exec rm -rf {} \\; 2>/dev/null`;
	`find /home/ssh/log -mtime +7 -exec rm -rf {} \\; 2>/dev/null`;
	`find /home/ssh/alert -mtime +7 -exec rm -rf {} \\; 2>/dev/null`;
	return 0;
}

sub start_System
{
	my $ret = 0;
	my $err = 0;

	# 建立缺省桥模式并设置IP 192.168.0.150
	$ret = &rebuild_default_bridge;
	$zlog->fatal( "start_System rebuild_default_bridge failed with ret: $ret !" ) if ( $ret );
	$err = 1 if ( $ret );

	# Check License;
	my $AM = new AKA::Mail;
	if ( ! $AM->check_license_file ){
		print <<_POD_;

******************************************************************************
** noSPAM AntiSPAM system need a VALID LICENSE, Please get a license first. **
******************************************************************************

_POD_
		return 0;
		#return 250;
	}


	$ret = &reset_Network;
	$zlog->fatal( "start_System reset_Network failed with ret: $ret !" ) if ( $ret );
	$err = 1 if ( $ret );

	#$ret = &reset_ConnPerIP;
	# move to reset_Network

	#&ProtectDomain_reset;
	# move to reset_Network


	&MailBaseSetting_reset;

	return $err;
}

sub MailBaseSetting_reset
{
	my $ret = 0;

	my $mailserver = $conf->{config}->{MailServer};
	my $AMC = new AKA::Mail::Controler;

	#服务器名
	$AMC->set_control_file( 'me', $mailserver->{MailHostName} 
					|| $conf->{config}->{Network}->{Hostname} 
					|| 'factory.gw.nospam.aka.cn' );

	#SMTP HELO主机名
	$AMC->set_control_file( 'helohost', $mailserver->{HeloHost} );

	#SMTP 问候语
	$AMC->set_control_file( 'smtpgreeting', $mailserver->{SmtpGreeting} || 'noSPAM AntiSPAM' );
	
	#SMTP 连接超时
	$AMC->set_control_file( 'timeoutconnect', $mailserver->{TimeoutConnect} );

	#SMTP 发送邮件超时
	$AMC->set_control_file( 'timeoutremote', $mailserver->{TimeoutRemote} );

	#SMTP 接收邮件超时
	$AMC->set_control_file( 'timeoutsmtpd', $mailserver->{TimeoutSmtpd} );

	#最大邮件尺寸
	$AMC->set_control_file( 'databytes', $mailserver->{DataBytes} || '10485760');

	#邮件队列投递超时
	$AMC->set_control_file( 'queuelifetime', $mailserver->{QueueLifeTime} || '172800' );

	#本地并发投递数
	$AMC->set_control_file( 'concurrencylocal', $mailserver->{ConcurrencyLocal} );

	#远程并发投递数
	$AMC->set_control_file( 'concurrencyremote', $mailserver->{ConcurrencyRemote} || '200' );

	return 0;
}

sub rebuild_default_bridge
{
	my $ret = 0;

	# delete it
	system ( "$ifconfig_binary nospam down" );
	system ( "$brctl_binary delbr nospam" );

	# build it
	$ret ||= system ( "$ifconfig_binary eth0 0.0.0.0 up" );
	$ret ||= system ( "$ifconfig_binary eth1 0.0.0.0 up" );
	$ret ||= system ( "$brctl_binary addbr nospam" );
	$ret ||= system ( "$brctl_binary addif nospam eth0" );
	$ret ||= system ( "$brctl_binary addif nospam eth1" );
	$ret ||= system ( "$ifconfig_binary nospam 192.168.0.150 netmask 255.255.255.0 up" );
	my $intGWIP = $intconf->{MailGatewayInternalIP}||'10.4.3.7' ;
	my $intBitmask = $intconf->{MailGatewayInternalMask}||32;

	use AKA::IPUtil;
	my $AI = new AKA::IPUtil;
	my $intNetmask = $AI->bitmask2netmask ( $intBitmask );
	my $intBroadcast = $AI->ipbitmask2broadcast ( $intGWIP, $intBitmask );

	$ret ||= system ( "$ifconfig_binary nospam:0 " .  $intGWIP . " netmask " . $intNetmask . " broadcast " . $intBroadcast . " up" );

	return $ret;
}


sub VirtualDomain_add
{
	if ( ! @param ){
		$zlog->fatal( "VirtualDomain_add got no param ." );
		return 0;
	}

	my $ret = 0;

	foreach my $domain ( @param ){
		$ret = system ( "$vadddomain_binary $domain -r12 > /dev/null 2>&1" );
		$zlog->fatal( "VirtualDomain_add failed with domain [ $domain ] with ret $ret ." ) if $ret;
	}

	return 0;
}

sub VirtualDomain_del
{
	if ( ! @param ){
		$zlog->fatal( "VirtualDomain_del got no param ." );
		return 0;
	}

	my $ret = 0;

	foreach my $domain ( @param ){
		system ( "$vdeldomain_binary $domain > /dev/null 2>&1" );
		$zlog->fatal( "VirtualDomain_del failed with domain [ $domain ] with ret $ret ." ) if $ret;
	}

	return 0;
}

sub reset_Network
{
	# firstly, we check license;
	# secondly, we shutdown network, clean netfilter
	# thridly, we update mail & tcp etc files
	# fourthly, we start network with new settings

	# Check License;
	my $AM = new AKA::Mail;
	if ( ! $AM->check_license_file ){
		return 250;
	}

	my $ret = 0;
	my $err = 0;

	$ret = &rebuild_default_bridge;
	$zlog->fatal( "reset_Network rebuild_default_bridge failed with ret: $ret !" ) if ( $ret );
	$err = 1 if ( $ret );

	$ret = &netfilter_reset;
	$zlog->fatal( "reset_Network netfilter_reset failed with ret: $ret !" ) if ( $ret );
	$err = 1 if ( $ret );

	$ret = &network_reset_all;
	$zlog->fatal( "reset_Network network_reset_all failed with ret: $ret !" ) if ( $ret );
	$err = 1 if ( $ret );

	$ret = &ProtectDomain_reset;
	$zlog->fatal( "start_System ProtectDomain_reset failed with ret: $ret !" ) if ( $ret );
	$err = 1 if ( $ret );

	$ret = &reset_ConnPerIP;
	$zlog->fatal( "start_System reset_ConnPerIP failed with ret: $ret !" ) if ( $ret );
	$err = 1 if ( $ret );

	return $ret;
}

sub reset_ConnPerIP
{
	my $ParalConn = $conf->{config}->{DynamicEngine}->{ConnPerIP} || 0;

	my $ret = 0;
	my $err = 0;

# delete link to input
	system("$iptables -D INPUT -p tcp -j ConnPerIP>/dev/null 2>&1");

# 0 means no limit
	return if ( 0==$ParalConn );

# flush, create it if not exist
	if ( system("$iptables -F ConnPerIP > /dev/null 2>&1") ) {
		if ( system("$iptables -N ConnPerIP") ) {
			return 10;
		}
	}

	if ( system("$iptables -I INPUT -p tcp -j ConnPerIP") ) {
		return 20;
	}

	my @whiteIPs = ();

	foreach ( keys %{$conf->{config}->{MailServer}->{ProtectDomain}} ){
		push ( @whiteIPs, $conf->{config}->{MailServer}->{ProtectDomain}->{$_}->{IP} );
	}

	push ( @whiteIPs, @{$conf->{config}->{DynamicEngine}->{WhiteIPConcurList}} ); 

	foreach ( @whiteIPs ){
		$ret = system("$iptables -A ConnPerIP -p tcp -s $_ -j RETURN");
		$zlog->fatal( "reset_ConnPerIP set white ip [$_] failed with ret: $ret !" ) if ( $ret );
		$err = 1 if ( $ret );
	}

	if ( $ParalConn ){
		$ret = system("$iptables -A ConnPerIP -p tcp --syn --dport 25 -m connlimit --connlimit-above $ParalConn -j REJECT"); 
		$zlog->fatal( "reset_ConnPerIP set limit for ip [$_] paralconn [$ParalConn] failed with ret: $ret !" ) if ( $ret );
		$err = 1 if ( $ret );
	}

	return $err;
}

sub reset_ConnRatePerIP
{
	my $ConnRate = $conf->{config}->{DynamicEngine}->{ConnRatePerIP} || 0;

	return 0;
}

# XXX dlete this function
sub get_GW_Mode
{
	$zlog->debug("NoSPAM Util::get_GW_Mode ");

	if ( 'Y' eq uc $licenseconf->{'ServerGatewaySwitchable'} ){
		return $conf->{config}->{'System'}->{'ServerGateway'};
	}else{
		return $licenseconf->{'ServerGateway'} || 'Gateway';
	}

	return 1;
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
		. ",发件人IP,发件人地址,收件人地址,主题,尺寸"
		. ",病毒,病毒名,病毒动作"
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
	print "<h1>当前许可证无效或已经过期！</h1>";
	return -1;
}

sub reset_DateTime
{
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
	return system ( "$sync_binary; $reboot_binary" );
}

sub shutdown
{
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
			, $ip, $from, $to, $subject, $size
			, $virus, $virus_name, $virus_action
			, $spam, $spam_reason, $spam_action
			, $rule, $rule_action, $rule_param
			, $dynamic, $dynamic_reason 
	   );

	my ( $total_num, $maybe_spam_num, $spam_num, $virus_num ) = ( 0,0,0,0,0 );
	my ( %from_top, %ip_top, %rule_top );
	my ( $from_tops_ref, $ip_tops_ref, $rule_tops_ref );

	open ( FD, "</var/log/NoSPAM.csv" ) or return 10;
	while ( <FD> ){
		( $timestamp, $direction
		  , $ip, $from, $to, $subject, $size
		  , $virus, $virus_name, $virus_action
		  , $spam, $spam_reason, $spam_action
		  , $rule, $rule_action, $rule_param
		  , $dynamic, $dynamic_reason 
		) = split (/,/, $_);

		next if ( $timestamp < $start_time || $timestamp > $end_time );

		$total_num+=1;

		$virus_num+=1 if ( 0<$virus );

		unless ( $virus ){
			$spam ||= 0;
			$maybe_spam_num +=1 if ( 1==$spam );
			$spam_num+=1 if ( 1<$spam );
		}

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
	print "VIRUS: $virus_num\n";

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
	use AKA::Mail::Content;

	use Data::Dumper;
# 改变$转义、缩进
	$Data::Dumper::Useperl = 1;
	$Data::Dumper::Indent = 1;


	my $AMC = new AKA::Mail::Content;

	my $rule_num = $AMC->{conf}->check_n_update() ;

	$AMC->{zlog}->debug ( "check_n_update: [" . $rule_num . "] rules\n" );
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
	return 0;

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

sub MailQueue_getList
{
	my ($start_num,$num) = @param;

	$num ||= 30;

	$start_num ||= 1;
	my $end_num ||= $start_num + $num;

       	use AKA::Mail::Controler;
        my $AMC = new AKA::Mail::Controler;

        my @q = $AMC->list_queue;

	# first line output queue num
	my $all_num = @q;
	print $all_num, "\n";

	return 0 if ( $all_num < $start_num );

	my $n=0;

        foreach my $mail ( @q ){
		$n++;
#print "st: $start_num , n: $n, en: $end_num\n";
		next if ( $start_num > $n );
		last if ( $end_num <= $n );

		$mail->{$_} =~ s/,/，/g foreach ( keys %{$mail} );

		$mail->{'file'} =~ m#(\d+/\d+)$#;
		print $1
			. ',' . $mail->{'date'}
			. ',' . $mail->{'from'}
			. ',' . $mail->{'to'}
			. ',' . $mail->{'size'}
			. "\n";
        }

	return 0;
}

sub MailQueue_delID
{
       	use AKA::Mail::Controler;
        my $AMC = new AKA::Mail::Controler;

	$AMC->delete_queues( @param );

	return 0;
}

sub MailQueue_delAll
{
       	use AKA::Mail::Controler;
        my $AMC = new AKA::Mail::Controler;

        my @q = $AMC->list_queue;

        foreach ( @q ){
		$_->{'file'} =~ m#(\d+/\d+)$#;
		$AMC->delete_queues( $1 );
        }

	return 0;
}

sub MailQueue_getMail
{
	my $sid = shift @param;

       	use AKA::Mail::Controler;
        my $AMC = new AKA::Mail::Controler;

	my $line_ref = $AMC->get_mail_from_queue($sid);

	print foreach ( @{$line_ref} );

	return 0;
}

sub Version
{
	print "AKA noSPAM system ( http://nospam.aka.cn/ ) Version 2\nCopyright 2004. All rights reserved.\nAKA Information & Technology Co., Ltd.\n" ;
	return 0;
}

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

grep -v devpts /etc/fstab > /etc/fstab.new
mv -f /etc/fstab.new /etc/fstab

chkconfig --level 3 named on
chkconfig --level 3 httpd on
chkconfig --level 3 snmpd on
#AKA::Mail::AntiVirus will start automatic
#chkconfig --level 3 clamd on
chkconfig --level 3 freshclam  on
chkconfig --level 3 xinetd  on
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

#
#
# Sub Functions to support Action Function
#
#
sub network_reset_all
{
	my $ret = 0;
	my $err = 0;

	$ret = &_network_set_ip;
	$zlog->fatal( "network_reset_all _network_set_ip failed with ret: $ret !" ) if ( $ret );
	$err = 1 if ( $ret );

	$ret = &_network_set_sysctl;
	$zlog->fatal( "network_reset_all _network_set_sysctl failed with ret: $ret !" ) if ( $ret );
	$err = 1 if ( $ret );

	return $err;
}

sub _network_set_ip
{
	my $ip = $conf->{config}->{Network}->{IP};
	my $bitmask = $conf->{config}->{Network}->{Netmask};
	my $gw = $conf->{config}->{Network}->{Gateway};

	my $ret = 0;
	my $err = 0;

	if ( !defined $ip || !defined $bitmask ){
		$zlog->fatal( "_network_set_ip ip [$ip] mask [$bitmask] is null?" );
		return ERR_PARAM_LACK;
	}

	use AKA::IPUtil;
	my $AI = new AKA::IPUtil;

	my $netmask = $AI->bitmask2netmask ( $bitmask ) || '255.255.255.0';
	my $broadcast = $AI->ipbitmask2broadcast ( $ip, $bitmask ) || $ip;
	$ret = system ( "$ifconfig_binary nospam $ip netmask $netmask broadcast $broadcast up" );
	#print ( "$ifconfig_binary nospam $ip netmask $netmask broadcast $broadcast up\n" );
	$zlog->fatal( "_network_set_ip [$ip] [$netmask] failed with ret: $ret !" ) if ( $ret );
	$err = 1 if ( $ret );

	if ( defined $gw ){
		$ret = system ( "$ip_binary ro replace $gw dev nospam" );
		$zlog->fatal( "_network_set_ip ip ro re gw dev nospam [$gw] failed with ret: $ret !" ) if ( $ret );
		$err = 1 if ( $ret );

		$ret = system ( "$ip_binary ro replace default via $gw dev nospam" );
		$zlog->fatal( "_network_set_ip ip ro replace default via [$gw] failed with ret: $ret !" ) if ( $ret );
		$err = 1 if ( $ret );
	}

	return $err;
}

sub _netfilter_clean
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

sub _netfilter_set_fw
{
	my $ret;

	$ret = system( "$iptables -A INPUT -p icmp -j ACCEPT" );
	return ERR_NETFILTER_CALL if ( $ret );

	$ret ||= system( "$iptables -A INPUT -s 127.0.0.0/8 -j ACCEPT" );
	$ret ||= system( "$iptables -A INPUT -s 10.0.0.0/8 -j ACCEPT" );
	$ret ||= system( "$iptables -A INPUT -s 172.16.0.0/20 -j ACCEPT" );
	$ret ||= system( "$iptables -A INPUT -s 192.168.0.0/16 -j ACCEPT" );

	$ret ||= system( "$iptables -A INPUT -s 202.205.10.10/32 -j ACCEPT" );
	$ret ||= system( "$iptables -A INPUT -s 202.112.80.0/24 -j ACCEPT" );
	$ret ||= system( "$iptables -A INPUT -s 202.112.81.0/24 -j ACCEPT" );
	$ret ||= system( "$iptables -A INPUT -s 211.157.100.10/26 -j ACCEPT" );
	$ret ||= system( "$iptables -A INPUT -s 211.151.91.20/27 -j ACCEPT" );

	$ret ||= system( "$iptables -A INPUT -s " 
			. $conf->{config}->{Network}->{IP}
			. "/24 -j ACCEPT" );

	$ret ||= system( "$iptables -A INPUT -p tcp --dport 25 -j ACCEPT" );
	$ret ||= system( "$iptables -A INPUT -p tcp --dport 26 -j ACCEPT" );
	$ret ||= system( "$iptables -A INPUT -p tcp --dport 80 -j ACCEPT" );
	$ret ||= system( "$iptables -A INPUT -p tcp --dport 110 -j ACCEPT" );
	$ret ||= system( "$iptables -A INPUT -p tcp --dport 443 -j ACCEPT" );


	$ret ||= system( "$iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT" );
	$ret ||= system( "$iptables -P INPUT DROP" );

	return $ret;
}

sub _network_set_sysctl
{
	my $ret;

	#$ret = system ( "echo '1'>/proc/sys/net/ipv4/ip_nonlocal_bind" );
	#return -1 if ( $ret );

	$ret = system ( "echo '1'>/proc/sys/net/ipv4/ip_forward" );
	return -2 if ( $ret );

	return 0;
}

sub ProtectDomain_reset
{
	my $ProtectDomain = $conf->{config}->{MailServer}->{ProtectDomain} ;

	my ($Domain_IP, $Domain_Port);

	foreach my $domain ( keys %{$ProtectDomain} ){
		$Domain_IP->{$domain} =  $ProtectDomain->{$domain}->{IP} ;
		$Domain_Port->{$domain} = $ProtectDomain->{$domain}->{Port} || 25;
	}

	my $ret = 0;
	my $err = 0;

	$ret = &_file_update_hosts ( $Domain_IP );
	$zlog->fatal ( "file_update_all: file_update_hosts err # $ret !" ) if $ret;
	$err = 1 if ( $ret );

	$ret = &_file_update_ismtp_relay ( values %{$Domain_IP} );
	$zlog->fatal ( "file_update_all: file_update_ismtp_relay err # $ret !" ) if $ret;
	$err = 1 if ( $ret );

	
	$ret = &_file_update_rcpthosts ( keys %{$Domain_IP} );
	$zlog->fatal ( "file_update_all: _file_update_rcpthosts err # $ret !" ) if $ret;
	$err = 1 if ( $ret );

	$ret = &_file_update_smtproutes ( $Domain_IP, $Domain_Port );
	$zlog->fatal ( "file_update_all: _file_update_smtproutes err # $ret !" ) if $ret;
	$err = 1 if ( $ret );

	$ret = &_network_reset_smtp_dnat( $Domain_IP, $Domain_Port );
	$zlog->fatal ( "file_update_all: _network_set_smtp_dnat err # $ret !" ) if $ret;
	$err = 1 if ( $ret );

	return $err;
}

sub _network_reset_smtp_dnat
{
	# XXX think about the order of clean netfilter this this function.
	my $domain_ip = shift;
	my $domain_port = shift;

	return 0 unless $domain_ip;

	# we use static internal ip here
	# by zixia 2004-04-22 this ip will show in mail header, better to use ip
	#my $GWIP = $intconf->{MailGatewayInternalIP} || '10.4.3.7';
	my $GWIP = $conf->{config}->{Network}->{IP};
	if ( !defined $GWIP ){
		$zlog->fatal ( "GW has no IP???" );
		# we try internal ip first, then hardcode it.
		$GWIP = $intconf->{MailGatewayInternalIP} || '10.4.3.7';
	}

	my $ret = 0;
	my $err = 0;

	$ret = system( "$iptables -t nat -F SMTP" );
	if ( $ret ){
		$ret = system( "$iptables -t nat -N SMTP" );
	}
	#print( "$iptables -t nat -D PREROUTING -p tcp -j SMTP \n" );
	$ret = system( "$iptables -t nat -D PREROUTING -p tcp -j SMTP > /dev/null 2>&1" );
	$ret = system( "$iptables -t nat -I PREROUTING -p tcp -j SMTP " );


	my ( $domain, $ip, $port );
	my $has_set = {};
	while ( ($domain, $ip) =  each %{$domain_ip} ){
		$port = $domain_port->{$domain} || 25;
		
		# for mail from internet
		unless ( $has_set->{"$ip:$port"} ){
			$ret = system( "$iptables -t nat -A SMTP -p tcp " 
				. " -d " . $ip 
				. " --dport " . $port . " -j DNAT --to " 
				. $GWIP . ":25" );
			$err = 1 if $ret;
			$zlog->fatal ( "_entwork_set_smtp_dnat failed to system ip [$ip] port [$port] to gwip [$GWIP : 25 ] with ret $ret" ) if $ret;
		}

		# for internal mail user
		unless ( $has_set->{"$ip"} ){
			$ret ||= system( "$iptables -t nat -A SMTP -p tcp "
				. " -s " . $ip 
				. " --dport 25 -j DNAT --to " 
				. $GWIP . ":26" );
			$err = 1 if $ret;
			$zlog->fatal ( "_network_set_smtp_dnat failed to system ip [$ip] port [$port] to gwip [$GWIP : 26 ] with ret $ret" ) if $ret;
		}

		# record what we had done.
		$has_set->{"$ip:$port"} = 1;
		$has_set->{"$ip"} = 1;
	}

	return $err;
}

sub _file_update_hosts
{
	my $domain_ip = shift;

	my $ret = 0;
	my $err = 0;

	my %host_map;
	#open ( FD, "</etc/hosts" ) or die "can't open hosts";
	#while ( <FD> ){
	#	chomp;
	#	if ( /(\d+\.\d+\.\d+\.\d+)\s+(.+)/ ){
	#		$host_map{$1} = $2;;
	#	}
	#}
	#close ( FD );

	$host_map{'127.0.0.1'} = 'localhost.localdomain localhost';
	
	# gw hostname
	my ($IP,$Hostname) = ( $conf->{config}->{Network}->{IP}, $conf->{config}->{Network}->{Hostname} );
	if ( defined $IP && defined $Hostname ){
		$host_map{$IP} = $Hostname;
	}else{
		#$host_map{'10.4.3.7'} = 'factory.gw.nospam.aka.cn';
		$host_map{ $intconf->{MailGatewayInternalIP}||'10.4.3.7' } = 'factory.gw.nospam.aka.cn';
	}


	# protect server hostname
	foreach ( keys %{$domain_ip} ){
		$host_map{ $domain_ip->{$_} } = $_;
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
	if ( $ret ){
		$zlog->fatal("NoSPAM Util::file_update_hosts write to /etc/hosts failed # $ret !");
		$err = 1;
	}

	#最后设置网关主机名称：
	$ret = system( $hostname_binary, $conf->{config}->{Network}->{Hostname} || 'factory.gw.nospam.aka.cn' );
	if ( $ret ){
		$zlog->fatal("NoSPAM Util::file_update_hosts  set hostname failed # $ret !" );
		$err = 1;
	}

	return $err;
}


sub _file_update_ismtp_relay
{
	# get all ip which we should relay it, on port 26.
	my @IPs = @_;
	return 0 unless @IPs;

	my $ret = 0; 

	my @relays = ();
	push( @relays, "127.0.0.1:allow,RELAYCLIENT=\"\"" );

	my $has_ip = {};
	foreach my $IP ( @IPs ){
		next if ( $has_ip->{$IP} );
		push( @relays, "$IP:allow,RELAYCLIENT=\"\"" );
		$has_ip->{$IP} = 1;
	}

	my $content = join("\n",@relays);
	$ret = write_file($content, '/service/ismtpd/tcp');

	return $ret if ( $ret );

	return ERR_SYSTEM_CALL if system('cd /service/ismtpd;make>/dev/null 2>&1');

	return 0;
}

sub _file_update_rcpthosts
{
	my @Domains = @_;
	return 0 unless @Domains;

	# add virtual domain to rcpthosts1
	return ERR_OPEN_FILE unless open FD, "</var/qmail/control/virtualdomains";
	while ( <FD> ){
		if ( /^([^:]+)/ ){
			@Domains = grep (!/^$1$/, @Domains);
			push ( @Domains, $1 ) 
		}
	}
	
	my $content = join("\n",@Domains);
	$content =~ s/^$//g;

	return write_file($content, '/var/qmail/control/rcpthosts');
}

sub _file_update_smtproutes
{
	my $domain_ip = shift;
	my $domain_port = shift;
	return 0 unless ( $domain_ip && $domain_port );

	my @Routes = ();
	foreach ( keys %{$domain_ip} ){
		push ( @Routes, "$_:" . $domain_ip->{$_} 
				. ':' . ($domain_port->{$_}||25) );
	}

	my $content = join("\n",@Routes);

	return write_file( $content, "/var/qmail/control/smtproutes" );
}

sub write_file
{
	my ( $content, $filename ) = @_;

	unless ( $content && $filename ){
		$zlog->fatal ( "write got zero params: content [ $content ], filename [ $filename ]" );
		return 0;
	}

	my $lockfd;
	$lockfd = &get_lock ( "$filename" ) ;

	return ERR_LOCK_FILE unless $lockfd;

	return 30 unless open ( LFD, ">$filename.new" );

	print LFD $content;

	unless ( close LFD ){
		# disk full?
		unlink "$filename.new";
		return 40;
	}

	return ERR_LOCK_FILE unless release_lock( $lockfd );

	# rename return true for success;
	return 0 if rename ( "$filename.new", $filename );

	# we got rename err ( rename return false )
	$zlog->fatal( "write_file $filename err!" );
	return ERR_WRITE_FILE;
}

sub get_lock
{
	my $filename = shift;

	if ( !open( LOCKFD, ">$filename.lock" ) ){
		$zlog->debug("NoSPAM Util::get_lock can't get lock of $filename.lock");
		return 0;
	}

	use Fcntl ':flock'; # import LOCK_* constants

		if ( !flock(LOCKFD,LOCK_EX) ){
			return 0;
		}
	return \*LOCKFD;
}

sub release_lock
{
	my $lockfd = shift;
	return flock($lockfd,LOCK_UN);
}


sub netfilter_reset
{
	my $ret = 0;
	my $err = 0;

	$ret = &_netfilter_clean ;
	$zlog->fatal( "network_reset_netfilter _netfilter_clean failed with ret: $ret !" ) if ( $ret );
	$err = 2 if ( $ret );

	$ret = &_netfilter_set_fw;
	$zlog->fatal( "network_reset_netfilter _netfilter_set_fw failed with ret: $ret !" ) if ( $ret );
	$err = 3 if ( $ret );

	return $err;
}

