#
# 邮件网关引擎总管
# Company: AKA Information & Technology Co., Ltd.
# Author: Ed Lee
# EMail: zixia@zixia.net
# Date: 2004-03-07


package AKA::Mail;

use MIME::Base64; 
use MIME::QuotedPrint; 
use Time::HiRes qw( usleep ualarm gettimeofday tv_interval );

use AKA::License;
use AKA::Mail::Conf;
use AKA::Mail::Log;

use AKA::Mail::AntiVirus;
use AKA::Mail::Spam;
use AKA::Mail::Content;
use AKA::Mail::Dynamic;

use AKA::Mail::Archive;

use constant	{
	RESULT_SPAM_NOT		=>	0,
	RESULT_SPAM_MAYBE	=>	1,
	RESULT_SPAM_MUST	=>	2,
	RESULT_SPAM_BLACK	=>	3,

	ACTION_PASS		=>	0,
	ACTION_REJECT		=>	1,
	ACTION_DISCARD		=>	2,
	ACTION_QUARANTINE	=>	3,
	ACTION_STRIP		=>	4,
	ACTION_DELAY		=>	5,
	ACTION_NULL		=>	6,
	ACTION_ACCEPT		=>	7,
	ACTION_ADDRCPT		=>	8,
	ACTION_DELRCPT		=>	9,
	ACTION_CHGRCPT		=>	10,
	ACTION_ADDHDR		=>	11,
	ACTION_DELHDR		=>	12,
	ACTION_CHGHDR		=>	13
	
};

sub new
{
	my $class = shift;

	my $self = {};

	bless $self, $class;

	my $parent = shift;

	$self->{license} = new AKA::License;

	$self->{conf} = new AKA::Mail::Conf($self);
	$self->{zlog} = new AKA::Mail::Log($self);

	$self->{antivirus} 	= new AKA::Mail::AntiVirus($self);
	$self->{spam} 		= new AKA::Mail::Spam($self);
	$self->{dynamic} 	= new AKA::Mail::Dynamic($self);
	$self->{content} 	= new AKA::Mail::Content($self);
	$self->{archive} 	= new AKA::Mail::Archive($self);

	return $self;

}

sub process
{
	my $self = shift;
	my $mail_info = shift;

	unless ( $mail_info ){
		$self->{zlog}->fatal ( "Mail::process can't get mail_info" );
		return undef;
	}

	$self->{mail_info} = $mail_info;

	# 获取文件尺寸和标题等基本信息
	$self->get_mail_base_info;

	$self->antivirus_engine() 	unless $self->{mail_info}->{aka}->{drop};
	$self->spam_engine() 		unless $self->{mail_info}->{aka}->{drop};
	$self->content_engine()		unless $self->{mail_info}->{aka}->{drop};
	$self->dynamic_engine()		unless $self->{mail_info}->{aka}->{drop};
	

	# Log
	#$self->log_engine();


	# 处理邮件动作
	#$self->do_action();

	# 清理内容引擎内容
	$self->{content}->clean;

	return $self->{mail_info};
}

sub do_action
{
	my $self = shift;

	die "un implement";
	# TODO
}

sub antivirus_engine
{
	my $self = shift;

	$self->{mail_info}->{aka}->{engine}->{antivirus} = 
		$self->{antivirus}->catch_virus( $self->{mail_info}->{aka}->{emlfilename} );

	$self->{mail_info}->{aka}->{drop} = 1 if $self->{mail_info}->{aka}->{engine}->{antivirus}->{action};
}


# return 0 if not archived, otherwise 1;
# input: ( emlfile, is_spam, match_rule );
sub archive_engine
{
	my $self = shift;

	my $emlfile = shift;
	my $is_spam = shift;
	my $is_matchrule = shift;

	if ( 'Y' ne uc $self->{conf}->{config}->{ArchiveEngine}->{ArchiveEngine} ){
		return (0, "审计引擎未启动" );
	}

	return 0 unless ( $is_spam || $is_matchrule );
	return 0 unless ( $emlfile && -f $emlfile );

	$self->{archive} ||= new AKA::Mail::Archive($self);

	return $self->{archive}->archive($emlfile);
}

