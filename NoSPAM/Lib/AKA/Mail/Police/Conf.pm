
package Police::Conf;

#use Exporter;
#use vars qw(@ISA @EXPORT);

#@ISA=qw(Exporter);

#@EXPORT=("function1", "function2", "function3");

#use Data::Dumper;
# 改变$转义、缩进
#$Data::Dumper::Useperl = 1;
#$Data::Dumper::Indent = 1;
use Police::Conf::Update;

use XML::Simple;

sub new
{
	my $class = shift;
	my $self = {};

	bless $self, $class;

	my ($police) = @_;

	$self->{police} = $police;

	$self->{zlog} = $police->{zlog} || new Police::Log();

	$self->{define}->{home} = "/home/ssh/";

	$self->{define}->{verify_binary} = $self->{define}->{home} . "/bin/GAverify";
	$self->{define}->{sign_binary} = $self->{define}->{home} . "/bin/GAsign";

	$self->{define}->{cen_pub_key} = $self->{define}->{home} . "/key/cen_verify_key";
	$self->{define}->{cen_pri_key} = $self->{define}->{home} . "/key/cen_sign_key";
	$self->{define}->{msp_pub_key} = $self->{define}->{home} . "/key/msp_verify_key";
	$self->{define}->{msp_pri_key} = $self->{define}->{home} . "/key/msp_sign_key";

	$self->{define}->{filterdb} = $self->{define}->{home} . "/etc/PoliceDB.xml";

	$self->{rule_add_modify} = undef;
	$self->{rule_del} = undef;

	return $self;
}

# 检查 rules/ *.rule，更新本地数据库，记录Update
# 如果有更新，返回1，否则返回0
sub check_n_update
{
	my $self = shift;

	$self->{update} ||= new Police::Conf::Update($self);

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

sub merge_new_rule
{
	my ($self, $rule_add_modify, $rule_del) = @_;
	if ( !$rule_add_modify && !$rule_del ){
		$self->{zlog}->log( "rule_add_modify & rule_del all empty?" );
		return 0;
	}

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

	for my $rule_id ( keys %{$rule_del} ){
		$self->{zlog}->log ( "deleting rule id: [$rule_id] from filterdb" );
		delete $filterdb->{'rule-add-modify'}->{'rule'}->{$rule_id} if defined $filterdb->{'rule-add-modify'}->{'rule'}->{$rule_id};
	}
	use Data::Dumper;
# 改变$转义、缩进
	$Data::Dumper::Useperl = 1;
	$Data::Dumper::Indent = 1;
	print Dumper($filterdb);


	my $hasrule = 0;
	for my $rule_id ( keys %{$rule_add_modify} ){
		$hasrule = 1;
		$self->{zlog}->log ( "add/modifying rule id: [$rule_id] to filterdb" );
		$filterdb->{'rule-add-modify'}->{'rule'}->{$rule_id} =  $rule_add_modify->{"$rule_id"};
#push ( @{$filterdb->{'rule-add-modify'}->{'rule'}}, $rule_id, $rule_add_modify->{"$rule_id"} );
	}

	if ( $hasrule ){
		delete $filterdb->{'rule-add-modify'}->{'rule'}->{""};
	}

	$new_filterdb = $xs->XMLout($filterdb);


	$new_filterdb_file = $filterdb_file . ".new";

	open ( WDB, ">$new_filterdb_file" ) or die "can't open [$new_filterdb_file] for writting";
	print WDB $new_filterdb;
	close ( WDB );


	my $bakfile = $filterdb_file . "-" . `date +%Y-%m-%d-%H-%M-%s`;

	$self->{zlog}->log( "renaming [$filterdb_file] to [$bakfile]..." );
	rename ( $filterdb_file, $bakfile ) or warn "backup file failed!";

	$self->{zlog}->log( "renaming [$new_filterdb_file] to [$filterdb_file]..." );
	rename ( $new_filterdb_file, $filterdb_file ) or die "can't rename [$new_filterdb_file] to [$filterdb_file]";

	return 1;
}

sub get_filterdb_xml_simple
{
	my ($self) = @_;

	my @parseropts;
	push ( @parseropts, ProtocolEncoding => 'ISO-8859-1' );

	$xs = new XML::Simple( KeepRoot => 1,
			NormaliseSpace => 1,
			parseropts => \@parseropts,
			KeyAttr => {rule=>'rule_id'},
			ForceArray => ['rule']);

}





sub DESTROY
{
	my $self = shift;

	delete $self->{police};
}

1;
