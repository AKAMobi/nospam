#
# noSPAM �û��б�ӿ�
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

# ���������� emails �����飬��Ϊ�����ֿ��ܴ�����Ƿ������˵��ʼ�
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

# ����Ƿ񷢼��˱��ռ������������
# ����ж���ռ��ˣ����κ�һ���ռ��˽��������������������
# ����ǰ�����������1�����򷵻�0��
sub is_user_whitelist($$$)
{
	my $self = shift;
	my $sender_email = shift;
	my @receiver_emails = @_;

	return $self->{db}->is_user_whitelist( AKA::Mail::Conf::WHITE_LIST, $sender_email, @receiver_emails );
}

# ����Ƿ񷢼��˱��ռ������������
# ����ж���ռ��ˣ����κ�һ���ռ��˽��������������������
# ����ǰ�����������1�����򷵻�0��
sub is_user_blacklist($$$)
{
	my $self = shift;
	my $sender_email = shift;
	my @receiver_emails = @_;

	return $self->{db}->is_user_whitelist( AKA::Mail::Conf::BLACK_LIST, $sender_email, @receiver_emails );
}


1;
