#
# 邮件网关引擎总管
# Company: AKA Information & Technology Co., Ltd.
# Author: Ed Lee
# EMail: zixia@zixia.net
# Date: 2004-03-07


package AKA::Mail;
use strict;

use Locale::TextDomain ('engine.nospam.cn');

use MIME::Base64; 
use MIME::QuotedPrint; 
use Time::HiRes qw( usleep ualarm gettimeofday tv_interval );
use Errno;
use IO::Socket;
use POSIX ();

use Data::Dumper;
use POSIX qw(:signal_h :errno_h :sys_wait_h);

use AKA::License;
use AKA::Mail::Conf;
use AKA::Mail::Log;

use AKA::Mail::AntiVirus;
use AKA::Mail::Spam;
use AKA::Mail::Content;
use AKA::Mail::Dynamic;

use AKA::Mail::Archive;

use constant	{
	RESULT_SPAM_NOT		=>	0,
	RESULT_SPAM_MAYBE	=>	1,
	RESULT_SPAM_MUST	=>	2,
	RESULT_SPAM_BLACK	=>	3,

	ACTION_PASS		=>	0,
	
	# main process func impl
	ACTION_REJECT		=>	1,
	ACTION_DISCARD		=>	2,
	ACTION_QUARANTINE	=>	3,

	ACTION_STRIP		=>	4,
	ACTION_DELAY		=>	5,

	ACTION_NULL		=>	6,
	ACTION_ACCEPT		=>	7,

	# in main process 
	ACTION_ADDRCPT		=>	8,
	ACTION_DELRCPT		=>	9,
	ACTION_CHGRCPT		=>	10,

	# qmail_rqueue impl
	ACTION_ADDHDR		=>	11,
	ACTION_DELHDR		=>	12,
	ACTION_CHGHDR		=>	13
	
};

sub new
{
	my $class = shift;

	my $self = {};

	bless $self, $class;

	my $parent = shift;

	$self->{license} = new AKA::License;

	$self->{conf} = new AKA::Mail::Conf($self);
	$self->{zlog} = new AKA::Mail::Log($self);


	$self->{antivirus} 	= new AKA::Mail::AntiVirus($self);
	$self->{spam} 		= new AKA::Mail::Spam($self);

	if ( 'Y' eq uc $self->{conf}->{config}->{SpamEngine}->{SmartEngine} ){
		eval "use AKA::Mail::SA;";
		if ( $@ ){
			$self->{zlog}->fatal ( "Mail::SA use AKA::Mail::SA failure: $@" );
		}
		$self->{sa}	= new AKA::Mail::SA($self, 1);
	}

	$self->{dynamic} 	= new AKA::Mail::Dynamic($self);
	$self->{content} 	= new AKA::Mail::Content($self);
	$self->{archive} 	= new AKA::Mail::Archive($self);

	($self->{license_ok},$self->{license_html}) = $self->check_license_file();

	$self->{conffile_list}->{conffile} = $self->{conf}->{define}->{conffile};	# NoSPAM.conf
	$self->{conffile_list}->{intconffile} = $self->{conf}->{define}->{intconffile};	# NoSPAM.intconf
	$self->{conffile_list}->{license} = $self->{conf}->{define}->{licensefile};	# License.dat
	$self->{conffile_list}->{filterdb} = $self->{content}->{content_conf}->{define}->{filterdb};	# PoliceDB.xml
	$self->{conffile_list}->{user_filterdb} = $self->{content}->{content_conf}->{define}->{user_filterdb};	# UserFilterDB.xml
	$self->{conffile_list}->{upgrade_log} = $self->{conf}->{define}->{upgrade_log};	# upgrade log
	$self->{conffile_list}->{SpamAssassin} = "/etc/mail/spamassassin/local.cf";

	$self->check_conffile_update();

	return $self;

}

sub get_language
{
	return shift->{conf}->{licconf}->{Language} || 'zh_CN';
}

sub server
{
	my $self = shift;

#XXX test
=pod
	local $SIG{CHLD} = 'IGNORE';
	my $counter = 0;
	while ( 1 ){
		my $pid = fork;
		if ( $pid == 0 ){ #child
			$self->{zlog}->debug ( "child $$ exist" );	
			#for ( my $i=0;$i<100000; $i++ ){
			#	$i=$i+2;
			#	$i--;
			#}
			select(undef, undef, undef, 0.25);
			exit;
		}elsif ( $pid < 0 ){
			exit;
		}
		$self->{zlog}->debug ( "parent forked $pid" );	
		$counter ++;
		exit 0 if $counter > 100;
	}
=cut

#	my $server = new IO::Socket::INET( LocalAddr => '127.0.0.1',
#					LocalPort => '40307',
#					Proto => 'tcp',
#					Type => SOCK_STREAM,
#					ReuseAddr => 1,
#					Listen => SOMAXCONN
#			) || sleep 1 && die "Could not create INET socket: $! $@\n";

	if ( new IO::Socket::UNIX ( Type => 'SOCK_STREAM'
					, Peer => '/home/NoSPAM/.ns'
					, Type => SOCK_STREAM 
				) ){
		sleep 1 && die "UNIX socket already in use!\n";
	}

	unlink '/home/NoSPAM/.ns';

	my $server = new IO::Socket::UNIX( Type => 'SOCK_STREAM'
					, Local => '/home/NoSPAM/.ns'
					, Type => SOCK_STREAM
					, Listen => SOMAXCONN
			) || sleep 1 && die "Could not create UNIX socket: $! $@\n";




	my $client;
	my $pid;

	$self->{zlog}->debug ( "Mail::server start to listen" );
	#local $SIG{CHLD} = \&{$self->reaper};
	local $SIG{CHLD} = 'IGNORE';
	while ( $client = $server->accept() ){
		$self->{start_time} = [gettimeofday];

#XXX
#$self->net_process($client);
#shutdown ( $client, 2 );
#close $client;
#next;
		if (!$client) {
		# this can happen when interrupted by SIGCHLD on Solaris,
		# perl 5.8.0, and some other platforms with -m.
			if ($! == &Errno::EINTR) {
				next;
			} else {
				# daemontools should restart me
				die "accept failed: $!\n";
			}
		}
		$pid = fork();

		if ( $pid > 0 ){ #parent
			close $client;
			# 如果检查到配置文件更新，则直接退出，由supervise负责重起
			if ( $self->check_conffile_update() ){
				shutdown ( $server, 2 );
				close $server;
				#kill 9, $$;
				exit;
			}
			; # goto accept
		}elsif ( 0==$pid ){ # child
			close $server;

#$self->{zlog}->debug ( "pid $$ process $client");
			$self->net_process($client);
			shutdown ( $client, 2 );
			close $client;
			exit;
		}else{ #err
			shutdown ( $server, 2 );
			shutdown ( $client, 2 );
			close $server;
			close $client;
			$self->{zlog}->fatal ( "Mail::server fork return < 0? [$pid] exiting..." );
			die "fork failed: $!\n";
		}
	}
}

sub reaper {
	my $self = shift;

	my $pid;

	$pid = waitpid(-1, &WNOHANG);

	if ($pid == -1) {
# no child waiting.  Ignore it.
	} elsif (WIFEXITED($?)) {
		print "Process $pid exited.\n";
	} else {
		print "False alarm on $pid.\n";
	}
	$SIG{CHLD} = \&reaper;          # in case of unreliable signals
}



sub check_conffile_update
{
	my $self = shift;

	my $mtime;
	foreach my $conf_name ( keys %{$self->{conffile_list}} ){
		if ( ! $self->{load_time}->{$conf_name} ){
			$self->{zlog}->debug ( "Mail::check_conffile_update init $conf_name => " 
				. $self->{conffile_list}->{$conf_name} . " load time" );
			$self->{load_time}->{ $conf_name } = time;
		}else{
			$mtime = (stat( $self->{conffile_list}->{$conf_name} ))[9];
			if ( $mtime > $self->{load_time}->{$conf_name} ){
				# 如果文件比加载时刻新
				if ( $mtime > time ){
					# 文件修改时间是未来？
					$self->{zlog}->debug ( "Mail::check_conffile_update found $conf_name => " 
						. $self->{conffile_list}->{$conf_name} 
						. " modified in the feature? update it to now" );
					utime undef, undef, $self->{conffile_list}->{$conf_name};
				}

				$self->{zlog}->debug ( "Mail::check_conffile_update found $conf_name => " 
					. $self->{conffile_list}->{$conf_name} . " updated!" );
				return 1;
			}
	
		}
	}
	return 0;
}

