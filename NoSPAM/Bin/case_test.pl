#!/usr/bin/perl -w

use AKA::Mail::Spam;

$S = new AKA::Mail::Spam;

&test_spam_checker;
#&test_traceable;
############################
sub test_spam_checker
{
	$ip = "202.205.10.10";
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
