package AKA::Loader ;

require 5.002 ;
require DynaLoader;
use strict;
use warnings;
use vars qw(@ISA $VERSION);
@ISA = qw(DynaLoader);
$VERSION = "1.20" ;

bootstrap AKA::Loader ;
1;
