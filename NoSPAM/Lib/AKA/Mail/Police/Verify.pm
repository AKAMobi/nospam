
package Police::Verify;

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

	my ($police) = @_;

	$self->{police} = $police;

	$self->{zlog} = $police->{zlog} || new Police::Log($self);
	$self->{conf} = $police->{conf} || new Police::Conf($self);

	return $self;
}

sub verify_key
{
	my ($self, $file) = @_;
	my $verify_binary = $self->{conf}->{define}->{verify_binary};
	my $verify_opts = " " . $self->{conf}->{define}->{cen_pub_key};


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



sub DESTROY
{
	my $self = shift;

	delete $self->{zlog};
	delete $self->{conf};
}

1;
