#
# 反垃圾判断动态引擎
# Company: AKA Information & Technology Co., Ltd.
# Author: Ed Lee
# EMail: zixia@zixia.net
# Date: 2004-03-07


package AKA::Mail::Dynamic;
use AKA::Mail::Conf;
use AKA::Mail::Log;

#use IPC::Shareable;
use MLDBM::Sync;                       # this gets the default, SDBM_File
use MLDBM qw(DB_File Storable);        # use Storable for serializing
use MLDBM qw(MLDBM::Sync::SDBM_File);  # use extended SDBM_File, handles values > 1024 bytes
use Fcntl qw(:DEFAULT);                # import symbols O_CREAT & O_RDWR for use with DBMs

#use Fcntl;
use Time::HiRes qw(gettimeofday);


sub new
{
	my $class = shift;

	my $self = {};
	bless $self, $class;

	my $parent = shift;

	$self->{parent} = $parent;
	$self->{conf} = $parent->{conf} || new AKA::Mail::Conf;#die "Mail::Conf can't get parent conf!"; 
	$self->{zlog} = $parent->{zlog} || new AKA::Mail::Log;#die "Mail::Conf can't get parent zlog!"; 

	$self->{define}->{size} = 1048576;
	$self->{define}->{glue} = 'SPAM';

	# 在内存中记录的邮件信息保留最长时间
	$self->{define}->{max_time} = 3600;

	$self->{define}->{SendRatePerSubject} = $self->{conf}->{config}->{SendRatePerSubject} || '0/0';
	$self->{define}->{SendRatePerFrom} = $self->{conf}->{config}->{SendRatePerFrom} || '0/0';
	$self->{define}->{ConnRatePerIP} = $self->{conf}->{config}->{ConnRatePerIP} || '0/0';

	$self->{define}->{DBMFILE} = "/home/NoSPAM/var/run/Dynamic.dbm";

	$self->{dynamic_info} = {};

	return $self;
}
sub clean
{
	my $self = shift;

	untie %{$self->{dynamic_info}} if ( $self->{dynamic_info} );

	return unlink $self->{define}->{DBMFILE};
}

sub clean_IPC
{
	my $self = shift;

	$self->attach;

	$self->{ipch}->remove;
	#IPC::Shareable->clean_up_all;
	#IPC::Shareable->clean_up;
}

sub dump
{
	my $self = shift;

	$self->attach;

	use Data::Dumper;
	print Dumper( $self->{dynamic_info} );
}

# 给出subject，察看是否subject超出限制频率
sub is_overrun_rate_per_subject
{
	my $self = shift;

	my $subject = shift;

	if ( ! $subject ){
		$self->{zlog}->debug ( "AKA::Mail::Dynamic::is_overrun_rate_per_subject can't get address." );
		return 0;
	}
	
	my ( $num, $sec );
	$self->{define}->{SendRatePerSubject}=~ m#(\d+)/(\d+)#;
	($num, $sec) = ( $1,$2 );
	
	# 0 or undef means no limit
	return 0 if ( !$num || !$sec );

	# is  overrun?
	return $self->is_overrun_rate_per_XXX ( 'Subject', $subject, $num, $sec );
}

# 给出mail_from，察看是否此address超出限制频率
sub is_overrun_rate_per_mailfrom
{
	my $self = shift;

	my $mail_from = shift;

	if ( ! $mail_from ){
		$self->{zlog}->debug ( "AKA::Mail::Dynamic::is_overrun_rate_per_mailfrom can't get address." );
		return 0;
	}
	
	my ( $num, $sec );
	$self->{define}->{SendRatePerFrom}=~ m#(\d+)/(\d+)#;
	($num, $sec) = ( $1,$2 );

	# 0 or undef means no limit
	return 0 if ( !$num || !$sec );
	
	# is overrun?
	return $self->is_overrun_rate_per_XXX ( 'From', $mail_from, $num, $sec );
}

