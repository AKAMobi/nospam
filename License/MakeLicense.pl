#!/usr/bin/perl -w

   use Digest::MD5  qw(md5 md5_hex md5_base64);

        #print md5($ARGV[0]), "\n";
        print md5_hex($ARGV[0]), "\n";
        print md5_base64($ARGV[0]), "\n";

use AKA::License;
my $AL = new AKA::License;
my $hd_serial = $AL->get_IDE_serial;
print "hd_serial: \n" . $hd_serial . "\n";
