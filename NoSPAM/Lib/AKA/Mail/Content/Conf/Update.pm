
package Police::Conf::Update;

#use Exporter;
#use vars qw(@ISA @EXPORT);

#@ISA=qw(Exporter);

#@EXPORT=("function1", "function2", "function3");

#use Data::Dumper;
# 改变$转义、缩进
#$Data::Dumper::Useperl = 1;
#$Data::Dumper::Indent = 1;

sub new
{
	my $class = shift;
	my $self = {};

	bless $self, $class;

	my ($conf) = @_;

	$self->{conf} = $conf;

	$self->{zlog} = $conf->{zlog} || new Police::Log($self);
	$self->{verify} = $conf->{verify} || new Police::Verify($self);

	$self->{conf}{rule_add_modify} = undef;
	$self->{conf}{rule_del} = undef;

	return $self;
}

sub check_new_rule
{
	my ( $self ) = @_;

	# 返回新文件数
	return read_rule( $self );
}

sub get_rule_files_in_dir {
	my ($self, $dir) = @_;

#TODO log opendir error
	opendir(GA_RULE_DIR, $dir) or warn "cannot opendir $dir: $!\n";
	my @rules = grep { /\.rule$/ && -f "$dir/$_" } readdir(GA_RULE_DIR);
	closedir GA_RULE_DIR;

	return map { "$dir/$_" } sort { $a cmp $b } @rules;     # sort numerically
}

sub read_rule {
	my ($self) = @_;

	return '' unless defined $self->{conf}->{define}->{home};

	my $path;
	$path = $self->{conf}->{define}->{home} . "/rule/";

	$self->{conf}->{zlog}->log ("using \"$path\" for check rule");

	my $xs = get_update_xml_simple($self);
#_get_xml_simple($self) or die "can't load xml simple";

	my $newfilenum = 0;
	if (-d $path) {

		foreach my $file ($self->get_rule_files_in_dir ($path)) {
			$self->{zlog}->log( "found new spam rule file \"$file\", processing..." );
			if ( ! $self->{verify}->verify_key( $file ) ){
				$self->{zlog}->log( "cannot verify \"$file\": $?\n"); 
				next;
			}

			$newfilenum++;

			$ruleref = $xs->XMLin($file) or warn "cannot xml simple \"$file\": $!\n", next;

			add_rule( $self, $ruleref );
			push ( @{$self->{files}}, $file );
		}

	}
	$newfilenum;
}   

sub add_rule
{
	my ($self, $ruleref) = @_;

	$ruleref or return;

	my ( $rule_add_modify, $rule_del );

	$rule_add_modify = $ruleref->{'asc-msp'}->{'jbl-data'}->{'rule-add-modify'}->{'rule'};
	$rule_del = $ruleref->{'asc-msp'}->{'jbl-data'}->{'rule-del'}->{'rule-id'};

	add_rule_add_modify( $self,$rule_add_modify ) if defined($rule_add_modify) ;
	add_rule_del( $self,$rule_del ) if defined($rule_del) ;
	
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

sub get_rule_add_modify
{
	my $self = shift;

	return $self->{rule_add_modify};
}

sub get_rule_del
{
	my $self = shift;

	return $self->{rule_del};
}

sub clean
{
	my $self = shift;

	foreach my $file ( @{$self->{files}} ){
		$self->{zlog}->log( "cleaning update file: [$file] & [$file sig]" );
		unlink $file;
		unlink "$file\.sig";
	}
}

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


#sub DESTROY
#{
#	my $self = shift;
#}

1;
