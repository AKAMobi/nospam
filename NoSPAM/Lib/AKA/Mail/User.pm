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

# 参数可以是 emails 的数组，因为引擎又可能处理的是发给多人的邮件
sub is_user_exist
{
	my $self = shift;
	my @emails = @_;
	
	my $q_users = undef;
	foreach ( @emails ){
		if ( $self->{db}->user_email_exist( $_ ) ){
			$q_users->{$_} = 1;
		}
	}
	return $q_users;
}

1;
