#
# 反垃圾判断动态引擎
# Company: AKA Information & Technology Co., Ltd.
# Author: Ed Lee
# EMail: zixia@zixia.net
# Date: 2004-03-07


package AKA::Mail::Dynamic;
use AKA::Mail::Conf;
use AKA::Mail::Log;

use IPC::Shareable;
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

	return $self;
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
	
	# is overrun?
	return $self->is_overrun_rate_per_XXX ( 'From', $mail_from, $num, $sec );
}

# 在 param1 为名的数组中，已 param2 为 key， 察看是否在 param4 秒内， param2 的 value 数目超过 param3
sub is_overrun_rate_per_XXX
{
	my $self = shift;

	my ( $namespace, $key, $num, $sec ) = @_;

	# 0 means unlimited
	return 0 if ( defined $num && defined $sec && 0==$num && 0==$sec );

	if ( ! $namespace || ! $key || ! $num || ! $sec ){
		$self->{zlog}->debug ( "AKA::Mail::Dynamic::is_overrun_rate_per_XXX can't get params: [" . join("",@_) . "]" );
		return 0;
	}

	# zero means UNLIMITED
	return 0 if ( 0==$num || 0==$sec );

	if ( ! $self->attach ){
		$self->{zlog}->fatal ( "AKA::Mail::Dynamic::is_overrun_rate_per_XXX can't attach" );
		return 0;
	}

	$self->lock;

	# 每2分钟清理一下内存 XXX
	$self->{dynamic_info}->{$namespace}->{'_LAST_REFRESH_TIME_'} ||= 0;
	if ( time - $self->{dynamic_info}->{$namespace}->{'_LAST_REFRESH_TIME_'} > 120 ){
		$self->refresh_info( $namespace, $sec );
		$self->{dynamic_info}->{$namespace}->{'_LAST_REFRESH_TIME_'} = time;
	}

	# 将数据保存起来备查
	$self->add_dynamic_info( $namespace, $key );

	# 检查是否超过限额
	my $overrun = $self->check_quota_exceed( $namespace, $key, $num );

	$self->unlock;

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

       	foreach $key ( keys %{$self->{dynamic_info}->{$namespace}} ){
#print STDERR "refresh_bad_ip: check $key\n";
                foreach $secmic ( keys %{$self->{dynamic_info}->{$namespace}->{$key}} ){
#print STDERR "refresh_bad_ip: check $key $secmic\n";
                        if ( $secmic =~ /^(\d+)\.(\d+)$/ ){
                                $seconds = $1;

                                if ( time - $seconds > $sec ){
                                        delete $self->{dynamic_info}->{$namespace}->{$key}->{$secmic} ;
#print STDERR "refresh_bad_ip: delete badlist $key $secmic\n";
                                }
                        }else{
				$self->{zlog}->debug ( "AKA::Mail::Dynamic::refresh_info found a val not sec.mic format: [$secmic]" );
			}
                }

                $val_count = keys %{$self->{dynamic_info}->{$namespace}->{$key}};
                if ( 0==$val_count ) {
                        delete $self->{dynamic_info}->{$namespace}->{$key};
                }
        }
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

        $self->{dynamic_info}->{$namespace}->{$key}->{$seconds . '.' . $microseconds} = 1;
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

        $num_counter = keys ( %{$self->{dynamic_info}->{$namespace}->{$key}} );

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

	return 1 if ( $self->{ipch} && $self->{dynamic_info} );

	my %options = ( 
			create    => 'yes',
			exclusive => '',
			mode      => 0644,
			destroy   => '',
			size      => $self->{define}->{size},
		      );

	if ( ! ($self->{ipch} = tie %{$self->{dynamic_info}}, 'IPC::Shareable', $self->{define}->{glue}, { %options }) ){
		$self->{zlog}->fatal ( "AKA::Mail::Dynamic attach failed!" );
		return 0;
	}

	# attach succ!
	return 1;
}

sub detach
{
	my $self = shift;

	#XXX
	#untie ( %{$self->{dynamic_info}} );
	return 1;
}


sub lock
{
	my $self = shift;

	return $self->{ipch}->shlock;
}

sub unlock
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