sub recv_mail_info_ex
{
	my $self = shift;

my $logstr;
	$_ = <STDIN>; s/\r|\r\n|\n//g;
$logstr .= "RELAYCLIENT: [$_]\n";
	$self->{mail_info}->{aka}->{RELAYCLIENT} = $_;

	$_ = <STDIN>; s/\r|\r\n|\n//g;
$logstr .= "TCPREMOTEIP: [$_]\n";
	$self->{mail_info}->{aka}->{TCPREMOTEIP} = $_;

	$_ = <STDIN>; s/\r|\r\n|\n//g;
$logstr .= "TCPREMOTEINFO: [$_]\n";
	$self->{mail_info}->{aka}->{TCPREMOTEINFO} = $_;

	$_ = <STDIN>; s/\r|\r\n|\n//g;
$logstr .= "emlfilename: [$_]\n";
	$self->{mail_info}->{aka}->{emlfilename} = $_;

	$_ = <STDIN>; s/\r|\r\n|\n//g;
	$self->{mail_info}->{aka}->{fd1} = $_;
s/\0/\\0/g;
$logstr .= "fd1: $_\n";

#$self->{zlog}->debug ( $logstr );

	$self->{mail_info};
}

# 2004-05-25
# use Net::Server, socket io is STDIN/STDOUT
sub net_process_ex
{
	my $self = shift;

	# 重新初始化；
	$self->{mail_info} = {};
	        
    # reset SIGCHLD to SIG_DFL, so that we can use system(), open ("foo|"),
    # etc. etc. and get their exit statuses correctly.  This is the child
    # process now, so this won't affect SIGCHLD in the parent, which still
    # needs SIG_IGN to avoid leaving zombies.
    $SIG{CHLD} = 'DEFAULT';

	$self->recv_mail_info_ex();

#use Data::Dumper;

#$self->{zlog}->debug ( "after recv_mail_info_ex" );
	$self->process ( $self->{mail_info} );
#$self->{zlog}->debug ( "after process" );
#print ZZZ Dumper($self->{mail_info} );
#close ZZZ;
	$self->send_mail_info_ex();
#$self->{zlog}->debug ( "after send_mail_info_ex" );
}

sub send_mail_info_ex
{
	my $self = shift;

	my ($smtp_code,$smtp_info,$exit_code);
	$smtp_code = $self->{mail_info}->{aka}->{resp}->{smtp_code} ||'';
	$smtp_info = $self->{mail_info}->{aka}->{resp}->{smtp_info} ||'';
	$exit_code = $self->{mail_info}->{aka}->{resp}->{exit_code} ||'0';

#print "after process, before send\n";
#$self->{zlog}->debug( "send_mail_info smtp_code: [$smtp_code],"
#	. "smtp_info: [$smtp_info], exit_code:[$exit_code]" );


#	if ( $self->{license_ok} ){
		print STDOUT $smtp_code . "\n";
		print STDOUT $smtp_info . "\n";
		print STDOUT $exit_code . "\n";
#	}else{
#		print STDOUT "553\n";
#		print STDOUT "对不起，本系统目前尚未获得正确的License许可，可能暂时无法工作。\n";
#		print STDOUT "150\n";
#	}
}


sub recv_mail_info
{
	my $self = shift;
	my $socket = shift;

my $logstr;
	$_ = <$socket>; s/\r|\r\n|\n//g;
$logstr .= "RELAYCLIENT: [$_]\n";
	$self->{mail_info}->{aka}->{RELAYCLIENT} = $_;

	$_ = <$socket>; s/\r|\r\n|\n//g;
$logstr .= "TCPREMOTEIP: [$_]\n";
	$self->{mail_info}->{aka}->{TCPREMOTEIP} = $_;

	$_ = <$socket>; s/\r|\r\n|\n//g;
$logstr .= "TCPREMOTEINFO: [$_]\n";
	$self->{mail_info}->{aka}->{TCPREMOTEINFO} = $_;

	$_ = <$socket>; s/\r|\r\n|\n//g;
$logstr .= "emlfilename: [$_]\n";
	$self->{mail_info}->{aka}->{emlfilename} = $_;

	$_ = <$socket>; s/\r|\r\n|\n//g;
	$self->{mail_info}->{aka}->{fd1} = $_;
s/\0/\\0/g;
$logstr .= "fd1: $_\n";

#$self->{zlog}->log ( $logstr );

	$self->{mail_info};
}

sub net_process
{
	my $self = shift;
	my $socket = shift;

	unless ( $socket && $socket->connected ){
		$self->{zlog}->fatal ( "Mail::net_process got invalid socket [$socket]" );
		return;
	}

	my ($old_alarm_sig,$old_alarm);

#print "before eval recv\n";
	eval {
		$old_alarm_sig = $SIG{ALRM};
		local $SIG{ALRM} = sub { die "TIMEOUT\n" }; # NB: \n required
		$old_alarm = alarm( 10 );

		$self->recv_mail_info( $socket );
	}; if ($@) {
		$self->{zlog}->fatal ( "Mail::net_process call recv_mail_info from socket[$@]" );
		# content engine have not start to work
		#$self->cleanup;
		return;
	}
	$SIG{ALRM} = $old_alarm_sig || 'IGNORE';
	alarm $old_alarm;
#print "after eval recv, before process\n";

#$self->{zlog}->debug( "mail_info.req\@srv\n"
#	. Dumper ($self->{mail_info}->{aka} )
#	. "<<<<processing...>>>" );

	#
	# Main process function
	#
	$self->process ( $self->{mail_info} );


	eval {
		$old_alarm_sig = $SIG{ALRM};
		local $SIG{ALRM} = sub { die "TIMEOUT\n" }; # NB: \n required
		$old_alarm = alarm( 10 );

		$self->send_mail_info ( $socket );
	}; if ($@) {	
		$self->{zlog}->fatal ( "Mail::net_process call send_mail_info from socket[$@]" );
		# content engine have not start to work
		#$self->cleanup;
		return;
	}
	$SIG{ALRM} = $old_alarm_sig || 'IGNORE';
	alarm $old_alarm;
		
#print "after send \n";
#$self->{zlog}->debug ( "mail_info.resp\@srv\n" . Dumper ($self->{mail_info}->{aka}) );
	
}

sub send_mail_info
{
	my $self = shift;
	my $socket = shift;

	my ($smtp_code,$smtp_info,$exit_code);
	$smtp_code = $self->{mail_info}->{aka}->{resp}->{smtp_code} ||'';
	$smtp_info = $self->{mail_info}->{aka}->{resp}->{smtp_info} ||'';
	$exit_code = $self->{mail_info}->{aka}->{resp}->{exit_code} ||'0';

#print "after process, before send\n";
$self->{zlog}->debug( "send_mail_info smtp_code: [" . $smtp_code . "]\n"
	. "smtp_info: [" . $smtp_info . "]\n"
	. "exit_code: [" . $exit_code . "]" );


	if ( $self->{license_ok} ){
		print $socket $smtp_code . "\n";
		print $socket $smtp_info . "\n";
		print $socket $exit_code . "\n";
	}else{
		print $socket "553\n";
		print $socket __"Sorry, System had no valid license now, It still can't work.\n";
		print $socket "150\n";
	}
}

