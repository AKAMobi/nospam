#
# 北京互联网接警中心邮件过滤器
# Company: AKA Information & Technology Co., Ltd.
# Author: Ed Lee
# EMail: zixia@zixia.net
# Date: 2004-04-10


package AKA::Mail::Archive;


use AKA::Mail::Conf;
use AKA::Mail::Controler;
use AKA::Mail::Police::Parser;

use Archive::Zip qw(:CONSTANTS :ERROR_CODES);

use POSIX qw(strftime);

#use XML::Simple;
#use POSIX qw(strftime);

sub new
{
	my $class = shift;

	my $self = {};

	bless $self, $class;

	my $parent = shift;

	$self->{parent} = $parent;
	$self->{conf} = $parent->{conf} || new AKA::Mail::Conf;
	
	$self->{define}->{archivedir} = "/home/vpopmail/domains/localhost.localdomain/archive/Maildir/";

	return $self;
}

sub archive
{
	my $self = shift;
	my $eml_file = shift;

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

	return 1;
}

# input: eml_filenaem
# output: a str contains exchange data format
sub get_exchange_data
{
	my $self = shift;
	my $emlfile = shift;

	$self->{parser} ||= new AKA::Mail::Police::Parser;

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
		"From:" . $mail_info->{head}->{from} . "0x0D0x0A"
		. "To:" . $mail_info->{head}->{to} . "0x0D0x0A"
		. "Cc:" . $mail_info->{head}->{cc} . "0x0D0x0A"
		. "Subject:" . $mail_info->{head}->{subject} . "0x0D0x0A"
		. "Received:" . join(';',@receives) . "0x0D0x0A"
		. "Content:" . length($mail_info->{body_text}) . "0x0D0x0A"
		. $mail_info->{body_text} . "0x0D0x0A"
		. "Mail:" . length($emldata) . "0x0D0x0A"
		. $emldata
		;
		
	$self->{parser}->clean;
	return $ex_dat;
}

sub print_archive_zip
{
	my $self = shift;

	my @file_list = $self->get_archive_files;

	my $zip = Archive::Zip->new();
	my $member;
	my $status;

	binmode(STDOUT);

	foreach ( @file_list ){
		m#(\d{8,})#;
		$member = $zip->addString( $self->get_exchange_data($_), "$1.log" );
		$member->desiredCompressionMethod( COMPRESSION_DEFLATED );
		$member->desiredCompressionLevel( COMPRESSION_LEVEL_FASTEST );
		$status = $zip->writeToFileHandle( STDOUT );
	}

	1;
}

sub clean_archive_files
{
	my $self = shift;
	
	my @file_list = $self->get_archive_files;
	
	unlink @file_list;

	return 1;
}

sub get_archive_files
{
	my $self = shift;

	my @file_list = ();

        if ( opendir( DIRNEW, $self->{define}->{archivedir} . "/new/") ){
        	foreach (readdir(DIRNEW)) {
                	next if (/^\.{1,2}$/);
                	push(@file_list, $self->{define}->{archivedir} . "/new/$_");
		}
        }
	closedir( DIRNEW );

	if ( opendir( DIRCUR, $self->{define}->{archivedir} . "/cur/") ){
		foreach (readdir(DIRCUR)) {
        		next if (/^\.{1,2}$/);
                	push(@file_list, $self->{define}->{archivedir} . "/cur/$_");
		}
        }
	closedir( DIRCUR );

	return @file_list;
}
1;


