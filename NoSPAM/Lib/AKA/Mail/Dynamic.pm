#
# ·´À¬»øÅÐ¶Ï¶¯Ì¬ÒýÇæ
# Company: AKA Information & Technology Co., Ltd.
# Author: Ed Lee
# EMail: zixia@zixia.net
# Date: 2004-03-07


package AKA::Mail::Dynamic;
use AKA::Mail::Conf;
use AKA::Mail::Log;

sub new
{
	my $class = shift;

	my $self = {};
	bless $self, $class;

	my $parent = shift;

	$self->{parent} = $parent;
	$self->{conf} = $parent->{conf} || new AKA::Mail::Conf;#die "Mail::Conf can't get parent conf!"; 
	$self->{zlog} = $parent->{zlog} || new AKA::Mail::Log;#die "Mail::Conf can't get parent zlog!"; 
	return $self;
}


1;