sub process
{
	my $self = shift;
	my $mail_info = shift;

	unless ( $mail_info ){
		$self->{zlog}->fatal ( "Mail::process can't get mail_info" );
		return undef;
	}

	$self->{mail_info} = $mail_info;


	$mail_info->{aka}->{start_time} = $self->{start_time};
	$mail_info->{aka}->{last_cputime} = $self->{last_cputime};

	# 设置引擎运行的结果数据缺省值
	$self->init_engine_info();

	# 获取文件尺寸和标题等基本信息
	$self->get_mail_base_info;

	# 如果License过期，则直接将信件投递
	goto REQUEUE unless ( $self->{license_ok} );

	my ($user,$system,$cuser,$csystem) = times;
	my $last_cputime;

	$last_cputime = $user+$system+$cuser+$csystem;

	$self->antivirus_engine() 	unless $self->{mail_info}->{aka}->{drop};
	($user,$system,$cuser,$csystem) = times;
	$self->{mail_info}->{aka}->{engine}->{antivirus}->{cputime} = int(1000*($user+$system+$cuser+$csystem - $last_cputime));
	$last_cputime = $user+$system+$cuser+$csystem;

	# by Ed 2004-06-14 dynamic 拒绝的邮件就不必进行后续处理。
	$self->dynamic_engine()		unless $self->{mail_info}->{aka}->{drop};
	($user,$system,$cuser,$csystem) = times;
	$self->{mail_info}->{aka}->{engine}->{dynamic}->{cputime} = int(1000*($user+$system+$cuser+$csystem - $last_cputime));
	$last_cputime = $user+$system+$cuser+$csystem;

	$self->content_engine()		unless $self->{mail_info}->{aka}->{drop};
	($user,$system,$cuser,$csystem) = times;
	$self->{mail_info}->{aka}->{engine}->{content}->{cputime} = int(1000*($user+$system+$cuser+$csystem - $last_cputime));
	$last_cputime = $user+$system+$cuser+$csystem;

#$self->{zlog}->debug ( "before spam: [" . $last_cputime . "]" );
	$self->spam_engine() 		unless $self->{mail_info}->{aka}->{drop};
	($user,$system,$cuser,$csystem) = times;
#$self->{zlog}->debug ( "after spam: [" . ($user+$system+$cuser+$csystem) . "]" );
	$self->{mail_info}->{aka}->{engine}->{spam}->{cputime} = int(1000*($user+$system+$cuser+$csystem - $last_cputime));
#$self->{zlog}->debug ( "store spam: [" . $self->{mail_info}->{aka}->{engine}->{spam}->{cputime} . "]" );
	$last_cputime = $user+$system+$cuser+$csystem;

	$self->interactive_engine()	unless $self->{mail_info}->{aka}->{drop};
	($user,$system,$cuser,$csystem) = times;
	$self->{mail_info}->{aka}->{engine}->{interactive}->{cputime} = int(1000*($user+$system+$cuser+$csystem - $last_cputime));
	$last_cputime = $user+$system+$cuser+$csystem;

	
	$self->archive_engine()	;	#unless $self->{mail_info}->{aka}->{drop};
					# archive should run even we drop mail
	($user,$system,$cuser,$csystem) = times;
	$self->{mail_info}->{aka}->{engine}->{archive}->{cputime} = int(1000*($user+$system+$cuser+$csystem - $last_cputime));
	$last_cputime = $user+$system+$cuser+$csystem;

	# Log
	$self->log_engine();


	# 处理邮件动作，大家都有的动作
	foreach my $engine ( keys %{$mail_info->{aka}->{engine}} ){
		next unless $_ = $self->{mail_info}->{aka}->{engine}->{$engine}->{action};
		next if ( $_ eq ACTION_PASS );

		if ( $_ eq ACTION_REJECT ){
			$self->cleanup();

			unless ($self->{mail_info}->{aka}->{engine}->{$engine}->{desc}){
				$self->{zlog}->fatal ( "engine $engine has action buf no desc?" );
			}
	
			$mail_info->{aka}->{resp} = {
					smtp_code => 553,
					smtp_info => __("Sorry, due to ")
						. ($self->{mail_info}->{aka}->{engine}->{$engine}->{desc} || __("Security Policy"))
						. __("System reject your mail.") ,
					exit_code => 150
			};
	
			if ( $engine eq 'content' ){
				$mail_info->{aka}->{resp}->{smtp_info} = $self->{mail_info}->{aka}->{engine}->{$engine}->{desc} 
								|| 'This message was rejected.';
			}elsif ( $engine eq 'dynamic' ){
				$mail_info->{aka}->{resp}->{smtp_code} = 451;
			}

			return $mail_info;
		}elsif ( $_ eq ACTION_DISCARD ){
			$self->cleanup();
			$mail_info->{aka}->{resp}->{exit_code} = 0;
			return $mail_info;
		}elsif ( $_ eq ACTION_QUARANTINE ){
			$self->quarantine();
			$mail_info->{aka}->{resp}->{exit_code} = 0;
			return $mail_info;
		}else{
			#$self->{zlog}->debug ( "Mail::process got a unknown action: [" . $_ . "]" );
			next;
		}
	}

	# ACTION_ADDRCPT / ACTION_DELRCPT / ACTION_CHGRCPT
	$self->action_rcpts();

REQUEUE:
	# ACTION_ADDHDR / ACTION_DELHDR / ACTION_CHGHDR
	$self->qmail_requeue();

	# 清理
	$self->cleanup();

	return $self->{mail_info};
}

sub init_engine_info
{
	my $self = shift;

	$self->{mail_info}->{aka}->{engine} = undef;

	$self->{mail_info}->{aka}->{engine}->{antivirus} = {	
			result	=>0,
			desc	=>__("not run"),
			action	=>ACTION_PASS,
               		enabled => 0,
               		runned  => 0,
                      	runtime => 0
	};
	$self->{mail_info}->{aka}->{engine}->{spam} = {	
			result	=>0,
			desc	=>__("not run"),
			action	=>ACTION_PASS,
               		enabled => 0,
               		runned  => 0,
                      	runtime => 0
	};
	$self->{mail_info}->{aka}->{engine}->{content} = {	
			result	=>0,
			desc	=>__("not run"),
			action	=>ACTION_PASS,
               		enabled => 0,
               		runned  => 0,
                      	runtime => 0
	};
	$self->{mail_info}->{aka}->{engine}->{dynamic} = {	
			result	=>0,
			desc	=>__("not run"),
			action	=>ACTION_PASS,
               		enabled => 0,
               		runned  => 0,
                      	runtime => 0
	};
	$self->{mail_info}->{aka}->{engine}->{archive} = {	
			result	=>0,
			desc	=>__("not run"),
			action	=>ACTION_PASS,
               		enabled => 0,
               		runned  => 0,
                      	runtime => 0
	};
}

sub action_rcpts
{
	my $self = shift;
	
	my $aka = $self->{mail_info}->{aka};

	if ( $aka->{engine}->{content}->{enabled} ){
		my $action = $aka->{engine}->{content}->{action};
		return unless $action;

		my $pf_param = $aka->{engine}->{content}->{desc};
		my $env_recips = $aka->{env_recips};

		if ( ACTION_ADDRCPT eq $action ){
			if ( ! $pf_param=~/^[\w\d\.-_=+]+\@[\w\d\.-_=+]+$/ ){
				$self->{zlog}->debug("pf_a: addrcpt param is: [$pf_param] invalid email address.");
				return;
			}
			$env_recips = "T$pf_param\0" . $env_recips;
		}elsif ( ACTION_DELRCPT eq $action ){
			# 9、delrcpt 删除指定收件人（该动作只允许在信封收件人的信头规则中使用）。无参数
			if ( ! $pf_param=~/^[\w\d\.-_=+]+\@[\w\d\.-_=+]+$/ ){
				$self->{zlog}->debug("pf_a: delrcpt param is: [$pf_param] invalid email address.");
				return;
			}
			# one recip, or first 
			$env_recips =~ s/T$pf_param\0//;

			if ( 3>length($env_recips) ){
				# only one recip, should be droped after delrcpt
				$self->cleanup;
				# XXX by zixia 2004-04-24 
				# why exit 0;
			}# 即使是一个地址，结尾也是两个\0
		}elsif ( ACTION_CHGRCPT eq $action ){
			# 10、chgrcpt 改变指定的收件人为新的收件人（该动作只允许在信封收件人的信头规则中使用）。
			#     带一个字符串参数，内容为新的收件人邮件地址
			if ( ! $pf_param=~/^[\w\d\.-_=+]+\@[\w\d\.-_=+]+$/ ){
				$self->debug("pf_a: chgrcpt param is: [$pf_param] invalid email address.");
				return;
			}
			# either one recip or more recips, need two NULL terminater.
			$env_recips = "T$pf_param\0\0";
		}else{
			return;
		}
		$aka->{engine}->{content}->{desc} = $pf_param ;
		$aka->{env_recips} = $env_recips ;
	}
}


sub quarantine
{
	my $self = shift;

	my $pf_param = $self->{mail_info}->{aka}->{engine}->{content}->{desc};

	#TODO support other dir
	if ( $pf_param =~ m#^/var/spool/uncmgw/# ){
		if (! -d "$pf_param") {
  			`mkdir -p /$pf_param`;
		}
		my $emlfilename = $self->{mail_info}->{aka}->{emlfilename};
		`mv -f $emlfilename  /$pf_param/`;
	}else{
		&debug ( "pf: action 3 quarantine dir must be default now, but pf_param is: [$pf_param]" );
	}
	# drop after quarantine;
	$self->cleanup();
	exit 0;
}

