#
# 北京互联网接警中心邮件过滤器
# Company: AKA Information & Technology Co., Ltd.
# Author: Ed Lee
# EMail: zixia@zixia.net
# Date: 2004-02-10


use AKA::Mail::Content::Conf;
use AKA::Mail::Log;
use AKA::Mail::Content::Filter;
use AKA::Mail::Content::Verify;

package AKA::Mail::Content;

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
	$self->{conf} = new AKA::Mail::Content::Conf($self);
	$self->{verify} = new AKA::Mail::Content::Verify($self);
	$self->{filter} = new AKA::Mail::Content::Filter($self);

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



