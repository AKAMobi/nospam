#
# 反垃圾判断核心引擎
# Company: AKA Information & Technology Co., Ltd.
# Author: Ed Lee
# EMail: zixia@zixia.net
# Date: 2004-02-29


package AKA::Mail::Spam;
use AKA::Mail::Conf;


sub new
{
	my $class = shift;

	my $self = {};
	bless $self, $class;

	my $parent = shift;

	$self->{parent} = $parent;
	$self->{conf} = $parent->{conf}; || die "Mail::Conf can't get parent conf!"; #new AKA::Mail::Conf;
	$self->{zlog} = $parent->{zlog}; || die "Mail::Conf can't get parent zlog!"; #new AKA::Mail::Conf;

	return $self;
}

sub test_spam
{
	my ( $self, $fromaddr, $fromip ) = @_;
	# TODO: finish it
}

# return ( traceable, strict_traceable )
# ie:
#	( 1,1 ) means it is spam,
#	( 0,1 ) mean it maybe spam.
sub is_traceable
{
	my ( $self, $smtp_ip, $from_addr ) = @_;

	if ( ! defined $smtp_ip || !length($smtp_ip) || !defined $from_addr || !length($from_addr) ){
		$self->{zlog}->debug( "Spam::is_traceable can't get enough params: [$smtp_ip] [$from_addr]" );
		return (0,0);
	}

	my $from_domain ;

	if ( $from_addr=~ /\@(\S+)/ ){
		$from_domain = $1;
	}else{
		$self->{zlog}->debug ( "Spam::is_traceable can't get email_domain from [$from_addr]." );
		return (0,0);
	}

	return &check_traceable( $self, $smtp_ip, $email_domain );
}

sub check_traceable
{
	my ( $self, $client_ip, $domain ) = @_;

	if ( ! $client_ip || ! $domain ){
		$self->{zlog}->fatal ( "Spam::check_traceable can't get client_ip & domain info." );
		return 0;
	}
	$self->{zlog}->debug ( "Spam::check_traceable smtp ip: $client_ip domain: $domain");
	
	use Net::DNS;
	my $res = Net::DNS::Resolver->new;
	if ( ! $res ){
		$self->{zlog}->fatal ( "Spam::check_traceable can't new Resolver $!" );
		return 0;
	}

	my @TraceType = $self->{conf}->{config}->{TraceType};

	my @mx_n_a ;
	
	if ( grep(/^MX$/i,@TraceType) ){
		push ( @mx_n_a, &get_mx_from_domain( $domain, $res ) );
	}

	if ( grep(/^A$/i,@TraceType) ){
		push ( @mx_n_a, &get_a_from_domain( $domain, $res ) );
	}

	# TODO: add HAND support

	$self->{zlog}->debug ( "Spam::check_traceable mx & a list: " . join( ",", @mx_n_a) . " TraceType; " . join(',',@TraceType) );

	my $client_net;
	$client_net = &ip_to_net_compare( $client_ip );
	$self->{zlog}->debug ( "AKA-Spam smtp net: " . $client_net );

	my $traceable = 0;
	my $strict_traceable = 0;

	my $traceable_mask = $self->{conf}->{config}->{TraceSpamMask};
	my $strict_traceable_mask = $self->{conf}->{config}->{TraceMaybeSpamMask};

	foreach my $mx_a_ip ( @mx_n_a ){
		$self->{zlog}->debug ( "Mail::Spam::check_traceable check if $mx_a_ip in $client_net" );
		&ip_to_net_compare ( $mx_a_ip );
		if ( $traceable && $strict_traceable ){
			last;
		}
		if ( $client_net eq $mx_a_net ){
			&debug ( "AKA-Spam found $mx_a_ip is in $client_net !" );
			$check_match = 1;
			last;
		}
	}
	return ($traceable,$strict_traceable);
}

sub get_a_from_domain
{
	my ( $domain, $res ) = @_;

	my @As;

	my $query = $res->search( $domain );

	if ($query) {
		foreach my $rr ($query->answer) {
			next unless $rr->type eq "A";
#print "type: " . $rr->type . " result: " . $rr->address . "\n";
			push ( @As, $rr->address );
		}
	} else {
		@As = ();
	}

	return @As;
}

