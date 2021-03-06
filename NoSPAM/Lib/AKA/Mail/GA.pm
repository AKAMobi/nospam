#
# 互联网接警中心基类
# Company: AKA Information & Technology Co., Ltd.
# Author: Ed Lee
# EMail: zixia@zixia.net
# Date: 2004-04-26


package AKA::Mail::GA;

use XML::Simple;
use POSIX qw(strftime);
use strict;

use AKA::Mail::Log;
use AKA::Mail::Conf;

sub new
{
	my $class = shift;

	my $self = {};

	bless $self, $class;

	my $parent = shift;

	$self->{parent} = $parent;

	$self->init();

	return $self;
}

sub init
{
	my $self = shift;

	$self->{zlog} = $self->{parent}->{zlog} || new AKA::Mail::Log($self) ;
	$self->{conf} = $self->{parent}->{conf} || new AKA::Mail::Conf($self);

	$self->{define}->{home} = "/home/ssh/";
	$self->{define}->{tmpdir} = "/home/NoSPAM/spool/tmp/";
	$self->{define}->{ruledir} = $self->{define}->{home} . "/rule/";

	$self->{define}->{filterdb} = $self->{define}->{home} . "/etc/PoliceDB.xml";
	$self->{define}->{updatedb} = $self->{define}->{home} . "/Update/Update.Xml";

	$self->{rule_add_modify} = undef;
	$self->{rule_del} = undef;
}

sub isEnabled
{
	my $self = shift;
	return ('Y' eq uc $self->{conf}->{config}->{GAInterface}->{GAInterface});
}

sub start_daemon_process
{
	my $self = shift;

	$self->{zlog}->debug ( "GA::start_daemon called, I'm going to sleep..." );

	sleep 600 while ( 1 ) ;
}

sub update_rule
{
	my $self = shift;

	$self->{zlog}->debug ( "GA::update_rule called, I'll do nothing..." );
}

sub check_match
{
	my $self = shift;
	
	my $mail_info = shift;

	unless ( $mail_info ){
		$self->{zlog}->fatal( "GA::check_match got null mail_info" );
		return undef;
	}

	my $AMG;

	use AKA::Mail::GA::GAISC;
	$AMG = new AKA::Mail::GA::GAISC;

#$self->{zlog}->debug( "GA::check_match run" );
	$AMG->check_match($mail_info) if ( $AMG->isEnabled() );
}

sub feed_log
{
	my $self = shift;

	$self->{zlog}->debug ( "GA::feed_log called, I'll do nothing..." );
}

sub feed_alert
{
	my $self = shift;

	$self->{zlog}->debug ( "GA::feed_alert called, I'll do nothing..." );
}

sub make_log
{
	my $self = shift;

	$self->{zlog}->debug ( "GA::make_log called, I'll do nothing..." );
}

sub make_alert
{
	my $self = shift;

	$self->{zlog}->debug ( "GA::make_alert called, I'll do nothing..." );
}

############################################################################
# 上面是公共对外的接口，下面是对内的功能函数
############################################################################

sub get_received_str
{
	my $self = shift;
	my $mail_info = shift;

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
	join(';',@receives) 
}


sub get_filter_db
{
	my $self = shift;

	my $filterdb_file = $self->{define}->{filterdb};

	if ( !-f $filterdb_file ) {
		open ( WDB, ">$filterdb_file" ) or $self->{zlog}->fatal( "can't open $filterdb_file for writing" );
		print WDB <<_SPAMXML_ ;
<?xml version="1.0" encoding="ISO-8859-1"?>
<rule-add-modify>
	<rule rule_id="" />
</rule-add-modify> 
_SPAMXML_
		close ( WDB );
	}

	my $xs = $self->_get_filterdb_xml_simple();

	return $xs->XMLin( $filterdb_file );
}

sub merge_new_rule
{
	my $self = shift;
	my ($rule_add_modify, $rule_del) = @_;

	if ( !$rule_add_modify && !$rule_del ){
		$self->{zlog}->log( "rule_add_modify & rule_del all empty?" );
		return 0;
	}

	my $filterdb = $self->get_filter_db;

	my ($last_rule_id,$last_rule_time);

	for my $rule_id ( sort { $rule_add_modify->{$a}->{update_time} cmp 
					$rule_add_modify->{$b}->{update_time} }
				 keys %{$rule_add_modify} ){
		$self->{zlog}->log ( "add/modifying rule id: [$rule_id] to filterdb" );
		$filterdb->{'rule-add-modify'}->{'rule'}->{$rule_id} =  $rule_add_modify->{$rule_id};
#push ( @{$filterdb->{'rule-add-modify'}->{'rule'}}, $rule_id, $rule_add_modify->{"$rule_id"} );
		$last_rule_id = $rule_id;
		$last_rule_time = $rule_add_modify->{$rule_id}->{update_time};
	}

	for my $rule_id ( keys %{$rule_del} ){
		$self->{zlog}->log ( "deleting rule id: [$rule_id] from filterdb" );
		next unless ( $rule_id );
$self->{zlog}->debug( "GA::merge del rule id: $rule_id\n" );
		delete $filterdb->{'rule-add-modify'}->{'rule'}->{$rule_id} 
			if defined $filterdb->{'rule-add-modify'}->{'rule'}->{$rule_id};
	}
#	$ keys %{$filterdb->{'rule-add-modify'}->{'rule'}} )

# 改变$转义、缩进
	#use Data::Dumper;
	#$Data::Dumper::Useperl = 1;
	#$Data::Dumper::Indent = 1;
	#print Dumper($filterdb);


	my $xs = $self->_get_filterdb_xml_simple();

	my $new_filterdb = $xs->XMLout($filterdb, XMLDecl=>'<?xml version="1.0" encoding="ISO-8859-1"?>');


	my $filterdb_file = $self->{define}->{filterdb};
	my $new_filterdb_file = $filterdb_file . ".new";

	open ( WDB, ">$new_filterdb_file" ) or return $self->{zlog}->fatal( "can't open [$new_filterdb_file] for writting" );
	print WDB $new_filterdb;
	close ( WDB );


	my $bakfile = $filterdb_file . "-" . `date +%Y-%m-%d-%H-%M-%s`;
	chomp $bakfile;

	$self->{zlog}->log( "renaming [$filterdb_file] to [$bakfile]..." );
	rename ( $filterdb_file, $bakfile ) or $self->{zlog}->fatal( "backup file failed!" );

	$self->{zlog}->log( "renaming [$new_filterdb_file] to [$filterdb_file]..." );
	rename ( $new_filterdb_file, $filterdb_file ) or $self->{zlog}->fatal( "can't rename [$new_filterdb_file] to [$filterdb_file]" );

	my $rule_count;
	$rule_count = keys %{$filterdb->{'rule-add-modify'}->{rule}};
	$self->rebirth_update( $rule_count, $last_rule_id, $last_rule_time );

	return 1;
}

