#!/usr/bin/perl -w

$prodno = $ARGV[0];
die "pls provide prodno\n" unless $prodno ;

$License = <<_LICENSE_;
ForSell=No
ExpireDate=2004-12-31
Version=1

FactoryName=
ProductName=iXRay

ServerGatewaySwitchable=N
ServerGateway=Gateway

LicenseHTML=<b>客户试用体验(非销售)版</b>


DynamicEngineEnabled=Yes
ContentEngineEnabled=Yes
SpamEngineEnabled=Yes

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

