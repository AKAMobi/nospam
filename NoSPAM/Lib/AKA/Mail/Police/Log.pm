#
# 北京互联网接警中心邮件过滤器
# Company: AKA Information & Technology Co., Ltd.
# Author: Ed Lee
# EMail: zixia@zixia.net
# Date: 2004-02-10


package AKA::Mail::Police::Log;
use AKA::Mail::Police::Verify;


use XML::Simple;
use MIME::Base64;
use POSIX qw(strftime);

my $can_log = 1;

BEGIN
{
	open MYLOG, ">>/var/log/police" or $can_log = 0;
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

	my $parent = shift;

	$self->{parent} = $parent;
	$self->{conf} = $parent->{conf} || new AKA::Mail::Police::Conf;
	$self->{verify} = $parent->{verify} || new AKA::Mail::Police::Verify;
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
	if ( $can_log ){
		print MYLOG &get_time_stamp . " $what\n";
	}
}

sub log_match
{
	my $self = shift;
	my ( $rule_info, $mail_info ) = @_;

	my $serialno = rand;
	$serialno = $serialno * 9999;
	$serialno = int ( $serialno );

	my $logfile = $self->{conf}->{define}->{home} . "/log/" . $self->{conf}->{define}->{mspid} . &get_time_stamp . $serialno . "log";
	my $emlfile = $self->{conf}->{define}->{home} . "/log/" . $self->{conf}->{define}->{mspid} . &get_time_stamp . $serialno . "eml";

	my ( $head_data, $body_data );
	$head_data = encode_base64( $self->{parser}->{entity}->head->stringify );
	$body_data = encode_base64( $self->{parser}->{entity}->body->stringify );
	my $logdata = {};

	$logdata->{'asc-msp'}->{'log-data'}->{'match_record'}->{'time'} = &get_time_stamp;
	$logdata->{'asc-msp'}->{'log-data'}->{'match_record'}->{'rule_id'} = $rule_info->{rule_id};
	$logdata->{'asc-msp'}->{'log-data'}->{'match_record'}->{'category_id'} = $rule_nifo->{category_id};
	$logdata->{'asc-msp'}->{'log-data'}->{'match_record'}->{'client_ip'} = $mail_info->{sender_ip};
	$logdata->{'asc-msp'}->{'log-data'}->{'match_record'}->{'ip_zone'} = 0; #XXX
	$logdata->{'asc-msp'}->{'log-data'}->{'match_record'}->{'size'} = $mail_info->{head_size} + $mail_info->{body_size}; #FIXME
	$logdata->{'asc-msp'}->{'log-data'}->{'match_record'}->{'body_size'} = $mail_info->{body_size};
	$logdata->{'asc-msp'}->{'log-data'}->{'match_record'}->{'mail_file'} = $emlfile;
	$logdata->{'asc-msp'}->{'log-data'}->{'match_record'}->{'condition'} = $rule_info->{rule_action}->{action_param};
	$logdata->{'asc-msp'}->{'log-data'}->{'match_record'}->{'action'} = $rule_info->{rule_action}->{action};
	$logdata->{'asc-msp'}->{'log-data'}->{'match_record'}->{'sender'} = $mail_info->{from};
	$logdata->{'asc-msp'}->{'log-data'}->{'match_record'}->{'subject'} = $mail_info->{subject};
	$logdata->{'asc-msp'}->{'log-data'}->{'match_record'}->{'mail_header'} = encode_base64( $head_data );
	$logdata->{'asc-msp'}->{'log-data'}->{'match_record'}->{'mail_content'} = encode_base64( $body_data );

	open ( FD, ">$emlfile" ) or $self->{zlog}->log ( "pf: open $emlfile for writing error" );
	print FD $head_data;
	print FD "\n";
	print FD $body_data;
	close ( FD );
	

	my $xs = $self->{conf}->get_filterdb_xml_simple();
	my $xml = $xs->XMLout( $logdata );

	open ( FD, ">$logfile" ) or $self->{zlog}->log ( "pf: open $logfile for writing error" );
	print FD $xml;
	close ( FD );
	
	if ( ! $self->{verify}->sign($emlfile) ){
		$self->{zlog}->log ( "pf: error for sign file [$emlfile]" );
		unlink $emlfile;
	}
	if ( ! $self->{verify}->sign($logfile) ){
		$self->{zlog}->log ( "pf: error for sign file [$logfile]" );
		unlink $logfile;
	}
}

sub get_time_stamp
{
	strftime "%Y%m%d%H%M%S", localtime;
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



