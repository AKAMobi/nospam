#
# 北京互联网接警中心邮件过滤器
# Company: AKA Information & Technology Co., Ltd.
# Author: Ed Lee
# EMail: zixia@zixia.net
# Date: 2004-02-10


package AKA::Mail::Police::Conf;

use AKA::Mail::Log;

#use Exporter;
#use vars qw(@ISA @EXPORT);

#@ISA=qw(Exporter);

#@EXPORT=("function1", "function2", "function3");

#use Data::Dumper;
# 改变$转义、缩进
#$Data::Dumper::Useperl = 1;
#$Data::Dumper::Indent = 1;
use AKA::Mail::Police::Conf::Update;

use XML::Simple;

sub new
{
	my $class = shift;
	my $self = {};

	bless $self, $class;

	my ($police) = @_;

	$self->{police} = $police;

	$self->{zlog} = $police->{zlog};

	$self->{define}->{mspid} = "300001";
	$self->{define}->{home} = "/home/ssh/";
	$self->{define}->{tmpdir} = "/home/NoSPAM/spool/tmp/";

	# 用户过滤策略
	$self->{define}->{user_filterdb} = "/home/NoSPAM/etc/UserFilterRule.xml";

	$self->{define}->{filterdb} = $self->{define}->{home} . "/etc/PoliceDB.xml";
	$self->{define}->{updatedb} = $self->{define}->{home} . "/Update/Update.Xml";

	$self->{define}->{verify_binary} = $self->{define}->{home} . "/bin/GAverify";
	$self->{define}->{sign_binary} = $self->{define}->{home} . "/bin/GAsign";

	$self->{define}->{cen_pub_key} = $self->{define}->{home} . "/key/cen_verify_key";
	$self->{define}->{cen_pri_key} = $self->{define}->{home} . "/key/cen_sign_key";
	$self->{define}->{msp_pub_key} = $self->{define}->{home} . "/key/msp_verify_key";
	$self->{define}->{msp_pri_key} = $self->{define}->{home} . "/key/msp_sign_key";



	$self->{rule_add_modify} = undef;
	$self->{rule_del} = undef;

	return $self;
}

# 检查 rules/ *.rule，更新本地数据库，记录Update
# 如果有更新，返回1，否则返回0
sub check_n_update
{
	my $self = shift;

	$self->{update} ||= new AKA::Mail::Police::Conf::Update($self);
	$self->{zlog} ||= new AKA::Mail::Log($self);

	my $newfilenum = $self->{update}->check_new_rule() || 0 ;
	if ( $newfilenum > 0 ){
		$self->{zlog}->log ( "found $newfilenum new rule file(s), mergeing to local database" );
# 更新文件
		$self->merge_new_rule($self->{update}->get_rule_add_modify(),
				$self->{update}->get_rule_del() );
		$self->{update}->clean();
# TODO 重起 spamd
	}
	return $newfilenum;
}

sub get_user_filter_db
{
	my $self = shift;

	my $filterdb_file = $self->{define}->{user_filterdb};

	if ( !-f $filterdb_file ) {
		open ( WDB, ">$filterdb_file" ) or die "can't open $filterdb_file for writing";
		print WDB <<_SPAMXML_ ;
<rule-add-modify>
	<rule rule_id="" />
</rule-add-modify> 
_SPAMXML_
		close ( WDB );
		`chown nospam.nospam $filterdb_file`;
	}

	my $xs = get_filterdb_xml_simple();

	return $xs->XMLin( $filterdb_file );
}


sub get_filter_db
{
	my $self = shift;

	my $filterdb_file = $self->{define}->{filterdb};

	if ( !-f $filterdb_file ) {
		open ( WDB, ">$filterdb_file" ) or die "can't open $filterdb_file for writing";
		print WDB <<_SPAMXML_ ;
<rule-add-modify>
	<rule rule_id="" />
</rule-add-modify> 
_SPAMXML_
			close ( WDB );
	}

	my $xs = get_filterdb_xml_simple();

	return $xs->XMLin( $filterdb_file );
}


