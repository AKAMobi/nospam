#!/usr/bin/perl -w

$prodno = $ARGV[0];

$License = <<_LICENSE_;
ServerGatewaySwitchable=N
ServerGateway=Gateway
_LICENSE_

use AKA::License;
$AL = new AKA::License;


print $AL->make_license( $License, $prodno ), "\n";
