
package Police::Conf;

#use Exporter;
#use vars qw(@ISA @EXPORT);

#@ISA=qw(Exporter);

#@EXPORT=("function1", "function2", "function3");

#use Data::Dumper;
# �ı�$ת�塢����
#$Data::Dumper::Useperl = 1;
#$Data::Dumper::Indent = 1;
use Police::Conf::Update;

sub new
{
	my $class = shift;
	my $self = {};

	bless $self, $class;

	my ($main) = @_;

	$self->{main} = $main;

	$self->{zlog} = $main->{zlog};

	$self->{define}->{home} = "/home/ssh/";
	$self->{define}->{verify_binary} = $self->{define}->{home} . "/bin/GAverify";
	$self->{define}->{sign_binary} = $self->{define}->{home} . "/bin/GAsign";
	$self->{define}->{cen_pub_key} = $self->{define}->{home} . "/key/cen_verify_key";
	$self->{define}->{cen_pri_key} = $self->{define}->{home} . "/key/cen_sign_key";
	$self->{define}->{msp_pub_key} = $self->{define}->{home} . "/key/msp_verify_key";
	$self->{define}->{msp_pri_key} = $self->{define}->{home} . "/key/msp_sign_key";

#$self->{xs} = get_xml_simple();

	$self->{rule_add_modify} = undef;
	$self->{rule_del} = undef;

	return $self;
}

# ��� rules/ *.rule�����±������ݿ⣬��¼Update
# ����и��£�����1�����򷵻�0
sub check_n_update
{
	my $self = shift;

	$self->{update} ||= new Police::Conf::Update($self);

	my $newfilenum = $self->{update}->check_new_rule();
	if ( $newfilenum > 0 ){
		$self->{zlog}->log ( "found $newfilenum new rule file(s), mergeing to local database" );
# �����ļ�
		$self->merge_new_rule($self->{update}->get_rule_add_modify(),
				$self->{update}->get_rule_del() );
		$self->{update}->clean();
# TODO ���� spamd
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

	use Data::Dumper;
# �ı�$ת�塢����
	$Data::Dumper::Useperl = 1;
	$Data::Dumper::Indent = 1;


	print "rule_add_modify: \n";
	print Dumper( $rule_add_modify );
	print "\n\n";
	print "rule_del: \n";
	print Dumper( $rule_del );

	return 1;
}

sub get_xml_simple
{
	my ($self) = @_;

	return $self->{xs} if defined ( $self->{xs} );

	use XML::Simple;

	my @parseropts;
	push ( @parseropts, ProtocolEncoding => 'ISO-8859-1' );
	$self->{xs} = new XML::Simple(KeepRoot => 1, 
			parseropts => \@parseropts , 
			KeyAttr => {rule=>'rule_id', 
			'rule-del'=>'rule_id'}, 
			ForceArray => ['rule', 
			'rule-del']);
}



sub DESTROY
{
	my $self = shift;

	delete $self->{main};
}

1;
