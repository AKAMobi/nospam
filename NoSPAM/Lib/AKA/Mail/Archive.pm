#
# 北京互联网接警中心邮件过滤器
# Company: AKA Information & Technology Co., Ltd.
# Author: Ed Lee
# EMail: zixia@zixia.net
# Date: 2004-04-10


package AKA::Mail::Archive;


use AKA::Mail::Conf;
use AKA::Mail::Log;
use AKA::Mail::Controler;
use AKA::Mail::Content::Parser;

use Archive::Zip qw(:CONSTANTS :ERROR_CODES);

use POSIX qw(strftime);

sub new
{
	my $class = shift;

	my $self = {};

	bless $self, $class;

	my $parent = shift;

	$self->{parent} = $parent;
	$self->{conf} = $parent->{conf} || new AKA::Mail::Conf;
	$self->{zlog} = $parent->{zlog} || new AKA::Mail::Log;
	
	$self->{define}->{archivedir} = "/home/vpopmail/domains/localhost.localdomain/archive/Maildir/";

	return $self;
}

sub archive
{
	my $self = shift;
	my $eml_file = shift;

#$self->{zlog}->debug ( "archive $eml_file" );
	$eml_file || return 0;

	#$self->{controler} ||= new AKA::Mail::Controler;

	#$self->{controler}->

	my $archive_dir = $self->{define}->{archivedir};

	open( FDR, "<$eml_file" ) or return 0;
	# get pure filename here
	$eml_file=~s#.+/##;
	open( FDW, ">$archive_dir/new/$eml_file") or (close(FDR) && return 0);

	print FDW while ( <FDR> );

	close ( FDW );
	close ( FDR );
	`chown nospam $archive_dir/new/$eml_file`;

	return 1;
}

# input: eml_filenaem
# output: a str contains exchange data format
sub get_exchange_data
{
	my $self = shift;
	my $emlfile = shift;

	$self->{parser} ||= new AKA::Mail::Content::Parser;

	open ( FD, "<$emlfile" ) or return 0;
	my $emldata;
	$emldata .= $_ while ( <FD> );
	close ( FD );

	open ( FD, "<$emlfile" ) or return 0;
	my $mail_info = $self->{parser}->get_mail_info( \*FD );
	close ( FD );
	
	my $relay;
	my @receives = ();
	
	#zixia.net,202.205.10.7,20040411021903
	foreach $relay ( @{$mail_info->{relays}} ){
		$_ = $relay->{helo} 
			. ',' . $relay->{ip}
			. ',' . strftime ("%Y%m%d%H%M%S", localtime($relay->{receive_time}))
			;
		push ( @receives,$_ );
	}

	my $ex_dat =
		"From:" . $mail_info->{head}->{from} . "\r\n"
		. "To:" . $mail_info->{head}->{to} . "\r\n"
		. "Cc:" . $mail_info->{head}->{cc} . "\r\n"
		. "Subject:" . $mail_info->{head}->{subject} . "\r\n"
		. "Received:" . join(';',@receives) . "\r\n"
		. "Content:" . length($mail_info->{body_text}) . "\r\n"
		. $mail_info->{body_text} . "\r\n"
		. "Mail:" . length($emldata) . "\r\n"
		. $emldata
		;
		
	$self->{parser}->clean;
	return $ex_dat;
}

sub print_archive_zip
{
	my $self = shift;

	my $file_list = $self->get_archive_files;

	my $member;

	my $zip = Archive::Zip->new();

	foreach ( @$file_list ){
		m#(\d{8,}\.\d+)#;
		
		$member = $zip->addString( $self->get_exchange_data($_), "$1.log" );
		$member->desiredCompressionMethod( COMPRESSION_DEFLATED );
		$member->desiredCompressionLevel( COMPRESSION_LEVEL_DEFAULT );
	}

	my $status = $zip->writeToFileHandle( STDOUT, 0 );

	1;
}

sub clean_archive_files
{
	my $self = shift;
	
	my $file_list = $self->get_archive_files;
	
	unlink @$file_list;

	return 1;
}

sub get_archive_files
{
	my $self = shift;

	my @file_list = ();

	foreach $dir ( qw(new cur .Trash/new .Trash/cur) ){
        	if ( opendir( DIR, $self->{define}->{archivedir} . "/$dir/") ){
       		 	foreach (readdir(DIR)) {
       		         	next if (/^\.{1,2}$/);
       		         	push(@file_list, $self->{define}->{archivedir} . "/$dir/$_");
			}
        	}
		closedir( DIR );
	}
	return \@file_list;
}
1;


