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
	$self->{define}->{SyncCacheSize} = '100K';
	# 清除过期记录的时间间隔，秒为单位
	$self->{define}->{clean_interval} = 600;
	# 封禁最长时间：一天
	$self->{define}->{max_deny_time} = 86400;
	# 封禁最长时间：一天
	# 缺省超限封禁时间：1Hour
	$self->{define}->{DefaultDenyTime} = 600;

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

	my $namespace;
	foreach $namespace ( keys %{$self->{dynamic_info}} ){
		printf "$namespace: %d entris\n", scalar keys %{$self->{dynamic_info}->{$namespace}};
	}

}

# 给出subject，察看是否subject超出限制频率
sub is_overrun_rate_per_subject
{
	my $self = shift;

	my $subject = shift;

	if ( ! $subject ){
		$self->{zlog}->debug ( "AKA::Mail::Dynamic::is_overrun_rate_per_subject can't get address." );
		return (0,'无参数');
	}
	
	my ( $num, $sec, $deny_sec );
	$self->{define}->{SendRatePerSubject}=~ m#(\d+)/(\d+)/(\d+)#;
	$self->{define}->{SendRatePerSubject}=~ m#(\d+)/(\d+)#
                unless ( defined $3 );
	($num, $sec, $deny_sec) = ( $1,$2,$3 );
	
	# 0 or undef means no limit
	return (0,'引擎未配置') if ( !defined $num || !defined $sec );

	# is  overrun?
	return $self->is_overrun_rate_per_XXX ( 'Subject', $subject, $num, $sec, $deny_sec );
}

# 给出mail_from，察看是否此address超出限制频率
sub is_overrun_rate_per_mailfrom
{
	my $self = shift;

	my $mail_from = shift;

	if ( ! $mail_from ){
		$self->{zlog}->debug ( "AKA::Mail::Dynamic::is_overrun_rate_per_mailfrom can't get address." );
		return (0,'无参数');
	}
	
	my ( $num, $sec, $deny_sec );

	$self->{define}->{SendRatePerFrom}=~ m#(\d+)/(\d+)/(\d+)#;
	$self->{define}->{SendRatePerFrom}=~ m#(\d+)/(\d+)#
                unless ( defined $3 );
	($num, $sec, $deny_sec) = ( $1,$2,$3 );

	# 0 or undef means no limit
	return (0,'引擎未配置') if ( !defined $num || !defined $sec );
	
	# is overrun?
	return $self->is_overrun_rate_per_XXX ( 'From', $mail_from, $num, $sec, $deny_sec );
}

# 给出ip，察看是否此ip超出限制频率
sub is_overrun_rate_per_ip
{
	my $self = shift;

	my $ip = shift;

	if ( ! $ip ){
		$self->{zlog}->debug ( "AKA::Mail::Dynamic::is_overrun_rate_per_ip can't get ip." );
		return (0,'无参数');
	}
	
	my ( $num, $sec, $deny_sec );
	$self->{define}->{ConnRatePerIP}=~ m#(\d+)/(\d+)/(\d+)#;
	$self->{define}->{ConnRatePerIP}=~ m#(\d+)/(\d+)# 
		unless ( defined $3 );
	($num, $sec, $deny_sec) = ( $1,$2,$3 );
	
	# 0 or undef means no limit
	return (0,'引擎未配置') if ( ! defined $num || ! defined $sec );

	# is overrun?
	return $self->is_overrun_rate_per_XXX ( 'IP', $ip, $num, $sec, $deny_sec );
}


