
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

	my ($main) = @_;

	$self->{main} = $main;

	$self->{zlog} = $main->{zlog};

	#$self->{xs} = get_xml_simple();

	$self->{main}{rule_add_modify} = undef;
	$self->{main}{rule_del} = undef;

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

	return '' unless defined $self->{main}->{define}->{home};

	my $path;
	$path = $self->{main}->{define}->{home} . "/rule/";

	$self->{main}->{zlog}->log ("using \"$path\" for check rule");

	$self->{main}->{xs} ||= $self->{main}->get_xml_simple( $self->{main} );
#_get_xml_simple($self) or die "can't load xml simple";

	my $newfile = 0;
	if (-d $path) {

		$self->{main}->{xs} or $self->{main}->get_xml_simple();

		foreach my $file ($self->get_rule_files_in_dir ($path)) {
			$newfile++;
			$self->{main}->{zlog}->log( "found new spam rule file \"$file\", processing..." );

			verify_key( $self, $file ) or warn "cannot verify \"$file\": $?\n", next;
			$ruleref = $self->{main}->{xs}->XMLin($file) or warn "cannot xml simple \"$file\": $!\n", next;

			add_rule( $self, $ruleref );
			push ( @{$self->{files}}, $file );
		}

	}
	$newfile;
}   

sub add_rule
{
	my ($self, $ruleref) = @_;

	$ruleref or return;

	my ( $rule_add_modify, $rule_del );

	$rule_add_modify = $ruleref->{'asc-msp'}->{'jbl-data'}->{'rule-add-modify'}->{'rule'};
	$rule_del = $ruleref->{'asc-msp'}->{'jbl-data'}->{'rule-del'};

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


sub verify_key
{
	my ($self, $file) = @_;
	my $verify_binary = $self->{main}->{define}->{verify_binary};
	my $verify_opts = " " . $self->{main}->{define}->{cen_pub_key};


	if ( ! -f $verify_binary ){
		warn "cannot find verify_binary: \"$verify_binary\"\n";
		return 0;
	}

	`$verify_binary $verify_opts $file`;
	if ( 0==$? ){
		return 1;
	}

	return 0;
}

#sub DESTROY
#{
#	my $self = shift;
#}

1;
