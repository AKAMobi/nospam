#!/usr/bin/perl -w

use strict;
use POSIX qw(strftime);

use AKA::Mail::Conf;
use AKA::Mail::Log;

(my $prog=$0) =~ s/^.*\///g;
my $action = shift @ARGV;
my @param = @ARGV;


my $conf = new AKA::Mail::Conf;
my $intconf = &get_intconf;
my $licenseconf = &get_licenseconf;
my $zlog = new AKA::Mail::Log;

my $action_map = { 'reset_Network' => [\&reset_Network, ""],
			'get_GW_Mode' => [\&get_GW_Mode, ""], 
			'get_Serial' => [\&get_Serial, ""],
			'check_License' => [\&check_License, ""],
			'reset_DateTime' => [\&reset_DateTime, "param1: YYYY-mm-DD HH:MM:SS"],
			'reboot' => [\&reboot, ""],
			'shutdown' => [\&shutdown, ""]
		};


#use Data::Dumper;
#print Dumper( $intconf );
print &get_GW_Mode_backend(), "\n";
exit 0;

# do the action now!
if ( ! defined $action ){
	&usage;
	exit -1;
}elsif( defined $action_map->{$action}[0] ){
	exit &{$action_map->{$action}[0]};
	$zlog->debug("NoSPAM Util:: $action @param");
}else{
	print "NoSPAM System Util unsuport action: $action\n";
}


# if program run to here, must be some error!
exit -1;

#############################

sub usage
{
	print STDERR <<_USAGE_;

$prog <action> [action params ...]
  action could be:
_USAGE_
	foreach ( keys %{$action_map} ){
		print STDERR "    $_ ";
		if ( defined $action_map->{$_}[1] ){
			print STDERR "$action_map->{$_}[1]";
		}
		print STDERR "\n";
	}
	print STDERR "\n";
}

sub get_licenseconf
{
	my $licenseconf;

	my $license_file = $conf->{define}->{licensefile};

	open ( LCFD, "<$license_file" ) or die "NoSPAM Util can't open license file\n";

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

sub get_GW_Mode_backend
{
	if ( 'Y' eq uc $licenseconf->{'ServerGatewaySwitchable'} ){
		return $conf->{config}->{'ServerGateway'};
	}else{
		return $licenseconf->{'ServerGateway'} || 'Gateway';
	}
}

########################################
#
# Action Functions
#
########################################
sub reset_Network
{
	$zlog->debug("NoSPAM Util::reset_Network ");

	my $ifconfig = "/sbin/ifconfig";
	my $arp = "/sbin/arp";
	my $iptables = "/sbin/iptables";

}

sub get_GW_Mode
{
	
	$zlog->debug("NoSPAM Util::get_GW_Mode ");
	
}

sub get_Serial
{
	
	$zlog->debug("NoSPAM Util::get_Serial ");
}

sub check_License
{
	$zlog->debug("NoSPAM Util::check_License ");
}

sub reset_DateTime
{
	$zlog->debug("NoSPAM Util::reset_DateTime $param[0]");
}

sub reboot
{
	$zlog->debug("NoSPAM Util::reboot");
}

sub shutdown
{
	$zlog->debug("NoSPAM Util::reset_DateTime");
}

