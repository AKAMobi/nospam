#
# 北京互联网接警中心邮件过滤器
# Company: AKA Information & Technology Co., Ltd.
# Author: Ed Lee
# EMail: zixia@zixia.net
# Date: 2004-02-10


package AKA::Mail::Log;


#use XML::Simple;
use POSIX qw(strftime);
use Fcntl ':flock';

my $can_log = 1;
my $can_debug = 1;
my $can_fatal = 1;

BEGIN
{
	open MYLOG, ">>/var/log/NoSPAM" or $can_log = 0;
	open DEBUG, ">>/var/log/NoSPAM.debug" or $can_debug = 0;
	open FATAL, ">>/var/log/NoSPAM.fatal" or $can_fatal = 0;
	select MYLOG; $|=1;
	select DEBUG; $|=1;
	select FATAL; $|=1;
	select STDOUT;
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
	#$self->{conf} = $parent->{conf} || new AKA::Mail::Content::Conf;
	#$self->{verify} = $parent->{verify};
	#XXX by zixia no need to load Verify in Log module  || new AKA::Mail::Content::Verify;

# Now we can retrieve the other arguments passed to the 
# construtor.

	#my $name = shift || "Fooish";
	#my $number = shift || 5;

# Put these arguments inside class members
	#$self->{'number'} = 5;

# Return $self so the user can use it.
	return $self;

}

sub fatal
{
	my ($slef,$what) = @_;

	#$what =~ s/\n/\\n/g;

	if ( $can_fatal ){
		print FATAL &get_log_time . " $what\n";
	}

	return 0;
}



sub debug
{
	my ($slef,$what) = @_;

	#$what =~ s/\n/\\n/g;

	if ( $can_debug ){
		print DEBUG &get_log_time . " $what\n";
	}
}


sub log
{
	my ($slef,$what) = @_;

# Strip the string of newline characters
#	$what =~ s/\n/\\n/g;

# The MYLOG filehandle is already open by virtue of the BEGIN
# block.
	if ( $can_log ){
		print MYLOG &get_log_time . " $what\n";
	}
}

sub get_log_time
{
	strftime "%Y-%m-%d %H:%M:%S", localtime;
}


sub get_time_stamp
{
	strftime "%Y%m%d%H%M%S", localtime;
}

sub log_csv {
	my $self = shift;

	my $mail_info = shift;

	my $aka = $mail_info->{aka};
	my $engine = $mail_info->{aka}->{engine};

	my $esc_subject = $mail_info->{aka}->{subject} || '';
	$esc_subject =~ s/,/_/g;
	$esc_subject = ' ' . $esc_subject . ' ';
	my $recips = $aka->{recips};
	$recips =~ s/,/，/g;

	if ( open ( LFD, ">>/var/log/NoSPAM.csv" ) ){
		flock(LFD,LOCK_EX);
		seek(LFD, 0, 2);
#print LFD strftime("%Y-%m-%d %H:%M:%S", localtime) 
		print LFD time
# ins-queue is link of ns-queue for internal mail scan, 0 means Ext->Int, 1 means Int->Ext
			. ',' . (	( 	(defined $aka->{RELAYCLIENT} && 1==$aka->{RELAYCLIENT})
							|| 
						length($aka->{TCPREMOTEINFO})
					) ?'1':'0' 
				)
			. ',' . $aka->{TCPREMOTEIP} . ',' . $aka->{returnpath} 
				. ',' . $recips . ',' . $esc_subject

			. ',' . $aka->{size} 

			. ',' . $engine->{antivirus}->{result}
				. ',' . $engine->{antivirus}->{desc} 
				. ',' . $engine->{antivirus}->{action} 

	
			. ',' . $engine->{spam}->{result} 
				. ',' . $engine->{spam}->{desc} 
				. ',' . $engine->{spam}->{action}

			. ',' . ($engine->{content}->{result}||'')
				. ',' . $engine->{content}->{action}
				. ',' . $engine->{content}->{desc}
				
			. ',' . $engine->{dynamic}->{result} 
				. ',' . $engine->{dynamic}->{desc} 

			. ',' . $engine->{archive}->{result} 
				. ',' . $engine->{archive}->{desc} 

			. "\n";

		flock(LFD,LOCK_UN);
		close(LFD);
	}else{
		&debug ( "AKA_mail_engine::log open NoSPAM.csv failure." );
	}
}

END
{
	close(MYLOG);
	close(DEBUG);
	close(FATAL);
}

1;



