#
# 北京互联网接警中心邮件过滤器
# Company: AKA Information & Technology Co., Ltd.
# Author: Ed Lee
# EMail: zixia@zixia.net
# Date: 2004-02-10


package AKA::Mail::Log;


#use AKA::Mail::DB;

#use XML::Simple;
use POSIX qw(strftime);
use Fcntl ':flock';
use Time::HiRes qw( usleep ualarm gettimeofday tv_interval );
use Data::Dumper;

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
	
	#$self->{db} = new AKA::Mail::DB;

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

	# PreFork 模式下统计 cputime 需要作差
	$self->{last_cputime} ||= 0;

	return $self;

}

sub fatal
{
	my ($slef,$what) = @_;

	$what =~ s/\n/\\n/g;

	if ( $can_fatal ){
		print FATAL &get_log_time . " $what\n";
	}

	return 0;
}



sub debug
{
	my ($slef,$what) = @_;

	return unless $what;

	$what =~ s/\n/\\n/g;

	if ( $can_debug ){
		print DEBUG &get_log_time . " $what\n";
	}
}


sub log
{
	my ($slef,$what) = @_;

# Strip the string of newline characters
	$what =~ s/\n/\\n/g;

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

sub log_mail
{
	my $self = shift;
	my $mail_info = shift;

	my $mail_log = $self->get_mail_log_from_info( $mail_info );
	
 	open ( FD, ">/tmp/log" ); print FD Dumper($mail_log); close (FD);

	$self->log_csv( $mail_log );
	#$self->{db}->log_mail( $mail_log );

	$self->log_rrdds( $mail_info );
	$self->log_sa ( $mail_info );
}

sub get_mail_log_from_info
{
	my $self = shift;
	my $mail_info = shift;

	my $aka = $mail_info->{aka};
	my $engine = $mail_info->{aka}->{engine};

	my $esc_subject = $mail_info->{head}->{subject} || $mail_info->{aka}->{subject} || '';
	$esc_subject =~ s/,/_/g;
	$esc_subject = ' ' . $esc_subject . ' ';
	my $recips = $aka->{recips};
	
	# ins-queue is link of ns-queue for internal mail scan, 0 means Ext->Int, 1 means Int->Ext
	return { 
			UnixTime	=> time # UnixTime
			, Direction 	=> (	( 	(defined $aka->{RELAYCLIENT} && '1' eq $aka->{RELAYCLIENT})
							|| 
						length($aka->{TCPREMOTEINFO})
					) ?'1':'0' 
				) # Direction
			, IP		=> $aka->{TCPREMOTEIP} # IP
			, MailFrom	=> $aka->{returnpath}  # MailFrom
			, MailTo	=> $recips # MailTo
			, Subject	=> $esc_subject # Subject
			, Size		=> $aka->{size} # Size

			, isVirus	=> $engine->{antivirus}->{result}
				, VirusReason	=> $engine->{antivirus}->{desc} 
				, VirusAction	=> $engine->{antivirus}->{action} 

			, isSpam	=> $engine->{spam}->{result} 
				, SpamReason	=> $engine->{spam}->{desc} 
				, SpamAction	=> $engine->{spam}->{action}

			, RuleNo	=> ($engine->{content}->{result}||'')
				, RuleAction	=> $engine->{content}->{action}
				, RuleParam	=> $engine->{content}->{desc}
					
			, isOverrun	=> $engine->{dynamic}->{result} 
				, OverrunReason	=> $engine->{dynamic}->{desc} 

			, isAudit	=> $engine->{archive}->{result} 
				, AuditReason	=> $engine->{archive}->{desc} 

			, isQuarantine	=> ''
				, QuarantineReason	=> '' # Quarantine
		};
}

sub log_csv {
	my $self = shift;

	my $mail_log = shift;

	if ( open ( LFD, ">>/var/log/NoSPAM.csv" ) ){
		flock(LFD,LOCK_EX);
		seek(LFD, 0, 2);
#print LFD strftime("%Y-%m-%d %H:%M:%S", localtime) 
		print LFD $mail_log->{UnixTime}
			. ',' . $mail_log->{Direction}
			. ',' . $mail_log->{IP} . ', ' . $mail_log->{MailFrom}
				. ' , ' . $mail_log->{MailTo} . ' ,' . $mail_log->{Subject}

			. ',' . $mail_log->{Size} 

			. ',' . $mail_log->{isVirus}
				. ',' . $mail_log->{VirusReason}
				. ',' . $mail_log->{VirusAction}

			. ',' . $mail_log->{isSpam}
				. ',' . $mail_log->{SpamReason}
				. ',' . $mail_log->{SpamAction}

			. ',' . $mail_log->{RuleNo}
				. ',' . $mail_log->{RuleAction}
				. ',' . $mail_log->{RuleParam}
				
			. ',' . $mail_log->{isOverrun}
				. ',' . $mail_log->{OverrunReason}

			. ',' . $mail_log->{isAudit}
				. ',' . $mail_log->{AuditReason}

			. "\n";

		flock(LFD,LOCK_UN);
		close(LFD);
	}else{
		&debug ( "AKA_mail_engine::log open NoSPAM.csv failure." );
	}
}

sub log_rrdds
{
	my $self = shift;
	my $mail_info = shift;

	my $aka = $mail_info->{aka};
	my $engine = $mail_info->{aka}->{engine};

	my ($user,$system,$cuser,$csystem) = times;
	my $cputime = $user+$system+$cuser+$csystem;

#$self->debug( "log spam cputime: [" . $engine->{spam}->{cputime} . "]" );
#$self->debug( "log spam runtime: [" . $engine->{spam}->{runtime} . "]" );
#$self->debug( "log spam dnstime: [" . $engine->{spam}->{dns_query_time} . "]" );
	if ( open ( LFD, ">>/var/log/NoSPAM.rrdds" ) ){
		flock(LFD,LOCK_EX);
		seek(LFD, 0, 2);
		print LFD time
			. ',' . (	( 	(defined $aka->{RELAYCLIENT} && '1' eq $aka->{RELAYCLIENT})
							|| 
						length($aka->{TCPREMOTEINFO})
					) ?'1':'0' 
				)
			. ',' . $aka->{size} 
			. ',' . ( int(1000*tv_interval($mail_info->{aka}->{start_time}, [gettimeofday])) 
				  - ($engine->{spam}->{dns_query_time}||0) )
			. ',' . int(1000*($cputime - $self->{last_cputime}))

			. ',' . $engine->{antivirus}->{result}
				. ',' . $engine->{antivirus}->{runtime}
				. ',' . $engine->{antivirus}->{cputime}
				. ',' . $engine->{antivirus}->{runned}

			. ',' . $engine->{spam}->{result} 
				. ',' . $engine->{spam}->{runtime}
				. ',' . $engine->{spam}->{cputime}
				. ',' . $engine->{spam}->{runned}

			. ',' . ($engine->{content}->{result}||0)
				. ',' . $engine->{content}->{runtime}
				. ',' . $engine->{content}->{cputime}
				. ',' . $engine->{content}->{runned}
				
			. ',' . $engine->{dynamic}->{result} 
				. ',' . $engine->{dynamic}->{runtime} 
				. ',' . $engine->{dynamic}->{cputime} 
				. ',' . $engine->{dynamic}->{runned}

			. ',' . $engine->{archive}->{result} 
				. ',' . $engine->{archive}->{runtime} 
				. ',' . $engine->{archive}->{cputime} 
				. ',' . $engine->{archive}->{runned}

			. "\n";

		flock(LFD,LOCK_UN);
		close(LFD);
		$self->{last_cputime} = $cputime;

	}else{
		&debug ( "AKA_mail_engine::log open NoSPAM.rrdds failure." );
	}
}

sub log_sa
{
	my $self = shift;
	my $mail_info = shift;

	my $aka = $mail_info->{aka};
	my $engine = $mail_info->{aka}->{engine};

	if ( $engine->{spam}->{sa}->{SCORE} && open ( LFD, ">>/var/log/NoSPAM.sa" ) ){
		flock(LFD,LOCK_EX);
		seek(LFD, 0, 2);
#print LFD strftime("%Y-%m-%d %H:%M:%S", localtime) 
		print LFD "\n" . &get_log_time . " ==================================================\n"
			. "TCPREMOTEIP: " . $aka->{TCPREMOTEIP} . "\n" . "Envelope-From: " . $aka->{returnpath} . "\n"
				. "Recips: " . $aka->{recips} . "\nSubject: " . $aka->{subject} . "\n"

			. "Size: " . $aka->{size} . "\n";

		print LFD Dumper ( $engine->{spam}->{sa} );

		flock(LFD,LOCK_UN);
		close(LFD);
	}


}

END
{
	close(MYLOG);
	close(DEBUG);
	close(FATAL);
}

1;