sub qmail_requeue {
	my $self = shift;

	my $aka = $self->{mail_info}->{aka};

	my($sender,$env_recips,$msg)= ( $aka->{env_returnpath}, $aka->{env_recips}, $aka->{emlfilename} );
	my ($findate);

	# Create a pipe through which to send the envelope addresses.
	pipe (EOUT, EIN) or return $self->close_smtp(451, "Unable to create a pipe. - $!");
	select(EOUT);$|=1;
	select(EIN);$|=1;

#XXX should this be DEFAULT instead of IGNORE ?
# Ed Li 2004-06-12
	local $SIG{PIPE} = 'IGNORE';
	local $SIG{CHLD} = 'DEFAULT';

	my $pid = fork;

	if (not defined $pid) {
		return $self->close_smtp (451, "Unable to fork. (#4.3.0) - $!");
	} elsif ($pid == 0) {
		# In child.  Mutilate our file handles.
		close EIN; 

		# Net::Server::PreFork 将 STDIN/STDOUT 映射成了socket的索引，这里需要重新将两个文件描述符独立出来，然后才可以reopen
		open(DUMMYIN, '</dev/null') || die "Can't close STDIN [$!]";
		open(DUMMYOUT,'>/dev/null') || die "Can't close STDOUT [$!]";
		*STDIN = *DUMMYIN;
		*STDOUT = *DUMMYOUT;
		open ( STDIN, "<&=0" ) or die "open <&=0";
		open ( STDOUT, ">&=1" ) or die "open >&=1";

		#$self->{zlog}->debug ( "try to open [$msg] for fd 0" );
		unless ( open(STDIN,"<$msg") ){
			$self->{zlog}->fatal ( "mail_requeue reopen stdin for msg $msg failure!" );
			exit -1;
		}

		unless ( open (STDOUT, "<&EOUT") ){
			$self->{zlog}->fatal ( "mail_requeue reopen stdout to pipe!" );
			exit -1;
		}

		select(STDIN);$|=1;

#print STDERR ": STDIN no: " . fileno(STDIN) . " STDOUT no: " . fileno(STDOUT) . "\n";
#$self->{zlog}->debug ( "write_queue before" );
		$self->write_queue();
#$self->{zlog}->debug ( "write_queue over" );

		#This child is finished - exit
		exit;
	} else {
		# In parent.
		close EOUT;

		# Feed the envelope addresses to qmail-queue.
		#my $envelope = "$sender\0$env_recips";
		
		my $envelope;

		if ( $aka->{env_returnpath} || $aka->{env_recips} ) {
			$envelope = $aka->{env_returnpath} . "\0" . $aka->{env_recips};
		}else{
			$envelope = "F\0T\0\0";
		}


		print EIN $envelope;
		close EIN  || return $self->close_smtp (451, "Write error to envelope pipe. (#4.3.0) - $!");

		$envelope =~ s/\0/\\0/g;
		#$self->{zlog}->debug ( "parent: q_r_q: envelope data: [$envelope]" );

	}

	# We should now have queued the message.  Let's find out the exit status
	# of qmail-queue.
	
	waitpid ($pid, 0);

	#eval {
		#1 while (waitpid($pid, POSIX::WNOHANG()) > 0);
	#}; 
#$self->{zlog}->debug ( "here1 $@" ) if $@;
#$self->{zlog}->debug ( "here1 $?" );

	my $xstatus =($? >> 8);
#$self->{zlog}->debug ( "here2" );
	if ( $xstatus > 10 && $xstatus < 41 ) {
		return $self->close_smtp(553, "mail server permanently rejected message. (#5.3.0) - $!",$xstatus);
	} elsif ($xstatus > 0) {
		return $self->close_smtp(451, "Unable to close pipe to mailqueue [$xstatus] (#4.3.0) - $!",$xstatus);
	}
}

sub write_queue
{
	my $self = shift;

	my $aka = $self->{mail_info}->{aka};
	my $config = $self->{conf}->{config};

	open (QMQ, "|/var/qmail/bin/qmail-queue")|| return $self->close_smtp (451, "Unable to open pipe to mailqueue (#4.3.0) - $!");
	#open (QMQ, "|/tmp/qq.pl")|| return $self->close_smtp (451, "Unable to open pipe to qmailqueue [$xstatus] (#4.3.0) - $!");
	my ($sec,$min,$hour,$mday,$mon,$year) = gmtime(time);
	my $elapsed_time = tv_interval ( $self->{start_time}, [gettimeofday]);
	my $findate = POSIX::strftime( "%d %b ",$sec,$min,$hour,$mday,$mon,$year);
	$findate .= sprintf "%02d %02d:%02d:%02d -0000", $year+1900, $hour, $min, $sec;

	print QMQ "Received: from " . $aka->{returnpath} . " by " 
		. $config->{Network}->{Hostname} 
		. " with noSPAM-" . $self->{conf}->{licconf}->{Version} .  "\n";
	print QMQ " Processed in $elapsed_time secs; $findate\n";

	my ($pf_action, $pf_param, $pf_desc) = ( $aka->{engine}->{content}->{action}, 
					$aka->{engine}->{content}->{desc}, 
					$aka->{engine}->{content}->{result} );
	my ($pf_hdr_key,$pf_hdr_done);
	if (  ACTION_ADDHDR<=$pf_action && ACTION_CHGHDR>=$pf_action ){
		$pf_hdr_done = 0;
		if ( $pf_param =~ /^([^:]+): /){
			$pf_hdr_key = $1;
		}elsif ( ACTION_DELHDR!=$pf_action ){
			$self->{zlog}->debug ( "pf: pf_param: [$pf_param] can't parse to header data when requeue, pf_action: [$pf_action]" );
		}
	}else{
		$pf_hdr_done = 1;
	}

	my $still_headers=1;

	while (<STDIN>) {
		if ($still_headers) {
			if ( !$pf_hdr_done && (ACTION_ADDHDR<=$pf_action || ACTION_CHGHDR>=$pf_action) ){
				if ( ACTION_ADDHDR==$pf_action ){
					# 11、addhdr 添加信头纪录。带一个字符串参数，内容为新的信头记录
					print QMQ "$pf_param\n";
					$pf_hdr_done = 1;
				}elsif ( ACTION_DELHDR==$pf_action ){
						# 12、delhdr 删除信头纪录，删除匹配到指定信头规则的信头记录
						#     （该动作只允许在信头规则中使用）。无参数
					if ( /^$pf_hdr_key: / ){
						#FIXME 如果是折行的header，需要特别处理
						$pf_hdr_done = 1;
						next;
					}
				}elsif ( ACTION_CHGHDR==$pf_action ){
					# 13、chghdr 修改信头纪录，将匹配到指定信头规则的信头记录换成新的信头记录
					#    （该动作只允许在信头规则中使用）。
					#    带一个字符串参数，内容为新的信头记录
					if ( /^$pf_hdr_key: / ){
						chomp $pf_param;
						$_ = $pf_param . "\n";
						$pf_hdr_done = 1;
					}
				}
			}
			if (/^Subject: (.+)/i){
				my $tagged_subj = $1;
				if ( 'Y' eq uc $config->{SpamEngine}->{TagSubject} ){
					if ( RESULT_SPAM_MAYBE==$aka->{engine}->{spam}->{result} ){
						$tagged_subj = $config->{SpamEngine}->{MaybeSpamTag} . ' ' . $tagged_subj; 
					}elsif ( RESULT_SPAM_MUST==$aka->{engine}->{spam}->{result} ){
						$tagged_subj = $config->{SpamEngine}->{SpamTag} . ' ' . $tagged_subj; 
					}elsif ( RESULT_SPAM_BLACK==$aka->{engine}->{spam}->{result} ){
						$tagged_subj = ($config->{SpamEngine}->{BlackTag}||__("[Black List]")) . ' ' . $tagged_subj; 
					}
				}
				if ( 'Y' eq uc $config->{AntiVirusEngine}->{TagSubject} ){
					if ( $aka->{engine}->{antivirus}->{result} ){
						$tagged_subj = ( $config->{AntiVirusEngine}->{VirusTag}
								|| __x("[VIRUS {result}]", result=>$aka->{engine}->{antivirus}->{result})
							) . ' ' . $tagged_subj; 
					}
				}
				$_ = 'Subject: ' . $tagged_subj . "\n";
			}
			if (/^(\r|\r\n|\n)$/){
				$still_headers=0 ;
				print QMQ "X-noSPAM-Version: v" . ($self->{conf}->{licconf}->{Version} || '2') .  "\n";

				print QMQ "X-noSPAM-Result: \n";
				if ( 'Y' eq uc $config->{AntiVirusEngine}->{TagReason} ){
					print QMQ "  V:" . $aka->{engine}->{antivirus}->{result} 
						. " N:" . $aka->{engine}->{antivirus}->{desc} . "\n";
				}
				if ( 'Y' eq uc $config->{SpamEngine}->{TagReason} ){
					print QMQ "  S:" . $aka->{engine}->{spam}->{result}
						. ' R:' . $aka->{engine}->{spam}->{desc} . "\n";
				}
				#if ( $aka->{engine}->{content}->{enabled} ){
					#XXX unimpl if ( 'Y' eq uc $config->{ContentEngine}->{TagReason} ){
					if ( 'Y' eq uc $config->{SpamEngine}->{TagReason} ){
						print QMQ "  A:$pf_action P:$pf_param I:$pf_desc\n";
					}
				#}
				

				if ( 'Y' eq uc $config->{AntiVirusEngine}->{TagHead} ){
					if ( $aka->{engine}->{antivirus}->{result} ){
						print QMQ "X-Virus-Flag: Yes\n";
					}else{
						print QMQ "X-Virus-Flag: No\n";
					}
				}
				if ( 'Y' eq uc $config->{SpamEngine}->{TagHead} ){
					if ( $aka->{engine}->{spam}->{result} ){
						print QMQ "X-Spam-Flag: Yes\n";
					}else{
						print QMQ "X-Spam-Flag: No\n";
					}
				}
			}
		}
		print QMQ;
	}
	close(QMQ); #||&$self->close_smtp("Unable to close pipe to $qmailqueue (#4.3.0) - $!");
	my $xstatus = ( $? >> 8 );
	if ( $xstatus > 10 && $xstatus < 41 ) {
		return $self->close_smtp(553, "mail server permanently rejected message. (#5.3.0) - $!",$xstatus);
	} elsif ($xstatus > 0) {
		return $self->close_smtp(451, "Unable to open pipe to mailqueue [$xstatus] (#4.3.0) - $!",$xstatus);
	}
}