# 在 param1 为名的数组中，已 param2 为 key， 察看是否在 param4 秒内， param2 的 value 数目超过 param3
sub is_overrun_rate_per_XXX
{
	my $self = shift;

	my ( $namespace, $key, $num, $sec, $deny_sec ) = @_;
	$deny_sec ||= $self->{define}->{DefaultDenyTime};

	# 0 means unlimited
	return (0,'通过动态检测') if ( defined $num && defined $sec && ( 0==$num || 0==$sec ) );

	# zero means UNLIMITED
	#return (0,'无限制') if ( 0==$num || 0==$sec );

	if ( ! $namespace || ! $key || ! $num || ! $sec ){
		$self->{zlog}->debug ( "AKA::Mail::Dynamic::is_overrun_rate_per_XXX can't get params: [" . join(" ",@_) . "]" );
		return (0,'引擎参数不足');
	}


	# 限制最长时间不大于1Hour
	$sec = $self->{define}->{max_time} if ( $sec > $self->{define}->{max_time} );

	if ( ! $self->attach ){
		$self->{zlog}->fatal ( "AKA::Mail::Dynamic::is_overrun_rate_per_XXX can't attach" );
		return (0,'引擎加载失败');
	}

	# protect our timer
	$key = '__AMD_LAST_REFRESH_TIME__' if ( $key eq '_AMD_LAST_REFRESH_TIME_' );

	$self->lock_DBM;
	$self->{sh}->SyncCacheSize( $self->{define}->{SyncCacheSize}||'100K' ); 

	my $namespace_obj = $self->{dynamic_info}->{$namespace};
	$namespace_obj->{'_AMD_LAST_REFRESH_TIME_'} ||= 0;

	# 最大每clean_interval s 清理一下内存
	if ( time - $namespace_obj->{'_AMD_LAST_REFRESH_TIME_'} > $self->{define}->{clean_interval} ){
		$namespace_obj = $self->refresh_info( $namespace_obj, $sec );
		# do this out of circle
		#$namespace_obj = $self->{dynamic_info}->{$namespace};
		$namespace_obj->{'_AMD_LAST_REFRESH_TIME_'} = time;
		#$self->{dynamic_info}->{$namespace} = $namespace_obj;
	}


	# 将数据保存起来备查 
	# $namespace_obj 传递的 is reference, so modify in add_Dynamic_info function will effect in this namespace
	$self->add_dynamic_info( $namespace_obj, $key );

	# 检查是否超过限额
	my ($overrun,$reason) = $self->check_quota_exceed_ex( $namespace_obj, $key, $num, $sec, $deny_sec );

	$self->{dynamic_info}->{$namespace} = $namespace_obj;

	$self->unlock_DBM;

	return ($overrun,$reason);
}	

sub refresh_info
{
	my $self = shift;

	my ( $namespace_obj, $sec ) = @_;

	if ( ! $namespace_obj || ! $sec ){
		$self->{zlog}->debug ( "AKA::Mail::Dynamic::refresh_info can't get params: [" . join("",@_) . "]" );
		return 0;
	}

	my $key;
	my ( $secmic, $seconds );
	my ( $val_count );

#print STDERR "refresh_bad_ip: check $ns_obj\n";
       	foreach $key ( keys %{$namespace_obj} ){
#print STDERR "refresh_bad_ip: check $key\n";
                foreach $secmic ( keys %{$namespace_obj->{$key}} ){
#print STDERR "refresh_bad_ip: check $key $secmic\n";
                        if ( $secmic =~ /^(\d+)\.(\d+)$/ ){
                                if ( time - $1 > $sec ){
                                        delete $namespace_obj->{$key}->{$secmic} ;
#print STDERR "refresh_bad_ip: delete badlist $key $secmic\n";
                                }
                        }else{
				$self->{zlog}->debug ( "AKA::Mail::Dynamic::refresh_info found a val not sec.mic format: [$secmic]" );
			}
                }

                $val_count = keys %{$namespace_obj->{$key}};
                if ( 0==$val_count ){
                        delete $namespace_obj->{$key};
		}elsif (1==$val_count &&
				defined $namespace_obj->{$key}->{_DENY_TO_} 
			) {
                        delete $namespace_obj->{$key};
                }
        }
	
	#$self->{dynamic_info}->{$namespace} = $ns_obj;

	return $namespace_obj;
}

sub add_dynamic_info
{
        my $self = shift;

	my ($namespace_obj,$key) = @_;

	if ( ! $namespace_obj || ! $key ){
		$self->{zlog}->debug ( "AKA::Mail::Dynamic::add_dynamic_info can't get params: [" . join("",@_) . "]" );
		return 0;
	}

        ($seconds, $microseconds) = gettimeofday;

	$namespace_obj->{$key}->{$seconds . '.' . $microseconds} = 1;

	# no need to return this, because this is a reference, and the modify of it should effect the parent function.
	#return $namespace_obj;
#print STDERR "add_bad_ip: $namespace, $key\n";
}

