#
# noSPAM 用户列表接口
# Company: AKA Information & Technology Co., Ltd.
# Author: Ed Li
# EMail: zixia@zixia.net
# Date: 2004-07-29

package AKA::Mail::User;

use strict;

use AKA::Mail::DB;
use AKA::Mail::Conf;

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

		# XXX
		$q_users->{$_} = 1;
		next;
		# XXX

		if ( $self->{db}->user_email_exist( $_ ) ){
			$q_users->{$_} = 1;
		}
	}
	return $q_users;
}

# 检查是否发件人被收件人列入白名单
# 如果有多个收件人，则任何一个收件人将发件人列入白名单即可
# 如果是白名单，返回1，否则返回0；
sub is_user_whitelist($$$)
{
	my $self = shift;
	my $sender_email = shift;
	my @receiver_emails = @_;

	return $self->{db}->is_user_whitelist( AKA::Mail::Conf::WHITE_LIST, $sender_email, @receiver_emails );
}

# 检查是否发件人被收件人列入白名单
# 如果有多个收件人，则任何一个收件人将发件人列入白名单即可
# 如果是白名单，返回1，否则返回0；
sub is_user_blacklist($$$)
{
	my $self = shift;
	my $sender_email = shift;
	my @receiver_emails = @_;

	return $self->{db}->is_user_whitelist( AKA::Mail::Conf::BLACK_LIST, $sender_email, @receiver_emails );
}


1;
