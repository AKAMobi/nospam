#!/usr/bin/perl -w

# K12 wMail License Generator

use POSIX qw(strftime);
use Digest::MD5 qw(md5_base64 md5_hex);
use strict;

my $prodno = $ARGV[0];
die "pls provide prodno\n" unless $prodno ;

my $now = strftime "%Y-%m-%d %H:%M:%S", localtime;


my $License = <<_LICENSE_;
ForSell=No
GenerateDate=$now

FactoryName=K12
ProductName=WebMail
ProductSN=$prodno

_LICENSE_

print make_license( $License, $prodno ), "\n";

sub make_license
{

        my ( $license_orig, $prodno ) = @_;

        my ( $license_data, $license_checksum );

        $license_data = &get_valid_license( $prodno );

        my $license_ret = $license_orig . "\nProductLicense=$license_data";

        $license_checksum = &get_checksum($license_ret);

        $license_ret .= "\nProductLicenseExt=$license_checksum";

        return $license_ret;
}

sub get_valid_license
{
	my $prod_no = shift;

	my $license_orig = "zixia" . $prod_no . "K12" . $prod_no . "wMail";
	return md5_hex ( $license_orig );
}

sub get_checksum
{
	my $license_dat = shift;
	
	my $license_dat_orig = "zixia" . $license_dat . "K12" . $license_dat . "wMail";
	return md5_base64( $license_dat_orig );
}
