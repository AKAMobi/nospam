#
# 北京互联网接警中心邮件过滤器
# Company: AKA Information & Technology Co., Ltd.
# Author: Ed Lee
# EMail: zixia@zixia.net
# Date: 2004-02-10


use AKA::Mail::Police::Conf;
use AKA::Mail::Log;
use AKA::Mail::Police::Filter;
use AKA::Mail::Police::Verify;

package AKA::Mail::Police;

#BEGIN
#{
#	open MYLOG, ">>/tmp/mylog.log";
#}

sub new
{
	my $class = shift;

	my $self = {};

	bless $self, $class;

	my $parent = shift;

	$self->{parent} = $parent;
	$self->{zlog} = $parent->{zlog} || new AKA::Mail::Log($self);
	$self->{conf} = new AKA::Mail::Police::Conf($self);
	$self->{verify} = new AKA::Mail::Police::Verify($self);
	$self->{filter} = new AKA::Mail::Police::Filter($self);

	return $self;

}

sub get_action
{
	$self = shift;

	return $self->{filter}->get_action( @_ );
}

sub print
{
	$self = shift;

	return $self->{filter}->print(@_)
}


sub clean
{
	$self = shift;

	return $self->{filter}->clean;
}


1;



