#
# noSPAM Quarantine
# Company: AKA Information & Technology Co., Ltd.
# Author: Ed Li
# EMail: zixia@zixia.net
# Date: 2004-07-25


package AKA::Mail::Quarantine;


use AKA::Mail::Conf;
use AKA::Mail::Log;
use AKA::Mail::Controler;
use AKA::Mail::DB;

sub new
{
	my $class = shift;

	my $self = {};

	bless $self, $class;

	my $parent = shift;

	$self->{parent} = $parent;
	$self->{conf} = $parent->{conf} || new AKA::Mail::Conf;
	$self->{zlog} = $parent->{zlog} || new AKA::Mail::Log;
	
	$self->{define}->{quarantinedir} = $self->{conf}->{define}->{quarantine_dir} || '/home/NoSPAM/Quarantine';
	$self->{define}->{sysdir} = "nospam";
	return $self;
}

# $MailFile, MailFrom, $MailTo, $QuarantineType, $QuarantineReason, 
sub quarantine
{
	my $self = shift;
	my ($q_type, $mailfile,$mailfrom,$mailto,$subject, $size, $q_reason, $q_desc) = @_;

	my $qdir = $self->{define}->{quarantinedir};
	my $sdir = $self->{define}->{sysdir};

	my $old_umask = umask 0022;
	my ($filename, $infoname);
#$self->{zlog}->debug ( "Quarantine::quarantine get mailfrom: [$mailfrom] mailto: [$mailto]" );
	$mailfile =~ m#([^/]+)$#;
	$filename = $1;
	$infoname = "$1.info";

	if ( $q_type eq AKA::Mail::Conf::QUARANTINE_ADMIN ){
		my $info_content = $self->make_info_content($mailfrom,$mailto,$subject,$size,$q_reason,$q_desc);
		if ( open ( FD, ">$qdir/$sdir/$infoname" ) ){
			print FD $info_content;
			close FD;
			link ($mailfile, "$qdir/$sdir/$filename");
			unlink ($mailfile);
		}else{
			$self->{zlog}->fatal ( "Mail::Quarantine::quarantine write info file [$qdir/$sdir/$infoname] error." );
			return undef;
		}
	}elsif ( $q_type eq AKA::Mail::Conf::QUARANTINE_USER ){
		my ($user,$domain);
		my ($single_mailto);
		foreach ( split(/,/,$mailto) ){ 
			$single_mailto = $_;
			if ( $single_mailto=~/(\S+)\@(\S+)/ ){
				($user,$domain) = (lc $1,lc $2);
			}else{
				$self->{zlog}->fatal ( "AKA::Mail::Quarantine::quarantine can't parse email address: [$single_mailto]" );
				next;
			}

			mkdir "$qdir/$domain" unless ( -d "$qdir/$domain" );
			mkdir "$qdir/$domain/$user" unless ( -d "$qdir/$domain/$user" );

			my $info_content = $self->make_info_content($mailfrom,$single_mailto,$subject,$size,$q_reason,$q_desc);
			if ( open ( FD, ">$qdir/$domain/$user/$infoname" ) ){
				print FD $info_content;
				close FD;
			}else{
				$self->{zlog}->fatal ( "Mail::Quarantine::quarantine write info file [$qdir/$domain/$user/$infoname] error." );
				return undef;
			}
			link ($mailfile, "$qdir/$domain/$user/$filename");
		}
		unlink ($mailfile);
	}else{
		$self->{zlog}->fatal ( "Mail::Quarantine::quarantine got unknown q_type: [$q_type]" );
		return undef;
	}
}

sub make_info_content
{
	my $self = shift;
	
	my ($from,$to,$subject,$size,$reason,$desc) = @_;

	my $info_content = "$from\n$to\n$subject\n$size\n$reason\n$desc";;
	return $info_content;
}
sub get_quarantine_info
{
	my $file = shift;

	my $info = {}; 
	if ( open (FD,"<$file.info") ){
		$info->{from} = <FD>; chomp $$info->{from};
		$info->{to} = <FD>; chomp $info->{to};
		$info->{subject} = <FD>; chomp $info->{subject};
		$info->{size} = <FD>; chomp $info->{size};
		$info->{reason} = <FD>; chomp $info->{reason};
		$info->{desc} = <FD>; chomp $info->{desc};
		close FD;
		return $info;
	}else{
		$zlog->fatal ( "wi QuarantineProcessMail::_get_quarantine_info can't open file [$file]" );
		return undef;
	}
}

1;


