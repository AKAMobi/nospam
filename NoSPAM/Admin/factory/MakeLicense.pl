#!/usr/bin/perl -w

use POSIX qw(strftime);

my $prodno = $ARGV[0];
die "pls provide prodno\n" unless $prodno ;

my $now = strftime "%Y-%m-%d %H:%M:%S", localtime;

$License = <<_LICENSE_;
ForSell=No
GenerateDate=$now
ExpireDate=2004-8-1
Version=2

FactoryName=
ProductName=noSPAM
ProductSN=$prodno

ServerGatewaySwitchable=Y
ServerGateway=Gateway,Server,MXRelay,Tailer

LicenseHTML=<b>客户试用体验(非销售)版</b>

MailGateway=100
MailServer=100
MailRelay=100
AntiVirusEngine=100
DynamicEngine=100
SpamEngine=100
ContentEngine=100
ArchiveEngine=100
InteractiveEngine=100
GAInterface=100


#独立服务器的License限制；
MailServerMaxUser=1000
MailServerMaxDomain=10
MailServerMaxQuota=30000000

_LICENSE_


use AKA::License;
$AL = new AKA::License;

print make_license( $License, $prodno ), "\n";

sub make_license
{

        my ( $license_orig, $prodno ) = @_;

        my ( $license_data, $license_checksum );

        $license_data = $AL->get_valid_license( $prodno );

        $license_ret = $license_orig . "\nProductLicense=$license_data";

        $license_checksum = $AL->get_checksum($license_ret);

        $license_ret .= "\nProductLicenseExt=$license_checksum";

        return $license_ret;
}