sub rebirth_update
{
	my $self = shift;

	my ( $rule_count, $last_rule_id, $last_rule_time )  = @_;

	my $updatedb = {};

	$updatedb->{rule_update}->{rule_sum}->{updatetime} = $self->{zlog}->get_time_stamp();
	$updatedb->{rule_update}->{rule_sum}->{count} = $rule_count;
	$updatedb->{rule_update}->{rule_sum}->{last_rule_time} = $last_rule_time;
	$updatedb->{rule_update}->{rule_sum}->{last_rule_id} = $last_rule_id;

	my $xs = $self->_get_filterdb_xml_simple();
	my $xml = $xs->XMLout( $updatedb, XMLDecl=>'<?xml version="1.0" encoding="ISO-8859-1"?>',NoAttr=>0 );
	
	my $updatedb_file = $self->{define}->{updatedb};
	open ( FD, ">$updatedb_file" . ".new" ) or return $self->{zlog}->fatal ( "pf: open updatedb file [$updatedb_file} for writing error." );
	print FD $xml;
	close ( FD );

	my $bakfile = $updatedb_file . "-" . $self->{zlog}->get_time_stamp();

	$self->{zlog}->log( "renaming [$updatedb_file] to [$bakfile]..." );
	rename ( $updatedb_file, $bakfile ) or $self->{zlog}->fatal( "backup file failed!" );

	$self->{zlog}->log( "renaming [$updatedb_file" . ".new] to [$updatedb_file]..." );
	rename ( $updatedb_file . ".new" , $updatedb_file ) or 
		return $self->{zlog}->fatal( "can't rename [$updatedb_file" . ".new] to [$updatedb_file]" );

	# XXX move it to GA::MSP use ->SUPER::
	#my $sign = $self->{verify} || new AKA::Mail::Content::Verify($self);
	#if ( ! $sign->sign_key ( $updatedb_file ) ){
	#	$self->{zlog}->log ( "pf: sign updatedb file [$updatedb_file] error." );
	#}
}


sub _get_filterdb_xml_simple
{
	my $self = shift;;

	my @parseropts;
	push ( @parseropts, ProtocolEncoding => 'ISO-8859-1' );

	return new XML::Simple( KeepRoot => 1,
			NormaliseSpace => 1,
			parseropts => \@parseropts,
			KeyAttr => {rule=>'+rule_id'},
			ForceArray => ['rule']);

}

sub add_rule_add_modify
{
	my ( $self, $rule ) = @_;
	$rule or return;

	foreach my $rule_id ( keys %{$rule} ){
		$self->{rule_add_modify}->{$rule_id} = $rule->{$rule_id}
	}
}

sub add_rule_del
{
	my ( $self, $rule ) = @_;
	$rule or return;

	foreach my $rule_id ( keys %{$rule} ){
		$self->{rule_del}->{$rule_id} = $rule->{$rule_id}
	}
}

sub clean
{
	my $self = shift;

	foreach my $file ( @{$self->{files}} ){
		# XXX move unlink sig to GA::MSP
		$self->{zlog}->debug( "cleaning update file: [$file] & [$file sig]" );
		unlink $file;
		unlink "$file\.sig";
	}
}

# XXX this is belong to GA::MSP
sub get_update_xml_simple
{
	my ($self) = @_;

	use XML::Simple;

	my @parseropts;
	push ( @parseropts, ProtocolEncoding => 'ISO-8859-1' );
	return new XML::Simple(KeepRoot => 1, 
			NormaliseSpace => 1,
			parseropts => \@parseropts , 
			KeyAttr => {'rule'=>'+rule_id', 'rule-id'=>'+rule_id'}, 
			ForceArray => ['rule', 'rule-id']);
}

# Ed Li <zxiia@zixia.net>, Zhuohuan <lizh@aka.cn>
# to
# zixia@zixia.net,lizh@aka.cn
sub get_addr_str_from_mail_str
{
	my $self = shift;

	my $mail_str = shift;

	my @TOs;
	foreach ( split(/,/, $mail_str ) ){
		if ( m#((\d|\w|\.|\-|_)+\@(\d|\w|\.|\-|_)+)# ){
			push ( @TOs, $1 );
		}
	}

	return join(',',@TOs);
}

1;



