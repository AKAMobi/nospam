#
# 反垃圾判断核心引擎
# Company: AKA Information & Technology Co., Ltd.
# Author: Ed Lee
# EMail: zixia@zixia.net
# Date: 2004-02-29


package AKA::Mail::Spam;
use AKA::Mail::Conf;
use AKA::IPUtil;

use Net::DNS;

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
	return $self;
}

sub test_spam
{
	my ( $self, $fromaddr, $fromip ) = @_;
	# TODO: finish it
}

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
	$self->{zlog}->debug ( "Spam::is_traceable smtp ip: $smtp_ip from_domain $from_domain");
	
	my $res = $self->get_dns_resolver;
	if ( ! $res ){
		$self->{zlog}->fatal ( "Spam::is_traceable can't new Resolver $!" );
		return 0;
	}

	my @TraceType = @{$self->{conf}->{config}->{TraceType}};

	my @mx_n_a ;
	
	if ( grep(/^MX$/i,@TraceType) ){
		push ( @mx_n_a, $self->get_mx_from_domain( $from_domain, $res ) );
	}

	if ( grep(/^A$/i,@TraceType) ){
		push ( @mx_n_a, $self->get_a_from_domain( $from_domain, $res ) );
	}

	# TODO: add HAND support

	$self->{zlog}->debug ( "Spam::is_traceable mx & a list: " . join( ",", @mx_n_a) . " TraceType; " . join(',',@TraceType) );

	#my $client_net;
	#$client_net = &ip_to_net_compare( $smtp_ip );
	#$self->{zlog}->debug ( "AKA-Spam smtp net: " . $client_net );

	my $traceable = 0;
	my $strict_traceable = 0;

	my $traceable_mask = $self->{conf}->{config}->{TraceSpamMask};
	my $strict_traceable_mask = $self->{conf}->{config}->{TraceMaybeSpamMask};

	foreach my $mx_a_ip ( @mx_n_a ){
		$self->{zlog}->debug ( "Mail::Spam::is_traceable check if $mx_a_ip is traceable for domain $from_domain ?" );

		#&ip_to_net_compare ( $mx_a_ip );

		if ( $traceable && $strict_traceable ){
			last;
		}

		if ( !$strict_traceable ){
			if ( $self->{iputil}->is_ip_in_range($mx_a_ip,"$smtp_ip/$strict_traceable_mask") ){
				$self->{zlog}->debug ( "Mail::Spam::is_traceable $smtp_ip is strict traceable at $mx_a_ip of $from_domain, mask $strict_traceable_mask" );
				$strict_traceable = 1;
				$traceable = 1;
				last;
			} 
		}

		if ( !$traceable ){
			if ( $self->{iputil}->is_ip_in_range($mx_a_ip,"$smtp_ip/$traceable_mask") ){
				$self->{zlog}->debug ( "Mail::Spam::is_traceable $smtp_ip is traceable at $mx_a_ip of $from_domain, mask $traceable_mask" );
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
	return @MXs;
}


sub is_black_ip
{
	my ($self,$ip) = @_;

	return 0 if ( 'Y' ne uc $self->{conf}->{config}->{BlockIP} );

	my $BlackIPList = $self->{conf}->{config}->{BlackIPList};

	my $found = 0;
	if ( defined $BlackIPList ){
		foreach ( @{$BlackIPList} ){
			$self->{zlog}->debug ( "Mail::Spam::is_black_ip $ip in $_?" );
			if ( $self->{iputil}->is_ip_in_range($ip,"$_") ){
				$found = 1;
				$self->{zlog}->debug ( "Mail::Spam::is_black_ip $ip in $_!" );
				last;
			}
		}
	}

	return $found;
}

sub is_white_ip
{
	my ($self,$ip) = @_;

	return 0 if ( 'Y' ne uc $self->{conf}->{config}->{BlockIP} );

	my $WhiteIPList = $self->{conf}->{config}->{WhiteIPList};

	my $found = 0;
	if ( defined $WhiteIPList ){
		foreach ( @{$WhiteIPList} ){
			$self->{zlog}->debug ( "Mail::Spam::is_white_ip $ip in $_?" );
			if ( $self->{iputil}->is_ip_in_range($ip,"$_") ){
				$found = 1;
				$self->{zlog}->debug ( "Mail::Spam::is_white_ip $ip in $_!" );
				last;
			}
		}
	}

	return $found;
}
sub is_black_domain
{
	my ($self,$domain) = @_;

	return 0 if ( 'Y' ne uc $self->{conf}->{config}->{BlockDomain} );

	my $BlackDomainList = $self->{conf}->{config}->{BlackDomainList};

	my $found = 0;
	if ( defined $BlackDomainList ){
		foreach ( @{$BlackDomainList} ){
			$self->{zlog}->debug ( "Mail::Spam::is_black_domain $domain in $_?" );
			if ( $domain=~/$_$/ ){
				$found = 1;
				$self->{zlog}->debug ( "Mail::Spam::is_black_domain $domain in $_!" );
				last;
			}
		}
	}

	return $found;

}
sub is_white_domain
{
	my ($self,$domain) = @_;

	return 0 if ( 'Y' ne uc $self->{conf}->{config}->{BlockDomain} );

	my $WhiteDomainList = $self->{conf}->{config}->{WhiteDomainList};

	my $found = 0;
	if ( defined $WhiteDomainList ){
		foreach ( @{$WhiteDomainList} ){
			$self->{zlog}->debug ( "Mail::Spam::is_white_domain $domain in $_?" );
			if ( $domain=~/$_$/ ){
				$found = 1;
				$self->{zlog}->debug ( "Mail::Spam::is_white_domain $domain in $_!" );
				last;
			}
		}
	}

	return $found;


}

sub is_white_addr
{
	my ($self,$addr) = @_;

	return 0 if ( 'Y' ne uc $self->{conf}->{config}->{BlockFrom} );

	my $WhiteFromList = $self->{conf}->{config}->{WhiteFromList};

	my $found = 0;
	if ( defined $WhiteFromList ){
		foreach ( @{$WhiteFromList} ){
			$self->{zlog}->debug ( "Mail::Spam::is_white_addr $addr in $_?" );
			if ( $addr=~/^$_$/ ){
				$found = 1;
				$self->{zlog}->debug ( "Mail::Spam::is_white_addr $addr in $_!" );
				last;
			}
		}
	}
	return $found;
}



sub is_black_addr
{
	my ($self,$addr) = @_;

	return 0 if ( 'Y' ne uc $self->{conf}->{config}->{BlockFrom} );

	my $BlackFromList = $self->{conf}->{config}->{BlackFromList};

	my $found = 0;
	if ( defined $BlackFromList ){
		foreach ( @{$BlackFromList} ){
			$self->{zlog}->debug ( "Mail::Spam::is_black_addr $addr in $_?" );
			if ( $addr=~/^$_$/ ){
				$found = 1;
				$self->{zlog}->debug ( "Mail::Spam::is_black_addr $addr in $_!" );
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
		$self->{zlog}->debug ( "Spam::spam_checker can't get email_domain from [$from_addr]." );
		return undef;
	}

	# 0: 非垃圾 
	# 1: 疑似垃圾
	# 2: 垃圾
	# 3: 黑名单
	$is_spam = 0;

	$self->{zlog}->debug ( "Spam::spam_checker checking $smtp_ip <=> $from_addr ..." );

	if ( &is_white_ip($self,$smtp_ip) ){
		$reason = "IP白名单";
		$is_spam = 0;
	}elsif ( &is_white_domain($self,$email_domain) ){
		$reason = "域名白名单";
		$is_spam = 0;
	}elsif ( &is_white_addr( $self,$from_addr ) ){
		$reason = "地址白名单";
		$is_spam = 0;
	}elsif ( &is_black_ip($self,$smtp_ip) ){
		$reason = "IP黑名单";
		$is_spam = 3;
	}elsif ( &is_black_domain($self,$email_domain) ) {
		$reason = "域名黑名单";
		$is_spam = 3;
	}elsif ( &is_black_addr($self,$from_addr) ){
		$is_spam = 3;
		$reason = "地址黑名单";
	}elsif ( 'Y' eq uc $self->{conf}->{config}->{Traceable} ){
		# 只有启用了可追查性检查时才判断
		my $traceable = &is_traceable( $self, $smtp_ip, $email_domain );

		# strict_traceable:2 = NOT spam:0
		# traceable:1 = maybe spam:1
		# un-traceable:0 = SPAM:2
		$is_spam = 2-$traceable;
		$reason = "可追查性检查";
	}else{
		$reason = "无匹配";
	}

	
	return ($is_spam, $reason);
}


1;