# Fail with the given message and a temporary failure code.
sub close_smtp {
	my $self = shift;

	my ($smtp_code, $smtp_info, $errcode)=@_;
	$errcode=150 if (!$errcode);
	$self->cleanup;

	#print NSOUT $string, "\r\n";
	#exit $errcode;
	$self->{mail_info}->{aka}->{resp}->{smtp_code} = $smtp_code;
	$self->{mail_info}->{aka}->{resp}->{smtp_info} = $smtp_info;
	$self->{mail_info}->{aka}->{resp}->{exit_code} = $errcode;

	return $self->{mail_info};
}

sub cleanup {
	my $self = shift;

	$self->{content}->clean;

	#XXX 无用？
	#chdir("/home/NoSPAM/spool/");

	#rmdir($ENV{'TMPDIR'});
	unlink( $self->{mail_info}->{aka}->{emlfilename} );
}


sub log_engine
{
	my $self = shift;

	$self->{zlog}->log_csv ( $self->{mail_info} );
}

sub antivirus_engine
{
	my $self = shift;

	my $start_time = [gettimeofday];

	if ( 'Y' ne uc $self->{conf}->{config}->{AntiVirusEngine}->{AntiVirusEngine} ){
		$self->{mail_info}->{aka}->{engine}->{antivirus} = ( { 	
				result 	=> 0,
				desc	=> __("OFF"),
				action 	=> 0, 

				enabled	=> 0,
				runned	=> 1,
				runtime	=> int(1000*tv_interval ($start_time, [gettimeofday]))
			} );
		return;
	}

	#
	# 判断保护方向
	#
	if ( $self->{mail_info}->{aka}->{RELAYCLIENT} || $self->{mail_info}->{aka}->{TCPREMOTEINFO} ){
		# 是“由内向外”
		if ( $self->{conf}->{config}->{AntiVirusEngine}->{ProtectDirection}!~/Out/ ){
			# 没有限制“由内向外”的邮件
			$self->{mail_info}->{aka}->{engine}->{antivirus} = {	
					result	=>0,
					desc	=>__("Need not check outgoing mail"),
					action	=>ACTION_PASS,

                  			enabled => 1,
                     			runned  => 1,
                                	runtime => int(1000*tv_interval ($start_time, [gettimeofday]))
			};
			return;
		}

	}else{
		# 是“由外向内”
		if ( $self->{conf}->{config}->{AntiVirusEngine}->{ProtectDirection}!~/In/ ){
			# 没有限制“由外向内”的邮件
			$self->{mail_info}->{aka}->{engine}->{antivirus} = {
					result  => 0,
					desc	=>__("Need not check incoming mail") ,
					action  => 0,

					enabled => 1,
					runned  => 1,
					runtime => int(1000*tv_interval ($start_time, [gettimeofday]))
			};
			return;
		}

	}

	#
	# 抽样检查
	#
	if ( 'Y' eq uc $self->{conf}->{config}->{AntiVirusEngine}->{SampleCheck} ){
		#my $random1_100 = int(rand(98)+1);
		my $random1_100 = $$ % 100;
		if ( $self->{conf}->{config}->{AntiVirusEngine}->{SampleProbability} < $random1_100 ){
#$self->{zlog}->debug ( "random: $random1_100 , sample: " . $self->{conf}->{config}->{AntiVirusEngine}->{SampleProbability} );
			$self->{mail_info}->{aka}->{engine}->{antivirus} = {
					result  => 0,
					desc	=> __("This mail is not in circle of check"),
					action  => 0,

					enabled => 1,
					runned  => 1,
					runtime => int(1000*tv_interval ($start_time, [gettimeofday]))
			};
			return;
		
		}
	}

	$self->{mail_info}->{aka}->{engine}->{antivirus} = 
		$self->{antivirus}->catch_virus( $self->{mail_info}->{aka}->{emlfilename} );


	if ( (ACTION_REJECT)==$self->{mail_info}->{aka}->{engine}->{antivirus}->{action}
			|| (ACTION_DISCARD)==$self->{mail_info}->{aka}->{engine}->{antivirus}->{action}){
		$self->{mail_info}->{aka}->{drop} = 1;
#$self->{zlog}->debug ( "antivirus action drop set [" . $self->{mail_info}->{aka}->{drop} . "]" );
	}
	#$self->{mail_info}->{aka}->{drop_info} ||= '553 邮件包含病毒 ' . $self->{mail_info}->{aka}->{engine}->{antivirus}->{desc};
}