sub get_mx_from_domain
{
	my ( $domain, $res ) = @_;

	my @MXs;

	my @mx_r   = mx($res, $domain);

	if (@mx_r) {
		foreach my $rr (@mx_r) {
#print "mx " . $rr->preference, " ", $rr->exchange, "\n";
			push ( @MXs, &get_a_from_domain( $rr->exchange, $res ) );
		}
	} else {
		@MXs = ();
	}
	return @MXs;
}

sub ip_to_net_compare
{
	my $ip = shift;

	my ( $d1, $d2, $d3, $d4 );
	if ( $ip =~ /(\d+)\.(\d+)\.(\d+)\.(\d+)/ ){
		($d1,$d2,$d3,$d4) = ($1,$2,$3,$4);
	}else{
		&debug ( "AKA-Spam can't understand ip [$ip]." );
		&error_condition( "IP information temporary unusable. (#4.3.0)" );
	}
	&debug ( "AKA-Spam mxcheck [$AKA_conf_mxcheck]." );

	if ( 0==$AKA_conf_mxcheck ){
   		# mfchk = 0	不检查
		return "";
	} elsif ( 1==$AKA_conf_mxcheck ){
   		# mfchk = 1	检查 A 类
		return $d1 . '.';
	} elsif ( 2==$AKA_conf_mxcheck ){
   		# mfchk = 2	检查 B 类
		return $d1 . '.' . $d2 . '.';
	} elsif ( 3==$AKA_conf_mxcheck ){
   		# mfchk = 3	检查 C 类
		return $d1 . '.' . $d2 . '.' . $d3 . '.';
	} elsif ( 4==$AKA_conf_mxcheck ){
   		# mfchk = 4	精确 IP 匹配
		return $ip;
	}
}


sub AKA_spam_checker
{

	my ( $smtp_ip, $email_domain );


	&debug ("AKA-Spam: entered AKA_spam_checker." );
	# 如果经过身份认证，则 TCPREMOTEINFO 内存的是用户名
	my $TCPREMOTEINFO = $ENV{TCPREMOTEINFO};

	# XXX 
	if ( defined $TCPREMOTEINFO ) {
		&debug ("AKA-Spam: It is a authorized user: " . $TCPREMOTEINFO . ", no need to check." );
		# It should not be SPAM.
		return 0;
	}
	
  	my ($start_akaspam_time)=[gettimeofday];

	# load conf file
	&AKA_conf_init();

	$smtp_ip = $remote_smtp_ip;
	if ( ! $smtp_ip ){
		&debug ( "AKA-Spam can't get remote_smtp_ip." );
		&error_condition( "IP information temporary unusable. (#4.3.0)" );
	}
	
	# allow localhost free relay
	return 0 if $smtp_ip eq '127.0.0.1';

	$email_domain = $returnpath;
	if ( ! $email_domain || !length($email_domain) || (! $email_domain=~/\@/) ){
		$email_domain = $headers{'from'};
		&debug ( "AKA-Spam get email_domain from headers{from}=[$email_domain]." );
		if ( ! $email_domain ){
			&debug ( "AKA-Spam can't get returnpath from email_domain, assume it is SPAM!!" );
			return 1;
			#&error_condition( "Address information temporary unusable. (#4.3.0)" );
		}
	}

	my $email_address = $email_domain;

	if ( $email_domain=~ /\@(\S+)/ ){
		$email_domain = $1;
	}else{
		&debug ( "AKA-Spam can't get email_domain from [$email_domain]." );
		&error_condition( "Domain information temporary unusable. (#4.3.0)" );
	}

	my $is_spam = 0;

	if ( ! &is_white_ip($smtp_ip) && ! &is_white_domain($email_domain) ){
		if ( &is_black_ip($smtp_ip) || 
				&is_black_domain($email_domain) ||
				&is_black_addr($email_address) ){
			$is_spam = 1;
			&debug ( "AKA-Spam: $smtp_ip or $email_domain or $email_address is in black list." );
		}elsif ( ! &check_mx_a_match( $smtp_ip, $email_domain ) ){
			# dns information NOT match, it is SPAM!!!!
			$is_spam = 1;
		}
	}else{
		&debug ( "AKA-Spam: $smtp_ip is white ip or $email_domain is white domain." );
	}

  	if ( $is_spam ){
		&debug("AKA-Spam: It is a SPAM!!!");
	}else{
		&debug("AKA-Spam: It is NOT a spam.");
	}

  	my $stop_akaspam_time=[gettimeofday];
  	my $akaspam_time = tv_interval ($start_akaspam_time, $stop_akaspam_time);
  	&debug("AKA-Spam: finished in $akaspam_time secs");

	#  在没有 smtp-auth 的情况下，STDERR 的信息传不到 remote_smtp 上？
	# 需要 qmail-smtpd 打补丁
	if ( $is_spam && $AKA_conf_mxcheckrefuse ){
		&error_condition ( "553 sorry, your envelope sender domain must exist(#5.7.1)", 32 );
		exit ( 32 );
	}

	return $is_spam;
}

