#!/usr/bin/perl -w

$prodno = $ARGV[0];

$License = <<_LICENSE_;
ServerGatewaySwitchable=N
ServerGateway=Gateway
_LICENSE_


print make_license( $License, $prodno ), "\n";

sub make_license
{
	use AKA::License;
	$AL = new AKA::License;

        my ( $license_orig, $prodno ) = @_;

        my ( $license_data, $license_checksum );

        $license_data = $AL->get_valid_license( $prodno );

        $license_ret = $license_orig . "\nProductLicense=$license_data\n";

        $license_checksum = $AL->get_checksum($license_ret);

        $license_ret .= "ProductLicenseExt=$license_checksum";

        return $license_ret;
}