sub spam_engine
{
	my $self = shift;

	my ( $client_smtp_ip, $returnpath ) = ( $self->{mail_info}->{aka}->{TCPREMOTEIP},
						$self->{mail_info}->{aka}->{returnpath} );

	$self->{mail_info}->{aka}->{engine}->{spam}->{enabled} =  'Y' eq uc $self->{conf}->{config}->{SpamEngine}->{NoSPAMEngine};

	if ( ! $client_smtp_ip || ! $returnpath ){
		$self->{zlog}->debug ( "Mail::spam_engine can't get param: " . join ( ",", @_ ) );

		$self->{mail_info}->{aka}->{engine}->{spam}->{result} = RESULT_SPAM_NOT;
		$self->{mail_info}->{aka}->{engine}->{spam}->{desc} = '反垃圾引擎参数不足';
		$self->{mail_info}->{aka}->{engine}->{spam}->{action} = ACTION_PASS;
		return;
	}

	if ( 'Y' ne uc $self->{conf}->{config}->{SpamEngine}->{NoSPAMEngine} ){
		$self->{mail_info}->{aka}->{engine}->{spam} = {	result	=>RESULT_SPAM_NOT,
							desc	=>'未启动',
							action	=>ACTION_PASS };
		return;
	}

	my ( $is_spam, $reason ) = $self->{spam}->spam_checker( $client_smtp_ip, $returnpath );

	$self->{mail_info}->{aka}->{engine}->{spam}->{result} = $is_spam;
	$self->{mail_info}->{aka}->{engine}->{spam}->{desc} = $reason;
	$self->{mail_info}->{aka}->{engine}->{spam}->{action} = (  ( 'Y' eq $self->{conf}->{config}->{SpamEngine}->{RefuseSpam} 
								   ) && $is_spam
								) ? ACTION_REJECT : ACTION_PASS ;
	
	$self->{mail_info}->{aka}->{drop} = 1 if $self->{mail_info}->{aka}->{engine}->{spam}->{action};

	return;
}

# input: (subject, mailfrom)
# return ( is_over_quota, reason );
sub dynamic_engine
{
	my $self = shift;

        my $start_time=[gettimeofday];

	my ( $subject, $mailfrom, $ip ) = (
		$self->{mail_info}->{aka}->{subject},
		$self->{mail_info}->{aka}->{returnpath},
		$self->{mail_info}->{aka}->{TCPREMOTEIP} 
	);

	my ( $is_overrun, $reason );

	if ( 'Y' ne uc $self->{conf}->{config}->{DynamicEngine}->{DynamicEngine} ){
		$self->{mail_info}->{aka}->{engine}->{dynamic} = {
	               			result  => 0,
	                                desc    => '未启动',
       	                         	action  => 0,
	
                                	enabled => 0,
       	                         	runned  => 1,
                                	runtime => int(1000*tv_interval ($start_time, [gettimeofday]))/1000
			
		};
		return;
	}

	# we check what we has seen
	if ( ! $subject || ! $mailfrom || ! $ip ){
		$self->{zlog}->debug ( "Mail::dynamic_engine can't get param: " . join ( ",", @_ ) );
		# we should check what we can check.

	#	($is_overrun,$reason) = (0, "动态限制引擎参数不足" );
	}

	if ( $mailfrom ){
		($is_overrun,$reason) = $self->{dynamic}->is_overrun_rate_per_mailfrom( $mailfrom );
		if ( $is_overrun ){
			$self->{mail_info}->{aka}->{engine}->{dynamic} = {
	               			result  => $is_overrun,
	                                desc    => '发信人' . $reason,
       	                         	action  => 1,
	
                                	enabled => 1,
       	                         	runned  => 1,
                                	runtime => int(1000*tv_interval ($start_time, [gettimeofday]))/1000
			};
			return ;
		}
	}

	if ( $subject ){
		($is_overrun,$reason) = $self->{dynamic}->is_overrun_rate_per_subject( $subject );
		if ( $is_overrun ){
			$self->{mail_info}->{aka}->{engine}->{dynamic} = {
	               			result  => $is_overrun,
	                                desc    => '邮件' . $reason,
       	                         	action  => 1,
	
                                	enabled => 1,
       	                         	runned  => 1,
                                	runtime => int(1000*tv_interval ($start_time, [gettimeofday]))/1000
			};
			return ;
		}
	}

	if ( $ip ){
		($is_overrun,$reason) = $self->{dynamic}->is_overrun_rate_per_ip( $ip );
		if ( $is_overrun ){
			$self->{mail_info}->{aka}->{engine}->{dynamic} = {
	               			result  => $is_overrun,
	                                desc    => 'IP' . $reason,
       	                         	action  => 1,
	
                                	enabled => 1,
       	                         	runned  => 1,
                                	runtime => int(1000*tv_interval ($start_time, [gettimeofday]))/1000
			};
			return ;
		}
	}

	$self->{mail_info}->{aka}->{engine}->{dynamic} = {
		result  => 0,
		desc    => '通过动态监测',
		action  => 0,

		enabled => 1,
		runned  => 1,
		runtime => int(1000*tv_interval ($start_time, [gettimeofday]))/1000
	};
	return ;
}

