#!/usr/bin/perl -w

$prodno = $ARGV[0];
die "pls provide prodno\n" unless $prodno ;

$License = <<_LICENSE_;
ServerGatewaySwitchable=N
ServerGateway=Gateway
LicenseHTML=<b>◊œπ‚ ‘”√∞Ê 2004-3</b>
_LICENSE_


print make_license( $License, $prodno ), "\n";

sub make_license
{
	use AKA::License;
	$AL = new AKA::License;

        my ( $license_orig, $prodno ) = @_;

        my ( $license_data, $license_checksum );

        $license_data = $AL->get_valid_license( $prodno );

        $license_ret = $license_orig . "\nProductLicense=$license_data";

        $license_checksum = $AL->get_checksum($license_ret);

        $license_ret .= "\nProductLicenseExt=$license_checksum";

        return $license_ret;
}