sub merge_new_rule
{
	my ($self, $rule_add_modify, $rule_del) = @_;
	if ( !$rule_add_modify && !$rule_del ){
		$self->{zlog}->log( "rule_add_modify & rule_del all empty?" );
		return 0;
	}

	my $filterdb = &get_filter_db;

	my ($last_rule_id,$last_rule_time);

	for my $rule_id ( sort { $rule_add_modify->{$a}->{update_time} cmp 
					$rule_add_modify->{$b}->{update_time} }
				 keys %{$rule_add_modify} ){
		$self->{zlog}->log ( "add/modifying rule id: [$rule_id] to filterdb" );
		$filterdb->{'rule-add-modify'}->{'rule'}->{$rule_id} =  $rule_add_modify->{"$rule_id"};
#push ( @{$filterdb->{'rule-add-modify'}->{'rule'}}, $rule_id, $rule_add_modify->{"$rule_id"} );
		$last_rule_id = $rule_id;
		$last_rule_time = $rule_add_modify->{$rule_id}->{update_time};
	}

	for my $rule_id ( keys %{$rule_del} ){
		$self->{zlog}->log ( "deleting rule id: [$rule_id] from filterdb" );
		delete $filterdb->{'rule-add-modify'}->{'rule'}->{$rule_id} if defined $filterdb->{'rule-add-modify'}->{'rule'}->{$rule_id};
	}
#	$ keys %{$filterdb->{'rule-add-modify'}->{'rule'}} )

# 改变$转义、缩进
	#use Data::Dumper;
	#$Data::Dumper::Useperl = 1;
	#$Data::Dumper::Indent = 1;
	#print Dumper($filterdb);


	$new_filterdb = $xs->XMLout($filterdb, XMLDecl=>'<?xml version="1.0" encoding="ISO-8859-1"?>');


	my $filterdb_file = $self->{define}->{filterdb};
	$new_filterdb_file = $filterdb_file . ".new";

	open ( WDB, ">$new_filterdb_file" ) or die "can't open [$new_filterdb_file] for writting";
	print WDB $new_filterdb;
	close ( WDB );


	my $bakfile = $filterdb_file . "-" . `date +%Y-%m-%d-%H-%M-%s`;
	chomp $bakfile;

	$self->{zlog}->log( "renaming [$filterdb_file] to [$bakfile]..." );
	rename ( $filterdb_file, $bakfile ) or warn "backup file failed!";

	$self->{zlog}->log( "renaming [$new_filterdb_file] to [$filterdb_file]..." );
	rename ( $new_filterdb_file, $filterdb_file ) or die "can't rename [$new_filterdb_file] to [$filterdb_file]";

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

	my $xs = get_filterdb_xml_simple();
	my $xml = $xs->XMLout( $updatedb, XMLDecl=>'<?xml version="1.0" encoding="ISO-8859-1"?>',NoAttr=>0 );
	
	$updatedb_file = $self->{define}->{updatedb};
	open ( FD, ">$updatedb_file" . ".new" ) or $self->{zlog}->log ( "pf: open updatedb file [$updatedb_file} for writing error." );
	print FD $xml;
	close ( FD );

	my $bakfile = $updatedb_file . "-" . `date +%Y-%m-%d-%H-%M-%s`;
	chomp $bakfile;

	$self->{zlog}->log( "renaming [$updatedb_file] to [$bakfile]..." );
	rename ( $updatedb_file, $bakfile ) or warn "backup file failed!";

	$self->{zlog}->log( "renaming [$updatedb_file" . ".new] to [$updatedb_file]..." );
	rename ( $updatedb_file . ".new" , $updatedb_file ) or die "can't rename [$updatedb_file" . ".new] to [$updatedb_file]";

	my $sign = $self->{police}->{verify} || new AKA::Mail::Police::Verify($self);
	if ( ! $sign->sign_key ( $updatedb_file ) ){
		$self->{zlog}->log ( "pf: sign updatedb file [$updatedb_file] error." );
	}
}

sub get_filterdb_xml_simple
{
	my ($self) = @_;

	my @parseropts;
	push ( @parseropts, ProtocolEncoding => 'ISO-8859-1' );

	$xs = new XML::Simple( KeepRoot => 1,
			NormaliseSpace => 1,
			parseropts => \@parseropts,
			KeyAttr => {rule=>'+rule_id'},
			ForceArray => ['rule']);

}


sub load_filter_db
{
	my $self = shift;

	my $filterdb_file = $self->{define}->{filterdb};

	if ( !-f $filterdb_file ) {
		open ( WDB, ">$filterdb_file" ) or die "can't open $filterdb_file for writing";
		print WDB <<_SPAMXML_ ;
<rule-add-modify>
	<rule rule_id="" />
</rule-add-modify> 
_SPAMXML_
			close ( WDB );
	}

	my $xs = get_filterdb_xml_simple();

	my $filterdb = $xs->XMLin( $filterdb_file );

	return $filterdb;
}


sub DESTROY
{
	my $self = shift;

	delete $self->{police};

}

1;
