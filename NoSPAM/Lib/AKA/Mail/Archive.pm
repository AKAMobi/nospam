#
# 北京互联网接警中心邮件过滤器
# Company: AKA Information & Technology Co., Ltd.
# Author: Ed Lee
# EMail: zixia@zixia.net
# Date: 2004-04-10


package AKA::Mail::Archive;


use AKA::Mail::Conf;
use AKA::Mail::Controler;

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
	
	$self->{define}->{archivedir} = "/home/vpopmail/domains/localhost.localdomain/archive/Maildir/new";

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
	open( FDW, ">$archive_dir/$eml_file") or (close(FDR) && return 0);

	print FDW while ( <FDR> );

	close ( FDW );
	close ( FDR );

	return 1;
}

1;