# return 0 if not archived, otherwise 1;
# input: ( emlfile, is_spam, match_rule );
sub archive_engine
{
	my $self = shift;

	my $start_time = [gettimeofday];

	my $emlfile = $self->{mail_info}->{aka}->{emlfilename};

	my $is_spam = $self->{mail_info}->{aka}->{engine}->{spam}->{result};
	my $run_spam = $self->{mail_info}->{aka}->{engine}->{spam}->{runned};

	my $is_virus = $self->{mail_info}->{aka}->{engine}->{antivirus}->{result};
	my $run_virus = $self->{mail_info}->{aka}->{engine}->{antivirus}->{runned};

	my $is_overrun = $self->{mail_info}->{aka}->{engine}->{dynamic}->{result};
	my $run_overrun = $self->{mail_info}->{aka}->{engine}->{dynamic}->{runned};

	my $is_matchrule = $self->{mail_info}->{aka}->{engine}->{content}->{result};
	my $run_matchrule = $self->{mail_info}->{aka}->{engine}->{content}->{runned};

	my $recips = $self->{mail_info}->{aka}->{recips};

# XXX test sa

	#$self->{zlog}->debug( "SA: $is_virus, $is_overrun" );
=pod
	if ( !$is_virus && !$is_overrun){
		my $spamc_cmd = "/usr/bin/spamc < $emlfile ";
		$emlfile =~ m#([^/]+)$#;
		my $spamc_output = "/home/vpopmail/domains/localhost.localdomain/archive/Maildir/";
		if ( $is_spam ){
			$self->{zlog}->debug( "SA: $spamc_cmd > $spamc_output/spam/$1" );
			system ( "$spamc_cmd > $spamc_output/spam/$1" );
		}else{
			$self->{zlog}->debug( "SA: $spamc_cmd > $spamc_output/nonspam/$1" );
			system ( "$spamc_cmd > $spamc_output/nonspam/$1" );
		}
	}
=cut
# XXX test sa over

	if ( 'Y' ne uc $self->{conf}->{config}->{ArchiveEngine}->{ArchiveEngine} ){
		$self->{mail_info}->{aka}->{engine}->{archive} = {	
			result	=>0,
			desc	=>__("OFF"),
			action	=>ACTION_PASS,
               		enabled => 0,
               		runned  => 1,
                      	runtime => int(1000*tv_interval ($start_time, [gettimeofday]))
		};
		return;
	}

	my @archivetype = @{$self->{conf}->{config}->{ArchiveEngine}->{ArchiveType}};
#foreach ( @archivetype ){
#	$self->{zlog}->debug( "archivetype: $_" );
#}
	unless ( @archivetype ){
		$self->{mail_info}->{aka}->{engine}->{archive} = {	
			result	=>0,
			desc	=>__("not set"),
			action	=>ACTION_PASS,
               		enabled => 0,
               		runned  => 1,
                      	runtime => int(1000*tv_interval ($start_time, [gettimeofday]))
		};
		return;
	}

	my @archive_address = @{$self->{conf}->{config}->{ArchiveEngine}->{ArchiveAddress}};
	my $need_archive = 1;	# 所有的条件必须满足才会审计

	#选择性归档：全部/特定地址/垃圾/非垃圾/匹配了规则的 Address,Spam,NotSpam,MatchRule,NotMatchRule,Virus,NotVirus
	if ( !grep(/^All$/,@archivetype) ){
		$need_archive=0 if ( $need_archive && grep(/^Spam$/,@archivetype) && (!$run_spam || !$is_spam) );
		$need_archive=0 if ( $need_archive && grep(/^NotSpam$/,@archivetype) && (!$run_spam || $is_spam) );
#$self->{zlog}->debug( "archive: NotSpam [$need_archive] [$run_spam] [$is_spam]" );

		$need_archive=0 if ( $need_archive && grep(/^Virus$/,@archivetype) && (!$run_virus || !$is_virus) );
		$need_archive=0 if ( $need_archive && grep(/^NotVirus$/,@archivetype) && (!$run_virus || $is_virus) );

#$self->{zlog}->debug ( "archive before overrun: $need_archive, " . join(',',@archivetype) );
		$need_archive=0 if ( $need_archive && grep(/^Excessive$/,@archivetype) && (!$run_overrun || !$is_overrun) );
		$need_archive=0 if ( $need_archive && grep(/^NotExcessive$/,@archivetype) && (!$run_overrun || $is_overrun) );
#$self->{zlog}->debug ( "archive after overrun: $need_archive" );

		$need_archive=0 if ( $need_archive && grep(/^MatchRule$/,@archivetype) && (!$run_matchrule || !$is_matchrule) );
		$need_archive=0 if ( $need_archive && grep(/^NotMatchRule$/,@archivetype) && (!$run_matchrule || $is_matchrule) );

		if ( $need_archive && grep(/^Address$/,@archivetype) ){
			if ( ! @archive_address){
				$need_archive = 0;
			}else{
				my ( $recip, $archive_addr );
				my $match = 0;
				ARCHIVE_ADDR_LOOP: 
				foreach $recip ( split(/,/,$recips) ){
					foreach $archive_addr ( @archive_address ){
						if ( $archive_addr eq $recip ){
							$match=1 ;
							last ARCHIVE_ADDR_LOOP;
						}
					}
				}
				$need_archive = 0 if ( !$match );
			}
		}
	}


	unless ( $need_archive ){
		$self->{mail_info}->{aka}->{engine}->{archive} = {	
			result	=>0,
			desc	=>__("not fit condition"),
			action	=>ACTION_PASS,
               		enabled => 0,
               		runned  => 1,
                      	runtime => int(1000*tv_interval ($start_time, [gettimeofday]))
		};
		return;
	}

	unless ( $emlfile && -f $emlfile ){
		$self->{mail_info}->{aka}->{engine}->{archive} = {	
			result	=>0,
			desc	=>__("internal error"),
			action	=>ACTION_PASS,
               		enabled => 0,
               		runned  => 1,
                      	runtime => int(1000*tv_interval ($start_time, [gettimeofday]))
		};
		return;
	}

	$self->{archive}->archive($emlfile);

	$self->{mail_info}->{aka}->{engine}->{archive} = {	
			result	=>1,
			desc	=>__("commited"),
			action	=>ACTION_PASS,
               		enabled => 1,
               		runned  => 1,
                      	runtime => int(1000*tv_interval ($start_time, [gettimeofday]))
	};

	return;
}

sub spam_engine
{
	my $self = shift;

	my $start_time = [gettimeofday];
	my ( $client_smtp_ip, $returnpath ) = ( $self->{mail_info}->{aka}->{TCPREMOTEIP},
						$self->{mail_info}->{aka}->{returnpath}
						 );

	my ( $is_spam, $reason, $dns_query_time ) = (0,__("AntiSpam Engine"),0);
	my $sa_result = {};

	$self->{mail_info}->{aka}->{engine}->{spam}->{enabled} = 1;

	if ( 'Y' ne uc $self->{conf}->{config}->{SpamEngine}->{NoSPAMEngine} ){
		$self->{mail_info}->{aka}->{engine}->{spam}->{enabled} = 0;

		$is_spam = RESULT_SPAM_NOT;
		$reason = __("OFF");
	}
	elsif ( $self->{mail_info}->{aka}->{RELAYCLIENT} ) { # 内部RELAY
		$is_spam = RESULT_SPAM_NOT;
		$reason = __("Traceable");

	}
	elsif ( $self->{mail_info}->{aka}->{TCPREMOTEINFO} ){ # 认证用户
		my $auth_user = $self->{mail_info}->{aka}->{TCPREMOTEINFO};

		$auth_user .= '@' . $self->{conf}->{config}->{MailServer}->{MailHostName}
			unless ( $auth_user =~ /\@/ );
		
		$is_spam = RESULT_SPAM_NOT;
		$reason = __("Auth user");

		if ( ($auth_user ne $returnpath) &&
				( ('Y' eq uc $self->{conf}->{config}->{SpamEngine}->{TraceEngine}) &&  # 内部可追查
				  ($self->{conf}->{config}->{SpamEngine}->{TraceProtectDirection}=~/Out/i) ) ){ 
			$is_spam = RESULT_SPAM_MAYBE;
			$reason = __("Sender must as same as auth user");
		}
		
		if ( 'Y' eq uc $self->{conf}->{config}->{SpamEngine}->{SmartEngine} &&
				$self->{conf}->{config}->{SpamEngine}->{SmartProtectDirection}=~/Out/i ){
			my $result = $self->get_sa_result();
			if ( defined $result ){
				($sa_result,$is_spam,$reason) = @$result;
			}
		}
	}
	#elsif ( (!length($client_smtp_ip)) || (!length($returnpath)) ){
		# A blank MAIL FROM: is typically used for error mail, 
		# and error mail typically would not be sent to multiple recipients.
	#	$is_spam = RESULT_SPAM_MAYBE;
	#	$reason = '邮件格式伪造';
	#}
	else{ #由外向内

		if ( 'Y' eq uc $self->{conf}->{config}->{SpamEngine}->{TraceEngine} &&
				$self->{conf}->{config}->{SpamEngine}->{TraceProtectDirection}=~/In/i ){
			( $is_spam, $reason, $dns_query_time ) = $self->{spam}->spam_checker( $client_smtp_ip, $returnpath );
#$self->{zlog}->debug ( "spam_checker: $returnpath: $is_spam, $reason" );
		}
		
		if ( !$is_spam && 'Y' eq uc $self->{conf}->{config}->{SpamEngine}->{SmartEngine} &&
				$self->{conf}->{config}->{SpamEngine}->{SmartProtectDirection}=~/In/i ){
			my $result = $self->get_sa_result();
			if ( defined $result ){
				($sa_result,$is_spam,$reason) = @$result;
			}
		}
	}

	my $action = ACTION_PASS;

	if ( $is_spam ) {
		if ( 'Y' eq $self->{conf}->{config}->{SpamEngine}->{RefuseSpam} ){
			$action = ACTION_REJECT; # 1、reject
		}elsif ( 'D' eq $self->{conf}->{config}->{SpamEngine}->{RefuseSpam} ){
			$action = ACTION_DISCARD; # 2、drop
		}else{ #'N'
			$action = ACTION_NULL;
		}
	}else{
		$action = ACTION_ACCEPT;
	}

#$self->{zlog}->log ( "SA: " . $sa_result->{VERSION} );
	$self->{mail_info}->{aka}->{engine}->{spam} = {	result	=>	$is_spam,
							desc	=>	$reason,
							action	=>	$action,
							sa	=>	$sa_result,
                      				enabled => 1,
                      				runned  => 1,
                                		runtime => int(1000*tv_interval ($start_time, [gettimeofday])) 
									- ($dns_query_time||0),
						dns_query_time => $dns_query_time||0
	};

	if ( (ACTION_REJECT)==$self->{mail_info}->{aka}->{engine}->{spam}->{action}
			|| (ACTION_DISCARD)==$self->{mail_info}->{aka}->{engine}->{spam}->{action}){
		$self->{mail_info}->{aka}->{drop} = 1;
	}

	return;
}