sub AKA_conf_init
{

	if ( open ( FD, "</var/qmail/control/mfcheck" ) ) {
		$AKA_conf_mxcheck = <FD>;
		chomp $AKA_conf_mxcheck;
		close FD;

		if ( ! defined $AKA_conf_mxcheck || $AKA_conf_mxcheck < 0 || $AKA_conf_mxcheck > 4 ){
			&debug ( "AKA-Spam unleague value mxcheck: " . $AKA_conf_mxcheck . ", resetting...");
			$AKA_conf_mxcheck = 0;
		}
	}else{
		$AKA_conf_mxcheck = 0;
	}

	if ( open ( FD, "</var/qmail/control/mxcheckrefuse" ) ) {
		$AKA_conf_mxcheckrefuse = <FD>;
		chomp $AKA_conf_mxcheckrefuse;
		close FD;

		if ( ! defined $AKA_conf_mxcheckrefuse || $AKA_conf_mxcheckrefuse < 0 || $AKA_conf_mxcheckrefuse > 1 ){
			$AKA_conf_mxcheckrefuse = 0;
		}
	}else{
		&debug ( "AKA-Spam can't open /var/qmail/control/mxcheckrefuse file" );
		$AKA_conf_mxcheckrefuse = 0;
	}

}

sub is_black_ip
{
	my $ip = shift;
	my $black_ip_file = "/var/qmail/control/black_ip";

	my $found = 0;
	if ( open( FD, "<$black_ip_file" ) ){
		while ( <FD> ){
			chomp;
			if ( $ip=~/^$_/ ){
				$found = 1;
				last;
			}
		}
		close ( FD );
	}

	return $found;
}
sub is_white_ip
{
	my $ip = shift;
	my $white_ip_file = "/var/qmail/control/white_ip";

	my $found = 0;
	if ( open( FD, "<$white_ip_file" ) ){
		while ( <FD> ){
			chomp;
			if ( $ip =~ /^$_/ ){
				$found = 1;
				last;
			}
		}
		close ( FD );
	}

	return $found;
}
sub is_black_domain
{
	my $domain = shift;
	my $black_domain_file = "/var/qmail/control/badmailfrom";

	my $found = 0;
	if ( open( FD, "<$black_domain_file" ) ){
		while ( <FD> ){
			chomp;
			if ( $domain=~/$_$/ ){
				$found = 1;
				last;
			}
		}
		close ( FD );
	}

	return $found;

}
sub is_white_domain
{
	my $domain = shift;
	my $white_domain_file = "/var/qmail/control/goodmailfrom";
	
	my $found = 0;
	if ( open( FD, "<$white_domain_file" ) ){
		while ( <FD> ){
			chomp;
			if ( $domain=~/$_$/ ){
				$found = 1;
				last;
			}
		}
		close ( FD );
	}

	return $found;


}
sub is_black_addr
{
	my $addr = shift;
	my $black_addr_file = "/var/qmail/control/black_addr";

	my $found = 0;
	if ( open( FD, "<$black_addr_file" ) ){
		while ( <FD> ){
			chomp;
			if ( $addr=~/^$_$/ ){
				$found = 1;
				last;
			}
		}
		close ( FD );
	}

	return $found;

}


1;



