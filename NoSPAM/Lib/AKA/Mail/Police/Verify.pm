#
# 北京互联网接警中心邮件过滤器
# Company: AKA Information & Technology Co., Ltd.
# Author: Ed Lee
# EMail: zixia@zixia.net
# Date: 2004-02-10


package AKA::Mail::Police::Verify;

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

	my ($parent) = @_;

	$self->{parent} = $parent;

	$self->{zlog} = $parent->{zlog};
	$self->{conf} = $parent->{conf};

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

sub sign_key
{
	my ($self, $file) = @_;
	my $sign_binary = $self->{conf}->{define}->{sign_binary};
	my $sign_opts = " " . $self->{conf}->{define}->{msp_pri_key};


	if ( ! -e $sign_binary ){
		warn "cannot find sign_binary: \"$sign_binary\"\n";
		return 0;
	}

	`$sign_binary $sign_opts $file`;
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