sub get_sa_result
{
	my $self = shift;

	# 检查 SA 是否开启
	return undef if ( 'Y' ne uc $self->{conf}->{config}->{SpamEngine}->{SmartEngine} );

	# SpamAssassin, default max size 150KB
	my ($sa_result,$is_spam,$reason);
	if ( $self->{mail_info}->{aka}->{size} < ($self->{conf}->{intconf}->{SpamAssassinMaxMailSize}||153600) ){
		$sa_result = $self->{sa}->get_result($self->{mail_info}->{aka}->{emlfilename});
		if ( $sa_result->{SCORE} > 10 ){
			$reason = $sa_result->{TESTS};
			if ( $sa_result->{SCORE} < 15 ){
				$is_spam = RESULT_SPAM_MAYBE ;
			}else{
				$is_spam = RESULT_SPAM_MUST;
			}
		}
		if ( $is_spam ){
			my @result = ($sa_result,$is_spam,$reason);
			return \@result;
		}
	}
	return undef;

}


# input: (subject, mailfrom)
# return ( is_over_quota, reason );
sub dynamic_engine
{
	my $self = shift;

        my $start_time=[gettimeofday];

	my ( $subject, $mailfrom, $ip ) = (
		$self->{mail_info}->{aka}->{subject},
		$self->{mail_info}->{aka}->{returnpath},
		$self->{mail_info}->{aka}->{TCPREMOTEIP} 
	);

	my ( $is_overrun, $reason );


	#
	# 引擎开关
	#
	if ( 'Y' ne uc $self->{conf}->{config}->{DynamicEngine}->{DynamicEngine} ){
		$self->{mail_info}->{aka}->{engine}->{dynamic} = {
	               			result  => 0,
	                                desc    => __("OFF"),
       	                         	action  => 0,
	
                                	enabled => 0,
       	                         	runned  => 1,
                                	runtime => int(1000*tv_interval ($start_time, [gettimeofday]))
			
		};
		return;
	}

	#
	# 判断保护方向
	#
	if ( $self->{mail_info}->{aka}->{RELAYCLIENT} || $self->{mail_info}->{aka}->{TCPREMOTEINFO} ){
		# 是“由内向外”
		if ( $self->{conf}->{config}->{DynamicEngine}->{ProtectDirection}!~/Out/ ){
			# 没有限制“由内向外”的邮件
			$self->{mail_info}->{aka}->{engine}->{dynamic} = {	
					result	=>0,
					desc	=>__("outgoing mail is not limited"),
					action	=>ACTION_PASS,

                  			enabled => 1,
                     			runned  => 1,
                                	runtime => int(1000*tv_interval ($start_time, [gettimeofday]))
			};
			return;
		}

	}else{
		# 是“由外向内”
		if ( $self->{conf}->{config}->{DynamicEngine}->{ProtectDirection}!~/In/ ){
			# 没有限制“由外向内”的邮件
			$self->{mail_info}->{aka}->{engine}->{dynamic} = {
					result  => 0,
					desc	=> __("incoming mail is not limited"),
					action  => 0,

					enabled => 1,
					runned  => 1,
					runtime => int(1000*tv_interval ($start_time, [gettimeofday]))
			};
			return;
		}

	}


	#
	# 判断动态
	#
	# we check what we has seen
	#if ( ! $subject || ! $mailfrom || ! $ip ){
		#$self->{zlog}->debug ( "Mail::dynamic_engine can't get param: " . join ( ",", @_ ) );

	#	($is_overrun,$reason) = (0, "动态限制引擎参数不足" );
	#}

	if ( $mailfrom ){
		# 检查白名单
		foreach ( @{$self->{conf}->{config}->{DynamicEngine}->{WhiteFromList}} ){
			if ( $_ eq $mailfrom ){
				$self->{mail_info}->{aka}->{engine}->{dynamic} = {
	               			result  => 0,
	                                desc    => __("Sender white list"),
       	                         	action  => 0,
	
                                	enabled => 1,
       	                         	runned  => 1,
                                	runtime => int(1000*tv_interval ($start_time, [gettimeofday]))
				};
				return ;
			}
		}
		# 递交后台处理
		($is_overrun,$reason) = $self->{dynamic}->is_overrun_rate_per_mailfrom( $mailfrom );
		if ( $is_overrun ){
			$self->{mail_info}->{aka}->{engine}->{dynamic} = {
	               			result  => $is_overrun,
	                                desc    => __("Mail sender") . $reason,
       	                         	action  => 1,
	
                                	enabled => 1,
       	                         	runned  => 1,
                                	runtime => int(1000*tv_interval ($start_time, [gettimeofday]))
			};
			$self->{mail_info}->{aka}->{drop} = 1;
			return ;
		}
	}

	if ( $subject ){
		# 检查白名单
		foreach ( @{$self->{conf}->{config}->{DynamicEngine}->{WhiteSubjectList}} ){
			if ( $_ eq $subject ){
				$self->{mail_info}->{aka}->{engine}->{dynamic} = {
	               			result  => 0,
	                                desc    => __("Mail subject white list"),
       	                         	action  => 0,
	
                                	enabled => 1,
       	                         	runned  => 1,
                                	runtime => int(1000*tv_interval ($start_time, [gettimeofday]))
				};
				return ;
			}
		}
	
		($is_overrun,$reason) = $self->{dynamic}->is_overrun_rate_per_subject( $subject );
		if ( $is_overrun ){
			$self->{mail_info}->{aka}->{engine}->{dynamic} = {
	               			result  => $is_overrun,
	                                desc    => __("Mail") . $reason,
       	                         	action  => 1,
	
                                	enabled => 1,
       	                         	runned  => 1,
                                	runtime => int(1000*tv_interval ($start_time, [gettimeofday]))
			};
			$self->{mail_info}->{aka}->{drop} = 1;
			return ;
		}
	}

	if ( $ip ){
		# 检查白名单
		use AKA::IPUtil;
		my $AI = new AKA::IPUtil;
		foreach ( @{$self->{conf}->{config}->{DynamicEngine}->{WhiteIPRateList}} ){
			if ( $AI->is_ip_in_range($ip, $_) ){
				$self->{mail_info}->{aka}->{engine}->{dynamic} = {
	               			result  => 0,
	                                desc    => 'IP' . __("white list"),
       	                         	action  => 0,
	
                                	enabled => 1,
       	                         	runned  => 1,
                                	runtime => int(1000*tv_interval ($start_time, [gettimeofday]))
				};
				return ;
			}
		}
	
		($is_overrun,$reason) = $self->{dynamic}->is_overrun_rate_per_ip( $ip );
		if ( $is_overrun ){
			$self->{mail_info}->{aka}->{engine}->{dynamic} = {
	               			result  => $is_overrun,
	                                desc    => 'IP' . $reason,
       	                         	action  => 1,
	
                                	enabled => 1,
       	                         	runned  => 1,
                                	runtime => int(1000*tv_interval ($start_time, [gettimeofday]))
			};
			$self->{mail_info}->{aka}->{drop} = 1;
			return ;
		}
	}

	$self->{mail_info}->{aka}->{engine}->{dynamic} = {
		result  => 0,
		desc    => __("Overrun check was passed"),
		action  => 0,

		enabled => 1,
		runned  => 1,
		runtime => int(1000*tv_interval ($start_time, [gettimeofday]))
	};
	return ;
}

sub content_engine
{
	my $self = shift;

	return unless ( $self->content_engine_is_enabled() );

	# content parser get all mail information, and return it.
#$self->{zlog}->debug( "content_engine 1 action: [" . $self->{mail_info}->{aka}->{engine}->{content}->{action} . "]" );
	$self->{mail_info} = $self->{content}->process( $self->{mail_info} );
#$self->{zlog}->debug( "content_engine 2 action: [" . $self->{mail_info}->{aka}->{engine}->{content}->{action} . "]" );

	$self->{mail_info}->{aka}->{drop} ||= ( 
						( ACTION_REJECT eq $self->{mail_info}->{aka}->{engine}->{content}->{action} )
						||
						( ACTION_DISCARD eq $self->{mail_info}->{aka}->{engine}->{content}->{action} )
						||
						( ACTION_QUARANTINE eq $self->{mail_info}->{aka}->{engine}->{content}->{action} )
					      );
	#$self->{mail_info}->{aka}->{drop_info} ||= '553 ' . $self->{mail_info}->{aka}->{engine}->{content}->{desc};

	return;
}

