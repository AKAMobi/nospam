#
# 反垃圾判断核心引擎
# Company: AKA Information & Technology Co., Ltd.
# Author: Ed Lee
# EMail: zixia@zixia.net
# Date: 2004-02-29


package AKA::Mail::Spam;
use AKA::Mail::Conf;
use AKA::Mail::Log;
use AKA::IPUtil;

use Net::DNS;
use Time::HiRes qw( usleep ualarm gettimeofday tv_interval );

sub new
{
	my $class = shift;

	my $self = {};
	bless $self, $class;

	my $parent = shift;

	$self->{parent} = $parent;
	$self->{conf} = $parent->{conf} || new AKA::Mail::Conf;#die "Mail::Conf can't get parent conf!"; 
	$self->{zlog} = $parent->{zlog} || new AKA::Mail::Log;#die "Mail::Conf can't get parent zlog!"; 
	$self->{iputil} = $parent->{iputil} || new AKA::IPUtil;
	# added by zxiia 2004-05-01 init dns when startup
	$self->get_dns_resolver;
	return $self;
}

#sub test_spam
#{
#	my ( $self, $fromaddr, $fromip ) = @_;
#}

# cache dns resolver;
sub get_dns_resolver
{
	my $self = shift;

	return $self->{resolver} if ( $self->{resolver} );

	$self->{resolver} = Net::DNS::Resolver->new;
	
	return $self->{resolver};
}

