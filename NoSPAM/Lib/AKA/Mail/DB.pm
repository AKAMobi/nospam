#
# noSPAM 数据库接口
# Company: AKA Information & Technology Co., Ltd.
# Author: Ed Li
# EMail: zixia@zixia.net
# Date: 2004-07-25

package AKA::Mail::DB;

use strict;
use DBI;
use AKA::Mail::Log;

sub new
{
	my $class = shift;
	my $self = {};
	bless $self, $class;

	my $parent = shift;

	$self->{parent} = $parent;
	$self->{zlog} = $parent->{zlog} || new AKA::Mail::Log;
	
	$self->{define}->{DBFile} = "/home/NoSPAM/var/sqlite/nospam.sqlite";

	return $self;
}

sub connect
{
	my $self = shift;
	
	# XXX
	#return $self->{dbh} if defined $self->{dbh};
	eval { $self->{dbh}->disconnect; $self->{dbh} = undef; } if defined $self->{dbh};

	$self->{zlog}->debug( "DB::connect pid $$" );
	my $DBFile = $self->{define}->{DBFile};
	$self->{dbh} = DBI->connect("dbi:SQLite:dbname=$DBFile","","") or 
		$self->{zlog}->fatal( "DB::connect failed! $!" );

	return $self->{dbh};
}

sub disconnect
{
	my $self = shift;
	eval { $self->{dbh}->disconnect(); };
	undef $self->{dbh};
}

# drop: if true, then drop first
sub create_table($$)
{
	my $self = shift;
	my $drop = shift;

	my $drop_sql = <<__SQL__;
drop table UserEmail_TB;
__SQL__

	my $create_sql = <<__SQL__;
create table UserEmail_TB (
	Email varchar(64) primary key
);
__SQL__

	my $dbh = $self->connect;

	if ( $drop ){
		eval {
			$dbh->do ( $drop_sql );
		};
	}
	$dbh->do ( $create_sql ) or $self->{zlog}->fatal ( "DB::create_table failed: $!" );
}

# email addr add to UserEmail_TB
sub user_email_add($$)
{
	my $self = shift;
	my $email = shift;

	my ($sth_del,$sth_ins) = $self->user_email_add_prepaer();
	$self->user_email_add_execute( $sth_del, $sth_ins, $email );
	$sth_del->finish;
	$sth_ins->finish;
}

sub user_email_add_prepare
{
	my $self = shift;
	my $dbh = $self->connect;

	my $sth_del = $dbh->prepare( "delete from UserEmail_TB where EMail=?" );
	my $sth_ins = $dbh->prepare( "insert into UserEmail_TB (EMail) values (?)" );

	return ( $sth_del,$sth_ins );
}

sub user_email_add_execute
{
	my $self = shift;

	my ($sth_del,$sth_ins,$email) = @_;

	$sth_del->execute( $email ) or 
		$self->{zlog}->fatal( "DB::user_email_add_execute failed when delete: $!" );

	$sth_ins->execute ( $email ) or
		$self->{zlog}->fatal( "DB::user_email_add_execute failed when insert: $!" );
}

sub user_email_list($)
{
	my $self = shift;
	
	my $dbh = $self->connect;

	my $sth = $dbh->prepare ( "select Email from UserEmail_TB" );
	$sth->execute();
	while( ($_)=$sth->fetchrow_array() ){
       		print STDOUT "$_\n"
	}
	$sth->finish;
}

sub user_email_clean($)
{
	my $self = shift;

	$self->connect()->do ( "delete from UserEmail_TB" );
}
# 判断用户email是否存在
sub user_email_exist($$)
{
	my $self = shift;
	my $email = shift;

	my $dbh = $self->connect();

	my $sth = $dbh->prepare ( "select count(*) from UserEmail_TB where Email=?" );
	$sth->execute( $email );
	my ($count) = $sth->fetchrow_array();
	$sth->finish;
	return $count;
}

1;
