#!/usr/bin/perl -w

use Data::Dumper;

use AKA::Mail::Spam;

$S = new AKA::Mail::Spam;

#&test_black_ip;
#&test_dynamic_clean;
#&test_dynamic_init;
#&test_dynamic_dump;
&test_ext_dat;
#&test_archive;
#&test_dynamic_subject;
#&test_queue;
#&test_black_ip;
#&test_traceable;
#&test_check_license_file;
exit;
############################
sub test_ext_dat
{
	use AKA::Mail::Archive;
	my $AMA = new AKA::Mail::Archive;

	$AMA->print_archive_zip;
}


sub test_archive
{
	use AKA::Mail::Archive;
	my $AMA = new AKA::Mail::Archive;

	print Dumper( $AMA->get_archive_files );
	print $AMA->archive( "/home/zixia/1081582212.1704.mail.thunis.com,S=1291" );
	print $AMA->archive( "/home/zixia/1081582217.1725.mail.thunis.com,S=1144" );
}

sub test_queue
{
	use AKA::Mail::Controler;
	my $AMC = new AKA::Mail::Controler;
	
	my @q = $AMC->list_queue;
	my @del_list;
	foreach ( @q ){
		#next unless ( $_->{size} > 20000000 );
		#$_->{file} =~ m#/(\d+/\d+)$#;
		#push ( @del_list, $1 );
		print Dumper( $_ );
	}
	#$AMMC->delete_queues( @del_list );
}

sub test_check_license_file
{
	use AKA::Mail;
	my $AM = new AKA::Mail;

	print "check val: " . $AM->check_license_file . "\n";
}

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

	my ( $n, $reason ) = $AM->dynamic_engine( "This is a subject", "zixia\@zixia.net", "192.168.1.1" );
	print "spam: $n, reason: $reason\n" ;
}

sub test_mail_engine_spam
{
	use AKA::Mail;

	my $AM = new AKA::Mail;

	my ( $is_spam, $reason ) = $AM->spam_engine( "102.205.10.10", "zixia\@zixia.net" );
	print "spam: $is_spam, reason: $reason\n" ;
}

sub test_dynamic_clean
{
	use AKA::Mail::Dynamic;
	my $AMD = new AKA::Mail::Dynamic;

	$AMD->clean() or die "can't clean";
}

sub test_dynamic_dump
{
	use AKA::Mail::Dynamic;
	my $AMD = new AKA::Mail::Dynamic;

	$AMD->dump or die "can't dump";
}

sub test_dynamic_ip
{
	use AKA::Mail::Dynamic;
	my $AMD = new AKA::Mail::Dynamic;

	my $ip = "192.168.1.1";

	if ( $AMD->is_overrun_rate_per_ip( $ip ) ){
		print "from: $ip is OVERRUN!\n";
	}else{
		print "from: $ip is NOT overrun!\n";
	}
	$AMD->dump or die "can't dump";
}

sub test_dynamic_init
{
	use AKA::Mail::Dynamic;
	my $AMD = new AKA::Mail::Dynamic;

	if ( $AMD->attach( 1 ) ){
		print "init ok!\n";
	}else{
		print "init failed!\n";
	}
	$AMD->dump or die "can't dump";
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
	#print Dumper($AMD->{dynamic_info}) or die "can't dump";
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
	$ip = "192.168.1.1";

	my $S = new AKA::Mail::Spam;
	$ret = $S->is_black_ip($ip);
	print "$ret\n";
}

sub test_traceable
{
	$ip = "211.157.100.10";

	$traceable = $S->is_traceable($ip, "aka.cn");
	print "traceable: $traceable\n";
}