# 给出ip，察看是否此ip超出限制频率
sub is_overrun_rate_per_ip
{
	my $self = shift;

	my $ip = shift;

	if ( ! $ip ){
		$self->{zlog}->debug ( "AKA::Mail::Dynamic::is_overrun_rate_per_ip can't get ip." );
		return 0;
	}
	
	my ( $num, $sec );
	$self->{define}->{ConnRatePerIP}=~ m#(\d+)/(\d+)#;
	($num, $sec) = ( $1,$2 );
	
	# 0 or undef means no limit
	return 0 if ( !$num || !$sec );

	# is overrun?
	return $self->is_overrun_rate_per_XXX ( 'IP', $ip, $num, $sec );
}


# 在 param1 为名的数组中，已 param2 为 key， 察看是否在 param4 秒内， param2 的 value 数目超过 param3
sub is_overrun_rate_per_XXX
{
	my $self = shift;

	my ( $namespace, $key, $num, $sec ) = @_;

	# 0 means unlimited
	return 0 if ( defined $num && defined $sec && ( 0==$num || 0==$sec ) );

	if ( ! $namespace || ! $key || ! $num || ! $sec ){
		$self->{zlog}->debug ( "AKA::Mail::Dynamic::is_overrun_rate_per_XXX can't get params: [" . join(" ",@_) . "]" );
		return 0;
	}

	# zero means UNLIMITED
	return 0 if ( 0==$num || 0==$sec );

	# 限制最长时间不大于1Hour
	$sec = $self->{define}->{max_time} if ( $sec > $self->{define}->{max_time} );

	if ( ! $self->attach ){
		$self->{zlog}->fatal ( "AKA::Mail::Dynamic::is_overrun_rate_per_XXX can't attach" );
		return 0;
	}

	$self->{sh}->SyncCacheSize('100K'); 
	$self->lock_DBM;

	my $namespace_obj = $self->{dynamic_info}->{$namespace};
	$namespace_obj->{'_LAST_REFRESH_TIME_'} ||= 0;
	$self->{dynamic_info}->{$namespace} = $namespace_obj;

	# 每2分钟清理一下内存 XXX
	if ( time - $namespace_obj->{'_LAST_REFRESH_TIME_'} > 120 ){
		$self->refresh_info( $namespace, $sec );
		$namespace_obj = $self->{dynamic_info}->{$namespace};
		$namespace_obj->{'_LAST_REFRESH_TIME_'} = time;
		$self->{dynamic_info}->{$namespace} = $namespace_obj;
	}

	# 将数据保存起来备查
	$self->add_dynamic_info( $namespace, $key );

	# 检查是否超过限额
	my $overrun = $self->check_quota_exceed( $namespace, $key, $num );

	$self->unlock_DBM;

	return $overrun;
}	

sub refresh_info
{
	my $self = shift;

	my ( $namespace, $sec ) = @_;

	if ( ! $namespace || ! $sec ){
		$self->{zlog}->debug ( "AKA::Mail::Dynamic::refresh_info can't get params: [" . join("",@_) . "]" );
		return 0;
	}

	my $key;
	my ( $secmic, $seconds );
	my ( $val_count );

	my $ns_obj = $self->{dynamic_info}->{$namespace};
#print STDERR "refresh_bad_ip: check $ns_obj\n";
       	foreach $key ( keys %{$ns_obj} ){
#print STDERR "refresh_bad_ip: check $key\n";
                foreach $secmic ( keys %{$ns_obj->{$key}} ){
#print STDERR "refresh_bad_ip: check $key $secmic\n";
                        if ( $secmic =~ /^(\d+)\.(\d+)$/ ){
                                $seconds = $1;

                                if ( time - $seconds > $sec ){
                                        delete $ns_obj->{$key}->{$secmic} ;
#print STDERR "refresh_bad_ip: delete badlist $key $secmic\n";
                                }
                        }else{
				$self->{zlog}->debug ( "AKA::Mail::Dynamic::refresh_info found a val not sec.mic format: [$secmic]" );
			}
                }

                $val_count = keys %{$ns_obj->{$key}};
                if ( 0==$val_count ) {
                        delete $ns_obj->{$key};
                }
        }
	
	$self->{dynamic_info}->{$namespace} = $ns_obj;

	return 1;
}

