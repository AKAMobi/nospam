#
# �ʼ����������ܹ�
# Company: AKA Information & Technology Co., Ltd.
# Author: Ed Lee
# EMail: zixia@zixia.net
# Date: 2004-03-07


package AKA::Mail;


use AKA::Mail::Conf;
use AKA::Mail::Log;
use AKA::Mail::Spam;
use AKA::Mail::Dynamic;
use AKA::Mail::Police;

sub new
{
	my $class = shift;

	my $self = {};

	bless $self, $class;

	my $parent = shift;

	$self->{conf} = new AKA::Mail::Conf;
	$self->{zlog} = new AKA::Mail::Log;
	$self->{spam} = new AKA::Mail::Spam;
	$self->{dynamic} = new AKA::Mail::Dynamic;
	$self->{police} = new AKA::Mail::Police;

	return $self;

}

# return ( spam_level, reason );
sub spam_engine
{
	my $self = shift;

	my ( $client_smtp_ip, $returnpath ) = @_;

	if ( ! $client_smtp_ip || ! $returnpath ){
		$self->{zlog}->debug ( "Mail::spam_engine can't get param: " . join ( ",", @_ ) );
		return (0, "�����������������" );
	}

	if ( 'Y' ne uc $self->{conf}->{config}->{NoSPAMEngine} ){
		return (0, "����������δ����" );
	}

	my ( $is_spam, $reason ) = $self->{spam}->spam_checker( $client_smtp_ip, $returnpath );

	return ( $is_spam, $reason );
}

# return ( is_over_quota, reason );
sub dynamic_engine
{
	my $self = shift;

	my ( $subject, $mailfrom ) = @_;

	if ( ! $subject || ! $mailfrom ){
		$self->{zlog}->debug ( "Mail::dynamic_engine can't get param: " . join ( ",", @_ ) );
		return (0, "��̬���������������" );
	}

	if ( $self->{dynamic}->is_overrun_rate_per_mailfrom( $mailfrom ) ){
		return ( 1, "�ظ��û������ʼ�����" );
	}

	if ( $self->{dynamic}->is_overrun_rate_per_subject( $subject ) ){
		return ( 1, "�ظ��ʼ�����Ƶ�ʳ���" );
	}

	return ( 0, "��ͨ����̬���" );

}

# return ( action, param );
sub content_engine
{
	my $self = shift;

	my $input_fd = shift;

	return $self->{police}->get_action( <$input_fd> );
}


1;