sub content_engine
{
	my $self = shift;

	return unless ( $self->content_engine_is_enabled() );

	# content parser get all mail information, and return it.
	$self->{mail_info} = $self->{content}->process( $self->{mail_info} );


	return;
}

sub content_engine_is_enabled
{	
	my $self = shift;
	my $mail_size = shift;


        my $start_time=[gettimeofday];

	if ( 'Y' eq uc $self->{conf}->{config}->{ContentEngine}->{ContentFilterEngine} ){
		if ( $self->{conf}->{intconf}->{ContentEngineMaxMailSize} ){
			return 1 if ( $self->{mail_info}->{aka}->{size} < $self->{conf}->{intconf}->{ContentEngineMaxMailSize} );
			$self->{mail_info}->{aka}->{engine}->{content} = {
                			result  => 0,
	                                desc    => '邮件超过配置最大值',
       	                         	action  => 0,
	
                                	enabled => 1,
       	                         	runned  => 1,
                                	runtime => int(1000*tv_interval ($start_time, [gettimeofday]))/1000
			};
			return 0;
		}
	}

	$self->{mail_info}->{aka}->{engine}->{content} = {
            		result  => 0,
                        desc    => '未启动',
                        action  => 0,

                        enabled => 0,
                        runned  => 1,
                        runtime => int(1000*tv_interval ($start_time, [gettimeofday]))/1000
		};
	
	return 0;
}

# input: in_fd, out_fd
# output ( action, param );
sub content_engine_fd
{
	my $self = shift;

	my ($input_fd,$output_fd) = @_;

	$self->{content} ||= new AKA::Mail::Content;

	($action,$param) = $self->{content}->get_action( $input_fd );

	#print $output_fd "X-Content-Status: $action:($param) OK\n";

	$self->{content}->print($action, $output_fd);

	$self->{content}->clean;
	
	undef $self->{content};
}

# input : in_fd
# output ( action, param, rule_id, mime_data );
sub content_engine_mime
{
	my $self = shift;

	my $input_fd = shift;

	$self->{content} ||= new AKA::Mail::Content;

	my ($action,$param,$ruleid) = $self->{content}->get_action( $input_fd );

        if ( $action == 1 || $action == 2 || $action == 3 ){
		return ( $action,$param, $ruleid, "" );
	}

	my $mime_data = $self->{content}->{filter}->{parser}->{entity}->stringify;
	#my $subject = $self->{content}->{filter}->{parser}->{mail_info}->{head}->{subject};

	$self->{content}->clean;

	undef $self->{content};

	return ( $action,$param, $ruleid, $mime_data );
}

sub get_spam_tag_params
{
	my $self = shift;

	my ( $SpamTag, $MaybeSpamTag, $TagHead, $TagSubject, $TagReason ) ;

	$SpamTag = $self->{conf}->{config}->{SpamEngine}->{SpamTag};
	$MaybeSpamTag = $self->{conf}->{config}->{SpamEngine}->{MaybeSpamTag};
	$TagHead = $self->{conf}->{config}->{SpamEngine}->{TagHead};
	$TagSubject = $self->{conf}->{config}->{SpamEngine}->{TagSubject};
	$TagReason = $self->{conf}->{config}->{SpamEngine}->{TagReason};

	return ( $TagHead, $TagSubject, $TagReason, $SpamTag, $MaybeSpamTag );
}


# move check license to here to prevent hacker
sub check_license_file
{
	my $self = shift;

	my $licensefile = $self->{conf}->{define}->{licensefile};

	my $LicenseHTML;

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
		}elsif ( /^LicenseHTML=(.+)$/ ){
			$LicenseHTML = $1;
		}

		$license_content .= $_;
		$license_content .= "\n";
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
	$LicenseHTML ||= '<h1>许可证有效！</h1>';
	return $LicenseHTML;
}

sub get_mail_base_info
{
	my $self = shift;

	open ( MAIL, '<' . $self->{mail_info}->{aka}->{emlfilename} ) or return undef;

	my $still_headers = 0;
	my $subject;
	while (<MAIL>) {
		if ( $still_headers ){
			if ( /^Subject: ([^\n]+)/i) {
				$subject = $1 || '';
				$subject=~s/[\r\n]*$//g;
				if ($subject=~/^=\?[\w-]+\?B\?(.*)\?=$/) { 
					$subject = decode_base64($1); 
				}elsif ($subject=~/^=\?[\w-]+\?Q\?(.*)\?=$/) { 
					$subject = decode_qp($1); 
				}
			}
			$still_headers = 0 if (/^(\r|\r\n|\n)$/);
		}
		last unless $still_headers;
	}
	close(MAIL);

	$self->{mail_info}->{aka}->{subject} = $subject;
	$self->{mail_info}->{aka}->{size} = -s $self->{mail_info}->{aka}->{emlfilename};
}

1;