# 
# 检查可追查性
# return ( 0=un-traceable, 1=traceable, 2=strict_traceable )
#
sub is_traceable
{
	my ( $self, $smtp_ip, $from_domain ) = @_;

	if ( ! defined $smtp_ip || !length($smtp_ip) || !defined $from_domain || !length($from_domain) ){
		$self->{zlog}->fatal( "Spam::is_traceable can't get enough params: [$smtp_ip] [$from_domain]" );
		return 0;
	}

	if ( ! $smtp_ip || ! $from_domain ){
		$self->{zlog}->fatal ( "Spam::is_traceable can't get smtp_ip & domain info." );
		return 0;
	}
	#$self->{zlog}->debug ( "Spam::is_traceable smtp ip: $smtp_ip from_domain $from_domain");
	
	my $res = $self->get_dns_resolver;
	if ( ! $res ){
		$self->{zlog}->debug ( "Spam::is_traceable can't get Resolver $!, we new one" );
		undef $self->{resolver};
		$res = $self->get_dns_resolver;
		if ( ! $res ){
			$self->{zlog}->fatal ( "Spam::is_traceable can't new Resolver $!" );
			return 0;
		}
	}

	my @TraceType = @{$self->{conf}->{config}->{SpamEngine}->{TraceType}};

	my (@mx_n_a, @ptr_domain) ;
	
	my $start_time = [gettimeofday];


	my ($old_alarm_sig,$old_alarm);

	my $TIMEOUT=30;
	eval {
#$self->{zlog}->debug ( "Mail::Spam::is_traceable in eval " . join(',',@TraceType) );
		$old_alarm_sig = $SIG{ALRM};
		local $SIG{ALRM} = sub { die "DNS DIE" };
		$old_alarm = alarm $TIMEOUT;

		if ( grep(/^Mail$/i,@TraceType) ){
#$self->{zlog}->debug ( "Mail::Spam::is_traceable in Mail" );
			push ( @mx_n_a, $self->get_mx_from_domain( $from_domain, $res ) );
		}

		if ( grep(/^IP$/i,@TraceType) ){
#$self->{zlog}->debug ( "Mail::Spam::is_traceable in IP" );
			push ( @mx_n_a, $self->get_a_from_domain( $from_domain, $res ) );
		}

		if ( grep(/^Domain$/i,@TraceType) ){
#$self->{zlog}->debug ( "Mail::Spam::is_traceable in Domain" );
			push ( @ptr_domain, $self->get_ptr_from_ip( $smtp_ip, $res ) );
		}

	};
	my $alarm_status=$@;
	$SIG{ALRM} = $old_alarm_sig || 'IGNORE';
	alarm $old_alarm;
	
	$self->{dns_query_time} = int(1000*tv_interval ( $start_time, [gettimeofday] ));

	if ($alarm_status and $alarm_status ne "" ) { 
		unless ( $mx_n_a[0] ){
			$self->{zlog}->fatal ( "Spam::get_X_from_domain($from_domain,$res) execeed timeout [$TIMEOUT], we got none from dns, DNS err? treat mail is not spam." );
#			如果 DNS 超时，我们应该判断邮件为正常邮件
			return 2;
		}
		$self->{zlog}->fatal ( "Spam::get_X_from_domain($from_domain,$res) execeed timeout [$TIMEOUT], but we got something [$mx_n_a[0]] from DNS." );
	}


	# TODO: add HAND support

	#$self->{zlog}->debug ( "Spam::is_traceable mx & a list: " . join( ",", @mx_n_a) . " TraceType; " . join(',',@TraceType) );

	#my $client_net;
	#$client_net = &ip_to_net_compare( $smtp_ip );
	#$self->{zlog}->debug ( "AKA-Spam smtp net: " . $client_net );

	my $traceable = 0;
	my $strict_traceable = 0;

	my $traceable_mask = $self->{conf}->{config}->{SpamEngine}->{TraceSpamMask} || 24;
	my $strict_traceable_mask = $self->{conf}->{config}->{SpamEngine}->{TraceMaybeSpamMask} || 22;

	foreach my $mx_a_ip ( @mx_n_a ){
#$self->{zlog}->debug ( "Mail::Spam::is_traceable check if $mx_a_ip is traceable for domain $from_domain ?" );
		if ( $traceable && $strict_traceable ){
			last;
		}

		# 检查反向DNS PTR是不是指向邮件发送域
		if ( !$strict_traceable ){
			foreach ( @ptr_domain ){
				if ( /$from_domain/ ){
$self->{zlog}->debug ( "Mail::Spam::is_traceable $smtp_ip ptr $_ include $from_domain" );
					$strict_traceable = 1;
					$traceable = 1;
					last;
				} 
			}
		}

		if ( !$strict_traceable ){
			if ( $self->{iputil}->is_ip_in_range($mx_a_ip,"$smtp_ip/$strict_traceable_mask") ){
				#$self->{zlog}->debug ( "Mail::Spam::is_traceable $smtp_ip is strict traceable at $mx_a_ip of $from_domain, mask $strict_traceable_mask" );
				$strict_traceable = 1;
				$traceable = 1;
				last;
			} 
		}

		if ( !$traceable ){
			if ( $self->{iputil}->is_ip_in_range($mx_a_ip,"$smtp_ip/$traceable_mask") ){
				#$self->{zlog}->debug ( "Mail::Spam::is_traceable $smtp_ip is traceable at $mx_a_ip of $from_domain, mask $traceable_mask" );
				$traceable = 1;
			} 
		}
	}
	
	if ( $strict_traceable ){
		return 2;
	}elsif ( $traceable ){
		return 1;
	}

	# un-traceable
	return 0;
}

