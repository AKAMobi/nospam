#!/usr/bin/perl -w

use AKA::Mail::Spam;

$S = new AKA::Mail::Spam;

&test_mail_engine_dynamic;
#&test_traceable;
############################
sub test_mail_engine_content
{
	use AKA::Mail;

	my $AM = new AKA::Mail;

	print "engine switch: " . $AM->content_engine_is_enabled . "\n";
	my ( $action, $param, $rule_id, $mime_data ) = $AM->content_engine_mime( \*STDIN );

	print "action: $action, rule_id: $rule_id, param; $param\n";
	print "============================\n";
	print $mime_data,"\n";
}


sub test_mail_engine_dynamic
{
	use AKA::Mail;

	my $AM = new AKA::Mail;

	my ( $n, $reason ) = $AM->dynamic_engine( "This is a subject", "zixia\@zixia.net" );
	print "spam: $n, reason: $reason\n" ;
}

sub test_mail_engine_spam
{
	use AKA::Mail;

	my $AM = new AKA::Mail;

	my ( $is_spam, $reason ) = $AM->spam_engine( "102.205.10.10", "zixia\@zixia.net" );
	print "spam: $is_spam, reason: $reason\n" ;
}

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