# 检查给定时间内的记录数目，可能会影响性能
sub check_quota_exceed_ex
{
	my $self = shift;

	my ( $namespace_obj, $key, $num, $sec, $deny_sec ) = @_;;

	if ( ! $namespace_obj || ! $key || ! $num || ! $sec || ! $deny_sec){
		$self->{zlog}->debug ( "AKA::Mail::Dynamic::check_quota_exceed can't get params: [" . join("",@_) . "]" );
		return (0,'参数不足 ');
	}

	my $ns_obj_who = $namespace_obj->{$key};

	if ( defined $ns_obj_who->{_DENY_TO_} ){
		my $wait_time = $ns_obj_who->{_DENY_TO_} - time;
		if( $wait_time > 0 ){
			# change to minute
			# 由于超额，还没到被解封时间，仍然返回OVERRUN，并且增加封禁时间
			if ( $wait_time > $self->{define}->{max_deny_time} ){
				$ns_obj_who->{_DENY_TO_} = time + $self->{define}->{max_deny_time};
				$wait_time = $self->{define}->{max_deny_time};
			}else{
				$ns_obj_who->{_DENY_TO_} += $deny_sec;
				$wait_time += $deny_sec;
			}

			$wait_time = int($wait_time/60);
			return (1, "发送超限，还需$wait_time分钟解封");
		}else{
			delete $ns_obj_who->{_DENY_TO_};
		}
	}

	my $num_counter = 0;
       	foreach ( keys %{$ns_obj_who} ){
               if ( /^(\d+)\.(\d+)$/ ){
                        if ( time - $1 < $sec ){
				$num_counter++;
                        }
                }else{
			$self->{zlog}->debug ( "AKA::Mail::Dynamic::refresh_info found a val not sec.mic format: [$_]" );
		}
        }
	
        if ( $num_counter > $num ) {
		# limit OVERRUN! EXCEED!
		$ns_obj_who->{_DENY_TO_} = time+$deny_sec;
		return (1,'发送超限');;
        }

	# we still have quota!
	return (0,'通过动态检测');
}


# 检查 DynamicInfo 中所有记录的数目，可能性能会好一些
sub check_quota_exceed
{
	my $self = shift;

	# no need to sec, because we already delete older items before sec second.
	my ( $namespace_obj, $key, $num, $sec ) = @_;;

	if ( ! $namespace_obj || ! $key || ! $num || ! $sec){
		$self->{zlog}->debug ( "AKA::Mail::Dynamic::check_quota_exceed can't get params: [" . join("",@_) . "]" );
		return 0;
	}

	my $num_counter;

        $num_counter = keys ( %{$namespace_obj->{$key}} );

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

sub get_dynamic_info_ns_name
{
	my $self = shift;

	$self->attach;

	return keys %{$self->{dynamic_info}};
}

sub get_dynamic_info_ns_data
{
	my $self = shift;
	my $ns = shift;

	$self->attach;

	return $self->{dynamic_info}->{$ns};
}

sub del_dynamic_info_ns_item
{
	my $self = shift;
	my ($ns,$item) = @_;

	return undef unless ( $ns && $item );

	$self->attach;

	$self->lock_DBM;

	my $ns_obj = $self->{dynamic_info}->{$ns};
	delete 	$ns_obj->{$item};
	$self->{dynamic_info}->{$ns} = $ns_obj;

	$self->unlock_DBM;
	
	return 1;
}

sub clean_dynamic_info_ns
{
	my $self = shift;
	my $ns = shift;

	return undef unless ( $ns );

	$self->attach;

	$self->lock_DBM;

	my $ns_obj = $self->{dynamic_info}->{$ns};
	$ns_obj = {};
	$self->{dynamic_info}->{$ns} = $ns_obj;

	$self->unlock_DBM;
	
	return 1;
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



