# File : MyLog.pm
#

package AKA::Mail::Police::Log;

BEGIN
{
	open MYLOG, ">>/tmp/mylog.log";
}

sub new
{
# Retrieve the package's string.
# It is not necessarily Foo, because this constructor may be
# called from a class that inherits Foo.
	my $class = shift;

# $self is the the object. Let's initialize it to an empty hash
# reference.
	my $self = {};

# Associate $self with the class $class. This is probably the most
# important step.
	bless $self, $class;

# Now we can retrieve the other arguments passed to the 
# construtor.

	#my $name = shift || "Fooish";
	#my $number = shift || 5;

# Put these arguments inside class members
	#$self->{'number'} = 5;

# Return $self so the user can use it.
	return $self;

}

sub log
{
	my ($slef,$what) = @_;

# Strip the string of newline characters
	$what =~ s/\n//g;

# The MYLOG filehandle is already open by virtue of the BEGIN
# block.
	print MYLOG $what, "\n";
}


sub DESTROY
{
    my $self = shift;

    #print "DESTROYed.\n";
}


END
{
	close(MYLOG);
}

1;