sub add_dynamic_info
{
        my $self = shift;

	my ($namespace,$key) = @_;

	if ( ! $namespace || ! $key ){
		$self->{zlog}->debug ( "AKA::Mail::Dynamic::add_dynamic_info can't get params: [" . join("",@_) . "]" );
		return 0;
	}

        ($seconds, $microseconds) = gettimeofday;

	my $ns_obj = $self->{dynamic_info}->{$namespace};
	$ns_obj->{$key}->{$seconds . '.' . $microseconds} = 1;
	$self->{dynamic_info}->{$namespace} = $ns_obj;
#print STDERR "add_bad_ip: $namespace, $key\n";
}

sub check_quota_exceed
{
	my $self = shift;

	# no need to sec, because we already delete older items before sec second.
	my ( $namespace, $key, $num ) = @_;;

	if ( ! $namespace || ! $key || ! $num){
		$self->{zlog}->debug ( "AKA::Mail::Dynamic::check_quota_exceed can't get params: [" . join("",@_) . "]" );
		return 0;
	}

	my $num_counter;

	my $ns_obj = $self->{dynamic_info}->{$namespace};
        $num_counter = keys ( %{$ns_obj->{$key}} );

#print STDERR "check_bad_ip: key $key has $num_counter times actions ... \n";

        if ( $num_counter > $num ) {
		# limit OVERRUN! EXCEED!
		return 1;
        }

	# we still have quota!
	return 0;
}

sub attach
{
	my $self = shift;

	return 1 if ( $self->{sh} && $self->{dynamic_info} );

	$self->{sh} = tie %{$self->{dynamic_info}}, 'MLDBM::Sync', $self->{define}->{DBMFILE}, O_CREAT|O_RDWR, 0640 ;

	if ( ! $self->{sh} ){
		return 0;
	}

	return 1;
}

sub attach_IPC
{
	my $self = shift;

	my $create = shift || '';

	return 1 if ( $self->{ipch} && $self->{dynamic_info} );

	my %options = ( 
			create    => '',
			exclusive => '',
			mode      => '',
			destroy   => '',
			size      => '',
		      );

	eval {
		$self->{ipch} = tie %{$self->{dynamic_info}}, 'IPC::Shareable', $self->{define}->{glue}, { %options };
	}; 
	if ( $@ ) {
		if ( $create ){
			$options{create} = 'yes';
			$options{size} = $self->{define}->{size};
			$options{mode} = 0640;
			eval {
				$self->{ipch} = tie %{$self->{dynamic_info}}, 
							'IPC::Shareable', 
							$self->{define}->{glue}, 
							{ %options };
			};
			if ( $@ ){
				$self->{zlog}->fatal ( "AKA::Mail::Dynamic attach & create failed!" );
				return 0;
			}
			$self->{zlog}->log ( "AKA::Mail::Dynamic attach & create " . $options{size} . " bytes memory!" );
			# create ok!
		}else{
			$self->{zlog}->fatal ( "AKA::Mail::Dynamic attach failed!" );
			return 0;
		}
	}

	# attach succ!
	return 1;
}

sub detach
{
	my $self = shift;

	#XXX
	untie ( %{$self->{dynamic_info}} );
	return 1;
}

sub lock_DBM_r
{
	my $self = shift;

	return $self->{sh}->ReadLock;
}

sub lock_DBM
{
	my $self = shift;

	return $self->{sh}->Lock;
}

sub unlock_DBM
{
	my $self = shift;

	return $self->{sh}->UnLock
}


sub lock_IPC
{
	my $self = shift;

	return $self->{ipch}->shlock;
}

sub unlock_IPC
{
	my $self = shift;

	return $self->{ipch}->shunlock;
}

sub test
{
	my $self = shift;

	# TODO check mem usage
	eval {
		$self->{dynamic_info}->{zixia} .= 'o'; 
	}; $@ and die "ohhh... $@\n";

	foreach ( keys %{$self->{dynamic_info}} ){
		print "$_ => " . $self->{dynamic_info}->{$_} . "\n";
	}

	return 1;
}

1;



