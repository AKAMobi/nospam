#
# noSPAM 用户列表接口
# Company: AKA Information & Technology Co., Ltd.
# Author: Ed Li
# EMail: zixia@zixia.net
# Date: 2004-07-29

package AKA::Mail::User;

use strict;

use AKA::Mail::DB;

sub new
{
	my $class = shift;
	my $self = {};
	bless $self, $class;

	my $parent = shift;

	$self->{parent} = $parent;
	$self->{zlog} = $parent->{zlog};
	$self->{conf} = $parent->{conf};
	
	$self->{db} = new AKA::Mail::DB;

	return $self;
}

sub is_user_exist($$)
{
	my $self = shift;
	my $email = shift;
	
	return 1;
	return $self->{db}->user_email_exist( $email );
}

1;
