#
# 北京互联网接警中心邮件过滤器
# Company: AKA Information & Technology Co., Ltd.
# Author: Ed Lee
# EMail: zixia@zixia.net
# Date: 2004-02-10


use AKA::Mail::Police::Conf;
use AKA::Mail::Log;
use AKA::Mail::Police::Filter;
use AKA::Mail::Police::Verify;

package AKA::Mail::Police;

#BEGIN
#{
#	open MYLOG, ">>/tmp/mylog.log";
#}

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
	$self->{zlog} ||= new AKA::Mail::Log($self);
	$self->{conf} ||= new AKA::Mail::Police::Conf($self);
	$self->{verify} ||= new AKA::Mail::Police::Verify($self);
	$self->{filter} ||= new AKA::Mail::Police::Filter($self);

# Return $self so the user can use it.
	return $self;

}

#sub DESTROY
#{
#    my $self = shift;

    #print "DESTROYed.\n";
#}


#END
#{
#	close(MYLOG);
#}

1;



