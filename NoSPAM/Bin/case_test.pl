#!/usr/bin/perl -w

use AKA::Mail::Spam;

$S = new AKA::Mail::Spam;

&test_dynamic_from;
#&test_traceable;
############################
sub test_dynamic_from
{
	use AKA::Mail::Dynamic;
	my $AMD = new AKA::Mail::Dynamic;

	my $from = "hehe\@zixia.net";

	if ( $AMD->is_overrun_rate_per_mailfrom( $from ) ){
		print "from: $from is OVERRUN!\n";
	}else{
		print "from: $from is NOT overrun!\n";
	}
	$AMD->dump or die "can't dump";
}


sub test_dynamic_subject
{
	use AKA::Mail::Dynamic;
	my $AMD = new AKA::Mail::Dynamic;

	my $subject = "This is a subject - 2";

	if ( $AMD->is_overrun_rate_per_subject( $subject ) ){
		print "subject: $subject is OVERRUN!\n";
	}else{
		print "subject: $subject is NOT overrun!\n";
	}
	$AMD->dump or die "can't dump";
}

sub test_spam_checker
{
	$ip = "166.111.168.8";
	$addr = "zixia\@zixia.net";

	my ($is_spam, $reason) = $S->spam_checker($ip, $addr);
	print "$is_spam, $reason\n";
}
sub test_white_addr
{
	$test = "bbb\@ccc.com";

	$ret = $S->is_white_addr($test);
	print "$ret\n";
}

sub test_black_addr
{
	$test = "bbb\@ccc.com";

	$ret = $S->is_black_addr($test);
	print "$ret\n";
}

sub test_black_domain
{
	$test = "abc.com";

	$ret = $S->is_black_domain($test);
	print "$ret\n";
}


sub test_white_domain
{
	$test = "abc.com";

	$ret = $S->is_white_domain($test);
	print "$ret\n";
}


sub test_white_ip
{
	$ip = "202.205.99.1";

	$ret = $S->is_white_ip($ip);
	print "$ret\n";
}


sub test_black_ip
{
	$ip = "202.205.99.1";

	$ret = $S->is_black_ip($ip);
	print "$ret\n";
}

sub test_traceable
{
	$ip = "202.205.99.1";

	$traceable = $S->is_traceable($ip, "zixia.net");
	print "$traceable\n";
}