sub get_a_from_domain
{
	my ( $self, $domain, $res ) = @_;

	my @As;

	my $query = $res->search( $domain );

#$self->{zlog}->debug ( "Mail::Spam::get_a_from_domain $query" );
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

sub get_ptr_from_ip
{
	my ( $self, $ip, $res ) = @_;

	my @PTRs;

        my $query = $res->query($ip, "PTR");

	if ($query) {
		foreach my $rr (grep { $_->type eq 'PTR' } $query->answer) {
$self->{zlog}->debug ("Spam get ptr of $ip : " . $rr->ptrdname);
			push (@PTRs, $rr->ptrdname);
		}
	} else {
		@PTRs = ();
	}

	return @PTRs;
}

sub get_mx_from_domain
{
	my ( $self, $domain, $res ) = @_;

	my @MXs;

	my @mx_r   = mx($res, $domain);

	if (@mx_r) {
		foreach my $rr (@mx_r) {
#print "mx " . $rr->preference, " ", $rr->exchange, "\n";
			push ( @MXs, $self->get_a_from_domain( $rr->exchange, $res ) );
		}
	} else {
		@MXs = ();
	}

	# AKA traceable mx data center:
	# for those mx ip not in DNS mx list, we put it into our dns database:
	# for example: 211.151.91.27 is not in zixia.net mx list, so we 
	#	put it into dns: zixia.net.mx.conf.nospam.aka.cn
	my @aka_As = $self->get_a_from_domain( "$domain.mx.conf.nospam.aka.cn", $res );
	push ( @MXs, @aka_As ) if ( @aka_As );
#print STDERR "check $domain.mx.conf.nospam.aka.cn $res @aka_As\n";
	
	return @MXs;
}


sub is_black_ip
{
	my ($self,$ip) = @_;

	return 0 if ( 'Y' ne uc $self->{conf}->{config}->{SpamEngine}->{BlockIP} );

	my $BlackIPList = $self->{conf}->{config}->{SpamEngine}->{BlackIPList};

	my $found = 0;
	if ( defined $BlackIPList ){
		foreach ( @{$BlackIPList} ){
			#$self->{zlog}->debug ( "Mail::Spam::is_black_ip $ip in $_?" );
			if ( $self->{iputil}->is_ip_in_range($ip,"$_") ){
				$found = 1;
			#	$self->{zlog}->debug ( "Mail::Spam::is_black_ip $ip in $_!" );
				last;
			}
		}
	}

	return $found;
}

sub is_white_ip
{
	my ($self,$ip) = @_;

	return 0 if ( 'Y' ne uc $self->{conf}->{config}->{SpamEngine}->{BlockIP} );

	my $WhiteIPList = $self->{conf}->{config}->{SpamEngine}->{WhiteIPList};

	my $found = 0;
	if ( defined $WhiteIPList ){
		foreach ( @{$WhiteIPList} ){
			#$self->{zlog}->debug ( "Mail::Spam::is_white_ip $ip in $_?" );
			if ( $self->{iputil}->is_ip_in_range($ip,"$_") ){
				$found = 1;
				#$self->{zlog}->debug ( "Mail::Spam::is_white_ip $ip in $_!" );
				last;
			}
		}
	}

	return $found;
}
sub is_black_domain
{
	my ($self,$domain) = @_;

	return 0 if ( 'Y' ne uc $self->{conf}->{config}->{SpamEngine}->{BlockDomain} );

	my $BlackDomainList = $self->{conf}->{config}->{SpamEngine}->{BlackDomainList};

	my $found = 0;
	if ( defined $BlackDomainList ){
		foreach ( @{$BlackDomainList} ){
			#$self->{zlog}->debug ( "Mail::Spam::is_black_domain $domain in $_?" );
			if ( $domain=~/$_$/ ){
				$found = 1;
				#$self->{zlog}->debug ( "Mail::Spam::is_black_domain $domain in $_!" );
				last;
			}
		}
	}

	return $found;

}
sub is_white_domain
{
	my ($self,$domain) = @_;

	return 0 if ( 'Y' ne uc $self->{conf}->{config}->{SpamEngine}->{BlockDomain} );

	my $WhiteDomainList = $self->{conf}->{config}->{SpamEngine}->{WhiteDomainList};

	my $found = 0;
	if ( defined $WhiteDomainList ){
		foreach ( @{$WhiteDomainList} ){
			#$self->{zlog}->debug ( "Mail::Spam::is_white_domain $domain in $_?" );
			if ( $domain=~/$_$/ ){
				$found = 1;
				#$self->{zlog}->debug ( "Mail::Spam::is_white_domain $domain in $_!" );
				last;
			}
		}
	}

	return $found;


}

sub is_white_addr
{
	my ($self,$addr) = @_;

	return 0 if ( 'Y' ne uc $self->{conf}->{config}->{SpamEngine}->{BlockFrom} );

	my $WhiteFromList = $self->{conf}->{config}->{SpamEngine}->{WhiteFromList};

	my $found = 0;
	if ( defined $WhiteFromList ){
		foreach ( @{$WhiteFromList} ){
			#$self->{zlog}->debug ( "Mail::Spam::is_white_addr $addr in $_?" );
			if ( $addr=~/^$_$/ ){
				$found = 1;
				#$self->{zlog}->debug ( "Mail::Spam::is_white_addr $addr in $_!" );
				last;
			}
		}
	}
	return $found;
}



sub is_black_addr
{
	my ($self,$addr) = @_;

	return 0 if ( 'Y' ne uc $self->{conf}->{config}->{SpamEngine}->{BlockFrom} );

	my $BlackFromList = $self->{conf}->{config}->{SpamEngine}->{BlackFromList};

	my $found = 0;
	if ( defined $BlackFromList ){
		foreach ( @{$BlackFromList} ){
			#$self->{zlog}->debug ( "Mail::Spam::is_black_addr $addr in $_?" );
			if ( $addr=~/^$_$/ ){
				$found = 1;
				#$self->{zlog}->debug ( "Mail::Spam::is_black_addr $addr in $_!" );
				last;
			}
		}
	}
	return $found;
}


###################################3
#
# 检测SPAM入口，
#	参数 ( smtp_ip, from_addr )
#	返回 ( is_spam, reason )
#		is_spam: 0: NOT spam
#			 1: Maybe Spam
#			 2: SPAM
#			 3: Black List
#
sub spam_checker
{
	my ( $self, $smtp_ip, $from_addr ) = @_;

	my $email_domain;

	my ( $is_spam, $reason );

	if ( $from_addr=~/\@(\S+)/ ){
		$email_domain = $1;
	}else{
		#$self->{zlog}->debug ( "Spam::spam_checker can't get email_domain from [$from_addr]." );
		return (0, __("bounced mail"));
	}

	# 0: 非垃圾 
	# 1: 疑似垃圾
	# 2: 垃圾
	# 3: 黑名单
	$is_spam = 0;


	if ( &is_white_ip($self,$smtp_ip) ){
		$reason = __("IP White List");
		$is_spam = 0;
	}elsif ( &is_white_domain($self,$email_domain) ){
		$reason = __("Domain White List");
		$is_spam = 0;
	}elsif ( &is_white_addr( $self,$from_addr ) ){
		$reason = __("Sender White List");
		$is_spam = 0;
	}elsif ( &is_black_ip($self,$smtp_ip) ){
		$reason = __("IP Black List");
		$is_spam = 3;
	}elsif ( &is_black_domain($self,$email_domain) ) {
		$reason = __("Domain Black List");
		$is_spam = 3;
	}elsif ( &is_black_addr($self,$from_addr) ){
		$is_spam = 3;
		$reason = __("Sender Black List");
	}elsif ( 'Y' eq uc $self->{conf}->{config}->{SpamEngine}->{Traceable} ){
		# 只有启用了可追查性检查时才判断
#use Time::HiRes qw( usleep ualarm gettimeofday tv_interval );
#my $start_time = [gettimeofday];
		my $traceable = &is_traceable( $self, $smtp_ip, $email_domain );
#my $elapsed_time = int(1000*tv_interval ( $start_time, [gettimeofday]));
#$self->{zlog}->debug("is_traceable run $elapsed_time");

		# strict_traceable:2 = NOT spam:0
		# traceable:1 = maybe spam:1
		# un-traceable:0 = SPAM:2
		$is_spam = 2-$traceable;
		$reason = __("Traceable check");
	}else{
		$reason = __("OFF");
	}

	
	#$self->{zlog}->debug ( "Spam::spam_checker checking $smtp_ip <=> $from_addr spam result [$is_spam because $reason]" );

	return ($is_spam, $reason, $self->{dns_query_time});
}


1;



