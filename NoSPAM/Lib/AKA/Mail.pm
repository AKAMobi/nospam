#
# 邮件网关引擎总管
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
use AKA::License;

sub new
{
	my $class = shift;

	my $self = {};

	bless $self, $class;

	my $parent = shift;

	$self->{license} = new AKA::License;

	$self->{conf} = new AKA::Mail::Conf;
	$self->{zlog} = new AKA::Mail::Log;
	$self->{spam} = new AKA::Mail::Spam;
	$self->{dynamic} = new AKA::Mail::Dynamic;
	$self->{police} = new AKA::Mail::Police;

	return $self;

}

sub should_refuse_spam
{
	my $self = shift;

	return ( 'Y' eq $self->{conf}->{config}->{RefuseSpam} );
}

# return ( spam_level, reason );
sub spam_engine
{
	my $self = shift;

	my ( $client_smtp_ip, $returnpath ) = @_;

	if ( ! $client_smtp_ip || ! $returnpath ){
		$self->{zlog}->debug ( "Mail::spam_engine can't get param: " . join ( ",", @_ ) );
		return (0, "反垃圾引擎参数不足" );
	}

	if ( 'Y' ne uc $self->{conf}->{config}->{NoSPAMEngine} ){
		return (0, "反垃圾引擎未启动" );
	}

	my ( $is_spam, $reason ) = $self->{spam}->spam_checker( $client_smtp_ip, $returnpath );

	return ( $is_spam, $reason );
}

# input: (subject, mailfrom)
# return ( is_over_quota, reason );
sub dynamic_engine
{
	my $self = shift;

	my ( $subject, $mailfrom, $ip ) = @_;

	my ( $is_overrun, $reason );

	if ( 'Y' ne uc $self->{conf}->{config}->{DynamicEngine} ){
		return (0, "动态限制引擎未启动" );
	}


	if ( ! $subject || ! $mailfrom || ! $ip ){
		$self->{zlog}->debug ( "Mail::dynamic_engine can't get param: " . join ( ",", @_ ) );
		# we should check what we can check.

		($is_overrun,$reason) = (0, "动态限制引擎参数不足" );
	}

	if ( $mailfrom && $self->{dynamic}->is_overrun_rate_per_mailfrom( $mailfrom ) ){
		return ( 1, "用户发送邮件频率超限" );
	}

	if ( $subject && $self->{dynamic}->is_overrun_rate_per_subject( $subject ) ){
		return ( 1, "重复邮件发送频率超限" );
	}

	if ( $ip && $self->{dynamic}->is_overrun_rate_per_ip( $ip ) ){
		return ( 1, "IP发送频率超限" );
	}

	$is_overrun ||= 0;
	$reason ||="已通过动态监测";

	return ( $is_overrun, $reason );
}

sub content_engine_is_enabled
{	
	my $self = shift;

	if ( 'Y' eq uc $self->{conf}->{config}->{ContentFilterEngine} ){
		return 1;
	}
	return 0;
}

# input: in_fd, out_fd
# output ( action, param );
sub content_engine_fd
{
	my $self = shift;

	my ($input_fd,$output_fd) = @_;

	($action,$param) = $self->{police}->get_action( $input_fd );

	print $output_fd "X-Police-Status: $action:($param) OK\n";

	$self->{police}->print($action, $output_fd);

	$self->{police}->clean;
}

# input : in_fd
# output ( action, param, rule_id, mime_data );
sub content_engine_mime
{
	my $self = shift;

	my $input_fd = shift;

	my ($action,$param,$ruleid) = $self->{police}->get_action( $input_fd );

	#print "X-Police-Status: $action:($param) OK\n";
	
        if ( $action == 1 || $action == 2 || $action == 3 ){
		return ( $action,$param, $ruleid, "" );
	}

	my $mime_data = $self->{police}->{filter}->{parser}->{entity}->stringify;
	#my $subject = $self->{police}->{filter}->{parser}->{mail_info}->{head}->{subject};

	$self->{police}->clean;

	return ( $action,$param, $ruleid, $mime_data );
}

sub get_spam_tag_params
{
	my $self = shift;

	my ( $SpamTag, $MaybeSpamTag, $TagHead, $TagSubject, $TagReason ) ;

	$SpamTag = $self->{conf}->{config}->{SpamTag};
	$MaybeSpamTag = $self->{conf}->{config}->{MaybeSpamTag};
	$TagHead = $self->{conf}->{config}->{TagHead};
	$TagSubject = $self->{conf}->{config}->{TagSubject};
	$TagReason = $self->{conf}->{config}->{TagReason};

	return ( $TagHead, $TagSubject, $TagReason, $SpamTag, $MaybeSpamTag );
}


# move check license to here to prevent hacker
sub check_license_file
{
	my $self = shift;

	my $licensefile = $self->{conf}->{define}->{licensefile};

	if ( ! open( LFD, "<$licensefile" ) ){
		#$self->{zlog}->fatal ( "AKA::License::check_license_file can't open [$licensefile]" );
		# No license
		return 0;
	}
	
	my $license_content;
	my $license_data;
	my $license_checksum;
	
	while ( <LFD> ){
		chomp;
		s/[\r\n]$//;
		if ( /^ProductLicenseExt=(.+)$/ ){
			$license_checksum = $1;
			next;
		}elsif ( /^ProductLicense=(.+)$/ ){
			$license_data = $1;
			$license_data =~ s/\s*//g;
		}

		$license_content .= $_ . "\n";
	}
	# trim tail \n
	$license_content =~ s/\n+$//;

	unless ( defined $license_content && defined $license_checksum && 
			length($license_content) && length($license_checksum) ){
		$self->{zlog}->fatal ( "AKA::License::check_license_file can't get enough information from [$licensefile]" );
		return 0;
	}

	my $cmp_str;

	$cmp_str=$self->{license}->get_valid_license($self->{license}->get_prodno) ;

	if ( $cmp_str ne $license_data ){
		#print "license_data $license_data ne $cmpstr\n";
		return 0;
	}
	if( !$self->{license}->is_valid_checksum( $license_content, $license_checksum ) ){
		#print "checksum $license_checksum not valid for [$license_content]\n";
		return 0;
	}
	# it's valid
	return 1;
}


1;