sub content_engine_is_enabled
{	
	my $self = shift;
	my $mail_size = shift;


        my $start_time=[gettimeofday];

	if ( 'Y' ne uc $self->{conf}->{config}->{ContentEngine}->{ContentFilterEngine} ){
		$self->{mail_info}->{aka}->{engine}->{content} = {
               			result  => 0,
                                desc    => __("OFF"),
                        	action  => 0,

                               	enabled => 1,
                        	runned  => 1,
                              	runtime => int(1000*tv_interval ($start_time, [gettimeofday]))
		};
	
		return 0;
	}

	#
	# 判断保护方向
	#
	if ( $self->{mail_info}->{aka}->{RELAYCLIENT} || $self->{mail_info}->{aka}->{TCPREMOTEINFO} ){
		# 是“由内向外”
		if ( $self->{conf}->{config}->{ContentEngine}->{ProtectDirection}!~/Out/ ){
			# 没有限制“由内向外”的邮件
			$self->{mail_info}->{aka}->{engine}->{content} = {	
					result	=>0,
					desc	=>__("Outgoing mail need not filter"),
					action	=>ACTION_PASS,

                  			enabled => 1,
                     			runned  => 1,
                                	runtime => int(1000*tv_interval ($start_time, [gettimeofday]))
			};
			return 0;
		}

	}else{
		# 是“由外向内”
		if ( $self->{conf}->{config}->{ContentEngine}->{ProtectDirection}!~/In/ ){
			# 没有限制“由外向内”的邮件
			$self->{mail_info}->{aka}->{engine}->{content} = {
					result  => 0,
					desc	=> __("Incoming mail need not filter"),
					action  => 0,

					enabled => 1,
					runned  => 1,
					runtime => int(1000*tv_interval ($start_time, [gettimeofday]))
			};
			return 0;
		}

	}


	if ( $self->{conf}->{intconf}->{ContentEngineMaxMailSize} ){
		if ( $self->{mail_info}->{aka}->{size} > $self->{conf}->{intconf}->{ContentEngineMaxMailSize} ){
			$self->{mail_info}->{aka}->{engine}->{content} = {
               			result  => 0,
                                desc    => __("Maximum size excceed"),
                        	action  => 0,

                               	enabled => 1,
                        	runned  => 1,
                              	runtime => int(1000*tv_interval ($start_time, [gettimeofday]))
			};
			return 0;
		}
	}

	return 1;
}

# move check license to here to prevent hacker
sub check_license_file
{
	my $self = shift;

	my $licensefile = $self->{conf}->{define}->{licensefile};

	my $LicenseHTML;

	if ( ! open( LFD, "<$licensefile" ) ){
		$self->{zlog}->debug ( "AKA::License::check_license_file no [$licensefile]" );
		# No license
		return (0, __("System has no valid license now") );
	}
	
	my $license_content;
	my $license_data;
	my $license_checksum;
	my $hardware_license;
	my $expire_date;
	
	while ( <LFD> ){
		chomp;
		s/[\r\n]+$//;
		if ( /^ProductLicenseExt=(.+)$/ ){
			$license_checksum = $1;
			next;
		}elsif ( /^ProductLicense=(.+)$/ ){
			$license_data = $1;
			$license_data =~ s/\s*//g;
		}elsif ( /^LicenseHTML=(.+)$/ ){
			$LicenseHTML = $1 . '<br>';
		}elsif ( /^HardwareLicense=(.+)$/ ){
			$hardware_license = $1;
		}elsif ( /^ExpireDate=(.+)$/ ){
			$expire_date = $1;
		}

		$license_content .= $_;
		$license_content .= "\n";
	}
	# trim tail \n
	
	$license_content =~ s/\n+$//;

	unless ( defined $license_content && defined $license_checksum && 
			length($license_content) && length($license_checksum) ){
		#$self->{zlog}->debug ( "AKA::License::check_license_file can't get enough information from [$licensefile]" );
		return (0,__("License error ") . "#1");
	}

	my $cmp_str;

	$cmp_str=$self->{license}->get_valid_license($self->{license}->get_prodno) ;

	if ( $cmp_str ne $license_data ){
		#print "license_data $license_data ne $cmpstr\n";
		#$self->{zlog}->debug ( "AKA::License::check_license_file licese check failed!" );
		return (0,__("License error ") . "#2");
	}
	if( !$self->{license}->is_valid_checksum( $license_content, $license_checksum ) ){
		#print "checksum $license_checksum not valid for [$license_content]\n";
		#$self->{zlog}->debug ( "AKA::License::check_license_file not valid!" );
		return (0,__("License error ") . "#3");
	}

	if ( defined $hardware_license && length($hardware_license) ){
		my ($hwok,$hwinfo) = $self->{license}->check_hardware ( $hardware_license );
		unless ( $hwok ){
			#$self->{zlog}->debug ( "AKA::License::check_license_file hardware err [$hwinfo]!" );
			return ($hwok,$hwinfo) 
		}
	}

	if ( length($expire_date) ){
		my ($dateok, $dateinfo) = $self->{license}->check_expiredate ( $expire_date );
		unless ( $dateok ){
			#$self->{zlog}->debug ( "AKA::License::check_license_file expire err [$dateinfo]!" );
			return ($dateok,$dateinfo) 
		}
		$LicenseHTML .= $dateinfo if ( $dateinfo );
	}

	# it's valid
	$LicenseHTML ||= __("License valid!");
	return (1,$LicenseHTML);
}

sub get_mail_base_info
{
	my $self = shift;

	open ( MAIL, '<' . $self->{mail_info}->{aka}->{emlfilename} ) or return undef;

	my $still_headers = 1;
	my ($subject,$mail_from);
	while (<MAIL>) {
		chomp;
		if ( $still_headers ){
			if ( /^Subject: ([^\n]+)/i) 
			{
				$subject = $1 || '';
				$subject=~s/[\r\n]*$//g;
				if ($subject=~/^=\?[\w-]+\?B\?(.*)\?=$/) { 
					$subject = decode_base64($1); 
				}elsif ($subject=~/^=\?[\w-]+\?Q\?(.*)\?=$/) { 
					$subject = decode_qp($1); 
				}
			}
			elsif ( /^From: (.+)/ )
			{
				$mail_from = $1;
				if ( $mail_from=~m#([a-z0-9\.\-_]+\S+?\@\S+\.\S+[a-z0-9])\s*#i )
				{
					$mail_from = $1;
				}else{
					$mail_from = '';
				}
			}
			$still_headers = 0 if (/^(\r|\r\n|\n)$/);
		}
		last unless $still_headers;
	}
	close(MAIL);

	my ($returnpath, $recips);
	
	$_ = $self->{mail_info}->{aka}->{fd1};

    	my ($env_returnpath,$env_recips) = split(/\0/,$_,2);

	my ($one_recip, $trecips);
    	if ( ($returnpath=$env_returnpath) =~ s/^F(.*)$// ) {
      		$returnpath=$1;
      		($recips=$env_recips) =~ s/^T//;
      		$recips =~ /^(.*)\0+$/;
      		$recips=$1;
      		$recips =~ s/\0+$//g;
      		#Keep a note of the NULL-separated addresses
      		$trecips=$recips;
      		$one_recip=$trecips if ($trecips !~ /\0T/);
      		$recips =~ s/\0T/\,/g;
	}

#if ( $subject eq 'ZIXIA' ){
#	$self->{zlog}->log ( "ZIXIA SMTP MAIL FROM: [$returnpath] HEADER From: [$mail_from] ReturnPath [$return_path]" );
#	$self->{zlog}->log ( "ZIXIA AUTH: [" . $self->{mail_info}->{aka}->{TCPREMOTEINFO} . "]");
#}

	$self->{mail_info}->{aka}->{subject} = $subject;
	$self->{mail_info}->{aka}->{size} = -s $self->{mail_info}->{aka}->{emlfilename};

	$self->{mail_info}->{aka}->{returnpath} = $returnpath; # 这个是 smtp 协议中的 MAIL FROM: (.+)

	# MTA 的退信是没有Envelope from的，所以不可以这样。
	# $self->{mail_info}->{aka}->{returnpath} ||= $mail_from || $return_path; # XXX is this no problem?
	#$self->{mail_info}->{aka}->{return_path} = $return_path; # 这个是邮件头重的Return-Path

	$self->{mail_info}->{aka}->{mail_from} = $mail_from;
	$self->{mail_info}->{aka}->{recips} = $recips;
	$self->{mail_info}->{aka}->{env_returnpath} = $env_returnpath;
	$self->{mail_info}->{aka}->{env_recips} = $env_recips;
}

sub interactive_engine
{
	my $self = shift;

}

1;

