#!/usr/bin/perl
#
# File: ns-queue.pl
# Version: 1.20
#
# Author: Ed Li <zixia@zixia.net>
# 
#
###########################################################################
# This is UNPUBLISHED PROPRIETARY SOURCE CODE of AKA Information & Technology 
# (Beijing), Inc.; the contents of this file may not be disclosed to third 
# parties, copied or duplicated in any form, in whole or in part, without 
# the prior written permission of AKA Information & Technology (Beijing) 
# Inc.  
# Permission is hereby granted soley to the licencee for use of this 
# source code in its unaltered state. This source code may not be 
# modified by licencee except under direction of AKA Information & 
# Technology (Beijing) Inc. Neither may this source code be given under 
# any circumstances to non-licensees in any form, including source or 
# binary. Modification of this source constitutes breach of contract, 
# which voids any potential pending support responsibilities by AKA 
# Information & Technology (Beijing) Inc. Divulging the exact or paraphrased 
# contents of this source code to unlicensed parties either directly or 
# indirectly constitutes violation of federal and international copyright 
# and trade secret laws, and will be duly prosecuted to the fullest 
# extent permitted under law. 
# This software is provided by AKA Information & Technology (Beijing) 
# Inc. ``as is'' and any express or implied warranties, including, but 
# not limited to, the implied warranties of merchantability and fitness 
# for a particular purpose are disclaimed. In no event shall the regents 
# or contributors be liable for any direct, indirect, incidental, special, 
# exemplary, or consequential damages (including, but not limited to, 
# procurement of substitute goods or services; loss of use, data, or 
# profits; or business interruption) however caused and on any theory of 
# liability, whether in contract, strict liability, or tort (including 
# negligence or otherwise) arising in any way out of the use of this 
# software, even if advised of the possibility of such damage. 
###########################################################################

# We close stdout, for hide all warn.
# 2004-03-12 by Ed
open (NSOUT, ">&=2");
close (STDERR);
#open (STDERR,">/dev/null");
open (STDERR,">/tmp/ns-queue.STDERR");

use Time::HiRes qw( usleep ualarm gettimeofday tv_interval );
# ʱ���¼
my ( $start_time, $end_time );
my ( $ns_start_time );
$ns_start_time = [gettimeofday];

# 
# load time: use AKA::Mail
# check license: check_license_file
# run time: all

my ( $engine_netio_time );
my ( $engine_load_time, $engine_check_license_time, $engine_run_time );
my ( $engine_antivirus_run_time, $engine_spam_run_time, $engine_dynamic_run_time, 
	$engine_content_run_time, $engine_archive_run_time );


delete @ENV{qw(IFS CDPATH ENV BASH_ENV QMAILMFTFILE QMAILINJECT)};

use strict 'vars', 'subs';

use Sys::Syslog qw(:DEFAULT setlogsock);
setlogsock('unix');

my $VERSION="2.00";

# hash for all engine return data;
my $AKA_virus_result = {};

my ( $AKA_is_spam, $AKA_is_refuse_spam, $AKA_spam_reason ) = (0,0,'');
my ( $AKA_is_overrun, $AKA_overrun_reason ) = ( 0, '' );
my ( $AKA_is_archived ) = ( 0 );
my ( $decoded_subject, $mail_size ) = ( '', 0 );
# AKA::Mail
my $AM; 

# MSP 1.8 Э�鶯��
my $pf_action=0; my $pf_desc=""; my $pf_param="";
my $pf_mime_data;

my $V_HEADER="X-noSPAM";
#my($qsmsgid);
#$qsmsgid=tolower("$V_HEADER-message-id");


my ( $TagHead, $TagSubject, $TagReason, $SpamTag, $MaybeSpamTag ) ;
my $AKA_content_engine_enable = 0;
my $AKA_email_receiver_num = 0;

my $rm_binary="/bin/rm";

my $V_FROMNAME='noSPAM System Administrator';


#Array of virus scanners used must point to subroutines
#my @scanner_array=("spamassassin","spampolicefilter");


# The full path to qmail programs we'll need.
my $qmailinject = '/var/qmail/bin/qmail-inject';
my $qmailqueue  = '/var/qmail/bin/qmail-queue';

# What directory to use for storing temporary files.
my $scandir = '/home/NoSPAM/spool';

#What maildir folder to store working files in
my $wmaildir='working';

#What maildir folder to store quarantine in
my $vmaildir='quarantine';


#Name of file in $scandir where debugging output goes
my $debuglog="ns-queue.debug";

#If you want to log via file/syslog information of all Email
# that passes through your system (from/to/subj/size/attachments)
my $log_details="mailstats.csv";


$ENV{'PATH'}='/bin:/usr/bin';

#Generate nice random filename
my $hostname='gw.nospam.aka.cn';
#my $hostname=`/bin/hostname -f`; #could get via call I suppose...
#chomp $hostname;

#Maximum amount of time we allow Q-S to run before returning
# a temp failure. This is so remote SMTP servers don't get confused
# over whether or not they have delivered to a SMTP server
# that's refused to say "OK" for over an hour...
# We'll default to 20 minutes. If the scanner loop takes more than 20 
# minutes to scan the message, then something *must* be wrong with the
# scanner. 
my $MAXTIME=3*60;

#Want debugging? Enable this and read $scandir/qmail-queue.log
my $DEBUG='1';

#Want microsec times for debugging
use POSIX qw(strftime);

my $mail_info;
# �ж��Ƿ��������ⷢ��mail
my $ins_queue = 0;
if ( defined $ENV{RELAYCLIENT} ){
	$mail_info->{aka}->{RELAYCLIENT} = $ENV{RELAYCLIENT};
	$ins_queue = 1 ;
}elsif (defined $ENV{TCPREMOTEINFO}){
	# ������������֤���� TCPREMOTEINFO �ڴ�����û���
	$mail_info->{aka}->{TCPREMOTEINFO} = $ENV{TCPREMOTEINFO};
	$ins_queue = 2 ;
}

umask(0022);


my $file_id = $ENV{'AKA_FILE_ID'};
unless ( -f "$scandir/$wmaildir/new/$file_id" ){
    &error_condition("443 ns can't get file.", 150);
}
$mail_info->{aka}->{emlfilename} = "$scandir/$wmaildir/new/$file_id"; 

#For security reasons, tighten the follow vars...
$ENV{'SHELL'} = '/bin/sh' if exists $ENV{SHELL};
$ENV{'TMP'} = $ENV{'TMPDIR'} = "$scandir/tmp/$file_id";

#Get current timestamp for logs
my ($sec,$min,$hour,$mday,$mon,$year);
($sec,$min,$hour,$mday,$mon,$year) = localtime(time);
my $nowtime = strftime("%a, %d %b %Y %H:%M:%S %z", localtime(time));

my ($smtp_sender,$remote_smtp_ip,$uid);

if ($DEBUG ) {
  open(LOG,">>$scandir/$debuglog");
  select(LOG);$|=1;
  &debug("+++ starting debugging for process $$ by uid=$uid at $nowtime");
}

my ($smtp_sender,$remote_smtp_ip);


if ($ENV{'TCPREMOTEIP'}) {
  $smtp_sender="via SMTP from $ENV{'TCPREMOTEIP'}";
  $remote_smtp_ip=$ENV{'TCPREMOTEIP'};
  $mail_info->{aka}->{TCPREMOTEIP} = $ENV{'TCPREMOTEIP'};
  &debug("incoming SMTP connection from $smtp_sender");
} else {
  $smtp_sender="via local process $$";
  $remote_smtp_ip='127.0.0.1';
  $mail_info->{aka}->{TCPREMOTEIP} = '127.0.0.1';
  &debug("incoming pipe connection from $smtp_sender");
}

my ($env_returnpath, $returnpath);
my ($env_recips, $recips, $trecips, $recip, $one_recip);
my ($alarm_status,$elapsed_time,$msg_size);
my $xstatus=0;

#Now alarm this area so that hung networks/virus scanners don't cause 
#double-delivery...

eval {
  $SIG{ALRM} = sub { die "Maximum time exceeded. Something cannot handle this message." };
  alarm $MAXTIME;

  #Now unset env var QMAILQUEUE so any further Email's sent don't
  #go through the Qmail-Scanner again
  #&debug("unsetting QMAILQUEUE env var");
  delete $ENV{'QMAILQUEUE'};
  
  #This SMTP session is incomplete until we see dem envelope headers!
  &grab_envelope_hdrs;
  &debug("from=$returnpath,to=$recips, smtp=$remote_smtp_ip");
  #$mail_info->{aka}->{returnpath} = $returnpath;



  &AKA_engine_run;
  
  if ( 2==$pf_action ){
    &debug("pf: discard action 2" );
    delete $ENV{'TCPREMOTEIP'};
  } else {
    &qmail_parent_check;
    &qmail_requeue($env_returnpath,$env_recips,"$scandir/$wmaildir/new/$file_id"); 
  }
  alarm 0;
};

$alarm_status=$@;
if ($alarm_status and $alarm_status ne "" ) { 
  if ($alarm_status eq "Maximum time exceeded. Something cannot handle this message.") {
    &error_condition("553 ALARM: taking longer than $MAXTIME secs. Requeuing...", 150);
  } else {
    &error_condition("553 Requeuing: $alarm_status", 150);
  }
}


&cleanup;

&debug("AKA performance:"
	#. ' N:' . $ns_start_time
	. ' MS:' . $mail_size
	. "\t NS:" . int(1000*tv_interval($ns_start_time, [gettimeofday]))/1000
	, ' IO:' . $engine_netio_time
	. ' LD:' . $engine_load_time 
	. ' CL:' . $engine_check_license_time
	. ' ER:' . $engine_run_time
	. ' SP:' . $engine_spam_run_time
	. ' DY:' . $engine_dynamic_run_time
	. ' CT:' . $engine_content_run_time
	. ' secs'
	);
exit 0;

############################################################################
# Error handling
############################################################################


# Fail with the given message and a temporary failure code.
sub error_condition {
  my ($string,$errcode)=@_;
  $errcode=111 if (!$errcode);
  eval {
    syslog('mail|err',"$V_HEADER-$VERSION:[$file_id] $string");
  };
  if ($@) {
    setlogsock('inet');
    syslog('mail|err',"$V_HEADER-$VERSION:[$file_id] $string");
  }
  if ($log_details ne "syslog") {
    #warn "$V_HEADER-$VERSION:[$file_id] $string\n";
    &debug ( "$V_HEADER-$VERSION:[$file_id] $string\n" );
  }
  $nowtime = sprintf "%02d/%02d/%02d %02d:%02d:%02d", $mday, $mon+1, $year+1900, $hour, $min, $sec;
  &debug("error_condition: $V_HEADER-$VERSION: $string");
  close(LOG);
  &cleanup;

  print NSOUT $string, "\r\n";
  exit $errcode;
}

sub debug {
  print LOG "$nowtime:$$: ",@_,"\n" if ($DEBUG);
}

sub grab_envelope_hdrs {
  select(STDOUT); $|=1;
  
  open(SOUT,"<&1")||&error_condition("cannot dup fd 0 - $!");
  while (<SOUT>) {
    $mail_info->{aka}->{fd1} = $_;
    ($env_returnpath,$env_recips) = split(/\0/,$_,2);
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
    #only meant to be one line!
    last;
  }
  close(SOUT)||&error_condition("cannot close fd 1 - $!");
  if ( ($env_returnpath eq "" && $env_recips eq "") || ($returnpath eq "" && $recips eq "") ) {
    #At the very least this is supposed to be $env_returnpath='F' - so
    #qmail-smtpd must be officially dropping the incoming message for
    #some (valid) reason (including the other end dropping the connection).
    &debug("g_e_h: no sender and no recips.");
    &cleanup;
    exit;
  }
  &debug("g_e_h: return-path is \"$returnpath\", recips is \"$recips\"");
}


sub AKA_engine_run {
  chdir("$ENV{'TMPDIR'}/");
  
  #
  # Load AKA Mail Engine Module & init it
  #
  use AKA::Mail;
  $AM = new AKA::Mail;

  #
  # Check License
  #
  $start_time=[gettimeofday];

  #&check_license;

  $engine_check_license_time = int(1000*tv_interval ($start_time, [gettimeofday]))/1000;
  &debug("AKA_check_license_engine $$: in $engine_check_license_time secs");

  #
  # Run it
  #
  $start_time=[gettimeofday];

  $mail_info = $AM->process( $mail_info );

  use Data::Dumper;
  open ( FD, ">/tmp/zixia.debug" );
  print FD Dumper($mail_info);
  close ( FD );
  ( $TagHead, $TagSubject, $TagReason, $SpamTag, $MaybeSpamTag ) = $AM->get_spam_tag_params;

  undef $AM;
  chdir("$scandir");
}

sub qmail_requeue {
  my($sender,$env_recips,$msg)=@_;
  my ($temp,$findate);

  &debug("q_r: fork off child into $qmailqueue...");
  
  # Create a pipe through which to send the envelope addresses.
  pipe (EOUT, EIN) or &error_condition("Unable to create a pipe. - $!");
  select(EOUT);$|=1;
  select(EIN);$|=1;
  # Fork qmail-queue.  The qmail-queue child will then open fd 0 as
  # $message and fd 1 as the reading end of the envelope pipe and exec
  # qmail-queue.  The parent will read in the addresses and pass them 
  # through the pipe and then check the exit status.

  $elapsed_time = tv_interval ($start_time, [gettimeofday]);
  local $SIG{PIPE} = 'IGNORE';
  my $pid = fork;

  if (not defined $pid) {
    &error_condition ("Unable to fork. (#4.3.0) - $!");
  } elsif ($pid == 0) {
    # In child.  Mutilate our file handles.
    close EIN; 
    
    open(STDIN,"<$msg")|| &error_condition ("Unable to reopen fd 0. (#4.3.0) - $!");

    open (STDOUT, "<&EOUT") ||  &error_condition ("Unable to reopen fd 1. (#4.3.0) - $!");
    select(STDIN);$|=1;
    &debug("q_r: xstatus=$xstatus");
    open (QMQ, "|$qmailqueue")|| &error_condition ("Unable to open pipe to $qmailqueue [$xstatus] (#4.3.0) - $!");
    ($sec,$min,$hour,$mday,$mon,$year) = gmtime(time);
    $elapsed_time = tv_interval ($start_time, [gettimeofday]);
    $findate = POSIX::strftime( "%d %b ",$sec,$min,$hour,$mday,$mon,$year);
    $findate .= sprintf "%02d %02d:%02d:%02d +8000", $year+1900, $hour, $min, $sec;
#    print QMQ "Received: from $returnpath by $hostname by uid $uid with qmail-scanner-$VERSION \n";

    print QMQ "Received: from $returnpath by $hostname by uid $uid with noSPAM-${VERSION} \n";
    print QMQ " Processed in $elapsed_time secs); $findate\n";


    my ($pf_hdr_key,$pf_hdr_done);
    if (  11<=$pf_action && 13>=$pf_action ){
	$pf_hdr_done = 0;
	if ( $pf_param =~ /^([^:]+): /){
		$pf_hdr_key = $1;
	}elsif ( 12!=$pf_action ){
		&debug ( "pf: pf_param: [$pf_param] can't parse to header data when requeue, pf_action: [$pf_action]" );
	}
    }else{
	$pf_hdr_done = 1;
    }


    my $still_headers=1;
    my $seen_env=0;


    while (<STDIN>) {
      if ($still_headers) {
        if ( !$pf_hdr_done && (11<=$pf_action || 13>=$pf_action) ){
		if ( 11==$pf_action ){
			# 11��addhdr �����ͷ��¼����һ���ַ�������������Ϊ�µ���ͷ��¼
			print QMQ "$pf_param\n";
			$pf_hdr_done = 1;
		}elsif (12==$pf_action ){
			# 12��delhdr ɾ����ͷ��¼��ɾ��ƥ�䵽ָ����ͷ�������ͷ��¼���ö���ֻ��������ͷ������ʹ�ã����޲���
			if ( /^$pf_hdr_key: / ){
				#FIXME ��������е�header����Ҫ�ر���
				$pf_hdr_done = 1;
				next;
			}
		}elsif (13==$pf_action ){
			# 13��chghdr �޸���ͷ��¼����ƥ�䵽ָ����ͷ�������ͷ��¼�����µ���ͷ��¼���ö���ֻ��������ͷ������ʹ�ã���
			# ��һ���ַ�������������Ϊ�µ���ͷ��¼
			if ( /^$pf_hdr_key: / ){
				chomp $pf_param;
				$_ = $pf_param . "\n";
				$pf_hdr_done = 1;
			}
		}
	}
	if (/^Subject: (.+)/i){
#&debug ("SUBJECT  $1");
#&debug ("SUBJECT  TagSubject: [$TagSubject] spam: [$AKA_is_spam]");
		if ( 'Y' eq uc $TagSubject ){
			if ( 1==$AKA_is_spam ){
				$_ = "Subject: " . $MaybeSpamTag . " $1\n"; 
			}elsif ( 2==$AKA_is_spam ){
				$_ = "Subject: " . $SpamTag . " $1\n"; 
			}elsif ( 3==$AKA_is_spam ){
				$_ = "Subject: " . "����������" . " $1\n"; 
			}
		}
#&debug ("SUBJECT  $_");
	}
	if (/^(\r|\r\n|\n)$/){
		$still_headers=0 ;
		print QMQ "X-Checker-Version: noSPAM v$VERSION\n";

		if ( 'Y' eq uc $TagReason ){
			print QMQ "X-Spam-Checker-Result: \n";
			print QMQ "  S:$AKA_is_spam R:$AKA_spam_reason\n";
			print QMQ "  D:$AKA_is_overrun P:$AKA_overrun_reason\n";
			if ( $AKA_content_engine_enable ){
				print QMQ "  A:$pf_action P:$pf_param I:$pf_desc\n";
			}
		}

		if ( $AKA_is_spam && ('Y' eq uc $TagHead) ){
			print QMQ "X-Spam-Flag: YES\n";
		}else{
			print QMQ "X-Spam-Flag: NO\n";
		}
	}
      }
      print QMQ;
    }
    close(QMQ); #||&error_condition("Unable to close pipe to $qmailqueue (#4.3.0) - $!");
    $xstatus = ( $? >> 8 );
    if ( $xstatus > 10 && $xstatus < 41 ) {
      &error_condition("mail server permanently rejected message. (#5.3.0) - $!",$xstatus);
    } elsif ($xstatus > 0) {
      &error_condition("Unable to open pipe to $qmailqueue [$xstatus] (#4.3.0) - $!",$xstatus);
    }
    #This child is finished - exit
    exit;
  } else {
    # In parent.
    close EOUT;
      
    # Feed the envelope addresses to qmail-queue.
    my $envelope = "$sender\0$env_recips";
    $envelope =~ s/\0/\\0/g;
    &debug ( "q_r_q: envelope data: [$envelope]" );
    print EIN "$sender\0$env_recips";
    close EIN  || &error_condition ("Write error to envelope pipe. (#4.3.0) - $!");
}

  # We should now have queued the message.  Let's find out the exit status
  # of qmail-queue.
  waitpid ($pid, 0);
  $xstatus =($? >> 8);
  if ( $xstatus > 10 && $xstatus < 41 ) {
    &error_condition("mail server permanently rejected message. (#5.3.0) - $!",$xstatus);
  } elsif ($xstatus > 0) {
    &error_condition("Unable to close pipe to $qmailqueue [$xstatus] (#4.3.0) - $!",$xstatus);
  }
}

sub cleanup {
  closelog;
  chdir("$scandir/");

  rmdir("$ENV{'TMPDIR'}") && unlink("$scandir/$wmaildir/new/$file_id" );
}

# zixia: send $email_file to $to ( if have $to ), and add $sign to the end of email body
sub send_email_file {
  my($to, $email_file, $sign )=@_;

  if ( !$to || !length($to) ){
  	&debug("e_s: sending email no to: [$to] specified.");
	return;
  }

  if ( ! open(EML, "<$email_file") ){
  	&debug("e_s: sending email file to $to open $email_file error.");
	# not this function's duty: unlink ( $email_file );
	return;
  }
	
  open(SM,"|$qmailinject -h -f ''")||&error_condition("s_e_f: cannot open $qmailinject for sending quarantine report - $!");
  &debug("e_s: sending email file via: $qmailinject to address ($to)");

  my $in_header = 1;
  while ( <EML> ){
	if ( $in_header ){
      		if (/^(\r|\r\n|\n)$/) {
			$in_header = 0;
		}elsif (/^To: \S+/){
  			$_ = "To: $to\n";
		}elsif ( /^CC: /i || /^BCC: /i ){
			# only send to archiver! -_-b
			next;
		}
	}
	print SM;
  }
  print SM "\n$sign";


  close(SM);
  close(EML);

}


sub qmail_parent_check {
  my $ppid=getppid;
  #&debug("q_s_c: PPID=$ppid");
  if ($ppid == 1)  {
    &debug("q_s_c: Whoa! parent process is dead! (ppid=$ppid) Better die too...");
    close(LOG);
    &cleanup;
    #Exit with temp error anyway - just to be real anal...
    exit 111; 
  }
}

sub AKA_mail_engine {
  	my ($cmdline_recip);

  	#Cleanup $one_recip so it's usable from the commandline...
  	#any char that isn't supported to changed into an '_'
  	($cmdline_recip=$one_recip)=~s/[^0-9a-z\.\_\-\=\+\@]/_/gi;
  	$cmdline_recip=~/^([0-9a-z\.\_\-\=\+\@]+)$/i;
  	$cmdline_recip=tolower($1);

	#
	# AntiVirus Engine
	#
  	$start_time=[gettimeofday];
	$AKA_virus_result =$AM->antivirus_engine( "$scandir/$wmaildir/new/$file_id" );
  	$engine_antivirus_run_time = int(1000*tv_interval ($start_time, [gettimeofday]))/1000;
  	&debug("AKA_antivirus_engine $$: in $engine_antivirus_run_time secs ["
			. $AKA_virus_result->{Result} 
			. ',' . $AKA_virus_result->{Reason}
			. ',' . $AKA_virus_result->{Action}
			. ']' );

	# ����ǲ�����������Ҫ�ܾ����������������棻
	if ( $AKA_virus_result->{Result}>0 && $AKA_virus_result->{Action}>0 ){
		#&debug ( "FOUND virus AND DROP IT!" );
		($AKA_is_spam, $AKA_spam_reason) = (0,'δ���������');
		$AKA_content_engine_enable = 1; $pf_action = 6; $pf_param = ''; $pf_desc = "δ�����ݼ��";
	 	($AKA_is_overrun, $AKA_overrun_reason ) = (0, 'δ����̬���');
		goto NOSPAM_LOG;
	}
	
	#
	# SPAM Engine
	#
  	$start_time=[gettimeofday];
	# ����������ⷢ�ͣ������п�׷���Լ��
	if ( $ins_queue ){
		($AKA_is_spam, $AKA_spam_reason) = (0,'�����û�') if ( 1==$ins_queue );
		($AKA_is_spam, $AKA_spam_reason) = (0,'��֤�û�') if ( 2==$ins_queue );
		$AKA_is_refuse_spam = 0;
	}else{
		($AKA_is_spam, $AKA_spam_reason) = &AKA_mail_spam_engine;
		$AKA_is_refuse_spam = $AM->should_refuse_spam;
	}
  	$engine_spam_run_time = int(1000*tv_interval ($start_time, [gettimeofday]))/1000;
  	&debug("AKA_spam_engine $$: in $engine_spam_run_time secs [$AKA_is_spam, $AKA_spam_reason, $AKA_is_refuse_spam]");

	#
	# Content Engine
	#
  	$start_time=[gettimeofday];

  	$AKA_content_engine_enable = $AM->content_engine_is_enabled($mail_size);

	if ( $AKA_content_engine_enable ){
		# pf_mime_data && pf_action & pf_param & pf_desc(rule_id) is global var, and set in function, no need to return.
		&AKA_mail_content_engine;
	}else{
		$pf_action = 7; $pf_param = ""; $pf_desc = "";
	}
  	$engine_content_run_time = int(1000*tv_interval ($start_time, [gettimeofday]))/1000;
  	&debug("AKA_content_engine $$: in $engine_content_run_time secs [$pf_action, $pf_param, $pf_desc]");


	#
	# Dynamic Engine
	#
  	$start_time=[gettimeofday];
	if ( 1==$ins_queue ){
	 	( $AKA_is_overrun, $AKA_overrun_reason ) = (0, '�����û�');
	}elsif ( 2==$ins_queue ){
	 	( $AKA_is_overrun, $AKA_overrun_reason ) = (0, '��֤�û�');
	}else{
	 	( $AKA_is_overrun, $AKA_overrun_reason ) = $AM->dynamic_engine( $decoded_subject, $returnpath, $remote_smtp_ip );
	}
  	$engine_dynamic_run_time = int(1000*tv_interval ($start_time, [gettimeofday]))/1000;
  	&debug("AKA_dynamic_engine $$: in $engine_dynamic_run_time secs [$AKA_is_overrun, $AKA_overrun_reason]");

	#
	# Archive_engine
	#
  	$start_time=[gettimeofday];
	$AKA_is_archived = $AM->archive_engine( "$scandir/$wmaildir/new/$file_id", $AKA_is_spam, $pf_desc );
  	$engine_archive_run_time = int(1000*tv_interval ($start_time, [gettimeofday]))/1000;
  	&debug("AKA_archive_engine $$: in $engine_archive_run_time secs");

NOSPAM_LOG:
	#&noSPAM_log;

	#sub noSPAM_log {
		my $esc_subject = $decoded_subject;
		$esc_subject=~s/,/_/g;
		$esc_subject=~s/[\r|\n]+//g;

# prevent half chinese character upset csv comma.
		$esc_subject = ' ' . $esc_subject . ' ';

		use Fcntl ':flock';
		if ( open ( LFD, ">>/var/log/NoSPAM.csv" ) ){
			flock(LFD,LOCK_EX);
			seek(LFD, 0, 2);
#print LFD strftime("%Y-%m-%d %H:%M:%S", localtime) 
			print LFD time
# ins-queue is link of ns-queue for internal mail scan, 0 means Ext->Int, 1 means Int->Ext
				. ',' . ($ins_queue?'1':'0') 
				. ",$remote_smtp_ip,$returnpath,$one_recip, $esc_subject "
				. ",$AKA_is_spam,$AKA_spam_reason," . ($AKA_is_spam?$AKA_is_refuse_spam:'0')

				. ',' . $AKA_virus_result->{Result}
					. ',' . $AKA_virus_result->{Reason} 
					. ',' . ($AKA_virus_result->{Result}?$AKA_virus_result->{Action}:6)

				. "," . ($AKA_content_engine_enable?$pf_desc:"�ʼ����������δ����") . ",$pf_action,$pf_param"
				. ",$AKA_is_overrun, $AKA_overrun_reason\n";
			flock(LFD,LOCK_UN);
			close(LFD);
		}else{
			&debug ( "AKA_mail_engine::log open NoSPAM.csv failure." );
		}
	#}
	
	######################## action #################################3

	# XXX we now drop virus
	if ( $AKA_virus_result->{Result}>0 && $AKA_virus_result->{Action}>0 ){
		&cleanup;
		exit ( 0 );
	}

	# ret code should be 31: mail server permanently rejected message (#5.3.0)";
	if ( $AKA_is_spam && $AKA_is_refuse_spam){
		&error_condition ( "553 �Բ�����Ϊ" . $AKA_spam_reason . 
			"�������ʼ���ϵͳ����Ϊ�����ʼ�����������ѯ�ʼ�����Ա��", 150 );
		&cleanup;
		exit ( 150 );
	}

	if ( $AKA_is_overrun ){
		# XXX 553 to performance reason
		&error_condition ( "451 �Բ�����Ϊ" . $AKA_overrun_reason . 
		#&error_condition ( "553 �Բ�����Ϊ" . $AKA_overrun_reason . 
			"�������ʼ���ϵͳ����Ϊ�����ʼ�������ѯ�ʼ�����Ա��", 150 );
		&cleanup;
		exit ( 150 );
	}

	&AKA_mail_content_engine_action;

}

sub AKA_mail_content_engine
{
  my ($start_content_engine_time)=[gettimeofday];
  my ($stop_content_engine_time,$content_engine_time);

  open(PF,"<$scandir/$wmaildir/new/$file_id")||&error_condition("pf1: cannot open $scandir/$wmaildir/new/$file_id - $!");
  ($pf_action, $pf_param, $pf_desc, $pf_mime_data) = $AM->content_engine_mime(\*PF);
  close PF ;

  # TODO: no need to write file so early, should be moved to qmail_requeue.
  # XXX why we rewrite mail file? by zixia 2004-04-12
  if ( defined $pf_mime_data && length($pf_mime_data) ){
	open (PF, ">$scandir/$wmaildir/new/$file_id.pf") ||&error_condition("pf2: cannot open $scandir/$wmaildir/new/$file_id.pf - $!");
	print PF $pf_mime_data;
	close (PF);
  	rename ("$scandir/$wmaildir/new/$file_id.pf","$scandir/$wmaildir/new/$file_id");
  }
  # ȱʡ������Ͷ��
  $pf_action=7 if (!$pf_action);
  $pf_param='' if (!$pf_param);
  $pf_desc='' if (!$pf_desc);

  &debug( "PF: action: $pf_action, param: ($pf_param), desc: $pf_desc" );

  $stop_content_engine_time=[gettimeofday];
  $content_engine_time = tv_interval ($start_content_engine_time, $stop_content_engine_time);
  &debug("AKA_mail_content_engine: finished scan of dir \"$ENV{'TMPDIR'}\" in $content_engine_time secs");
  return 1;
}

#sub AKA_police_action
sub AKA_mail_content_engine_action
{
  # ��ȡ��ʩ
  if ( 1==$pf_action ){
	# 1��reject�����ء��ܾ��ʼ�����һ���ַ�������������Ϊ�����ʼ�ʱ���صĴ�����Ϣ��
	# ȱʡΪ'This message was rejected'
	$pf_param ||= 'This message was rejected';
	&error_condition ( "553 " . $pf_param . "(#5.7.1)", 150 );
  }elsif (  2==$pf_action ){
	# 2��discard �����ʼ����޲���
	# XXX �� init_scanner ��ֱ���ж�

  }elsif (  3==$pf_action ){
	# 3��quarantine �����ʼ�����һ���ַ�������������Ϊ�����ʼ��Ĵ��Ŀ¼��
	# ȱʡΪ'/var/spool/uncmgw/Quarantines'
	#$quarantine_event = "Police Quarantine policy";
	if ( $pf_param=~m#^/var/spool/uncmgw/# ){
		if (! -d "$pf_param") {
  			`mkdir -p /$pf_param`;
		}
		`mv -f $scandir/$wmaildir/new/$file_id /$pf_param/`;
	}else{
		&debug ( "pf: action 3 quarantine dir must be default now, but pf_param is: [$pf_param]" );
	}
	# drop after quarantine;
	$pf_action = 2;
  }elsif (  4==$pf_action ){
	# 4��strip �����ʼ��еĸ�������һ���ַ�������������Ϊ�滻�������������ı���Ϣ���ݣ�
	# ȱʡΪ'�ʼ������а����в���ȫ�ļ�\$file���Ѿ������룡'
	#TODO

  }elsif (  5==$pf_action ){
	# 5�� delay ���ʼ������������ʱ(��)����һ����������������Ϊ�����ʱ������
	#TODO
	if ( $pf_param=~/(\d+)/ ){
		my $sec = $1;
		sleep ( $sec>120?120:$sec );
	}
  }elsif (  6==$pf_action ){
	# 6�� null �����κβ������޲���
  }elsif (  7==$pf_action ){
	# 7��accept ���ܸ��ʼ��������ַ����޲���
  }elsif (  8==$pf_action ){
	# 8��addrcpt ��������ռ��ˡ���һ���ַ�������������Ϊ��ӵ��ռ����ʼ���ַ
	if ( ! $pf_param=~/^[\w\d\.-_=+]+\@[\w\d\.-_=+]+$/ ){
		&debug("pf_a: addrcpt param is: [$pf_param] invalid email address.");
		return;
	}
	$env_recips = "T$pf_param\0" . $env_recips;
  }elsif (  9==$pf_action ){
	# 9��delrcpt ɾ��ָ���ռ��ˣ��ö���ֻ�������ŷ��ռ��˵���ͷ������ʹ�ã����޲���
	if ( ! $pf_param=~/^[\w\d\.-_=+]+\@[\w\d\.-_=+]+$/ ){
		&debug("pf_a: delrcpt param is: [$pf_param] invalid email address.");
		return;
	}
	# one recip, or first 
	$env_recips =~ s/T$pf_param\0//;

	if ( 3>length($env_recips) ){
		# only one recip, should be droped after delrcpt
		$pf_action = 2;
		undef $env_recips;
	}#else{
#XXX ��ʹ��һ����ַ����βҲ������\0?
		#ԭ���ж������ɾ��ʣ��һ������β�����һ�� \0
#		my @recips = split(/T/,$env_recips);
#		if ( 1==@recips ){
#			$env_recips=~s#\0\0$#\0#;
#		}
#	}
  }elsif (  10==$pf_action ){
	# 10��chgrcpt �ı�ָ�����ռ���Ϊ�µ��ռ��ˣ��ö���ֻ�������ŷ��ռ��˵���ͷ������ʹ�ã�����һ���ַ�������������Ϊ�µ��ռ����ʼ���ַ
	if ( ! $pf_param=~/^[\w\d\.-_=+]+\@[\w\d\.-_=+]+$/ ){
		&debug("pf_a: chgrcpt param is: [$pf_param] invalid email address.");
		return;
	}
	# either one recip or more recips, need two NULL terminater.
	$env_recips = "T$pf_param\0\0";
  }elsif (  11==$pf_action ){
	# XXX 11,12,13 action do at qmail_rqueuen.
	# 11��addhdr �����ͷ��¼����һ���ַ�������������Ϊ�µ���ͷ��¼
  }elsif (  12==$pf_action ){
	# 12��delhdr ɾ����ͷ��¼��ɾ��ƥ�䵽ָ����ͷ�������ͷ��¼���ö���ֻ��������ͷ������ʹ�ã����޲���
  }elsif (  13==$pf_action ){
	# 13��chghdr �޸���ͷ��¼����ƥ�䵽ָ����ͷ�������ͷ��¼�����µ���ͷ��¼���ö���ֻ��������ͷ������ʹ�ã���
	# ��һ���ַ�������������Ϊ�µ���ͷ��¼

  }

}

sub AKA_mail_spam_engine
{
	my ( $smtp_ip, $email_domain );

# ?��2aSPAM��??����?
#       2?��y ( smtp_ip, from_addr )
#       ����?? ( is_spam, reason )
#               is_spam: 0: NOT spam
#                        1: Maybe Spam
#                        2: SPAM
#                        3: Black List

  	my ($start_spam_engine_time)=[gettimeofday];

	&debug ("AKA-Spam: entered AKA_mail_spam_engine." );

	if ( ! $remote_smtp_ip ){
		&debug ( "AKA_mail_spam_engine: can't get remote_smtp_ip." );
		&error_condition( "553 IP information temporary unusable. (#4.3.0)", 150 );
	}
	
	# allow localhost free relay
	return (0, "����IP") if $remote_smtp_ip eq '127.0.0.1';

	my $is_spam = 0;
	my $reason;

	my ( $is_spam, $reason );

	if ( defined $returnpath && length($returnpath) ){
		( $is_spam, $reason ) = $AM->spam_engine($remote_smtp_ip, $returnpath);
		&debug ( "AKA_mail_spam_engine: is_spam: $is_spam, reason: $reason, smtp_ip: $remote_smtp_ip, mail_from: $returnpath" );
	} else {
		&debug ( "AKA_mail_spam_engine can't get returnpath from email_domain, assume it is SPAM!!" );
		($is_spam,$reason) = (1, "�ʼ���Ϣ��ȱ��ȫ");
	}

  	my $stop_spam_engine_time=[gettimeofday];
  	my $spam_engine_time = tv_interval ($start_spam_engine_time, $stop_spam_engine_time);
  	&debug("AKA_mail_spam_engine: finished in $spam_engine_time secs");

	return ($is_spam, $reason);
}

sub check_license
{
#	my $n = rand;
#	$n = int($n * 10);
#
	#if ( $n > 7 ){
        	if ( ! $AM->check_license_file ){
			&debug ( "!!!!!!!!!!!!!noSPAM System need a valid license, please contact the factory.!!!!!!!!!!!" );
 			&error_condition ( "553 �Բ��𣬱�ϵͳĿǰ��δ�����ȷ��License��ɣ�������ʱ�޷�������", 150 );
        	}
#	}
}
#
###########################################################################
# This is UNPUBLISHED PROPRIETARY SOURCE CODE of AKA Information & Technology 
# (Beijing), Inc.; the contents of this file may not be disclosed to third 
# parties, copied or duplicated in any form, in whole or in part, without 
# the prior written permission of AKA Information & Technology (Beijing) 
# Inc.  
# Permission is hereby granted soley to the licencee for use of this 
# source code in its unaltered state. This source code may not be 
# modified by licencee except under direction of AKA Information & 
# Technology (Beijing) Inc. Neither may this source code be given under 
# any circumstances to non-licensees in any form, including source or 
# binary. Modification of this source constitutes breach of contract, 
# which voids any potential pending support responsibilities by AKA 
# Information & Technology (Beijing) Inc. Divulging the exact or paraphrased 
# contents of this source code to unlicensed parties either directly or 
# indirectly constitutes violation of federal and international copyright 
# and trade secret laws, and will be duly prosecuted to the fullest 
# extent permitted under law. 
# This software is provided by AKA Information & Technology (Beijing) 
# Inc. ``as is'' and any express or implied warranties, including, but 
# not limited to, the implied warranties of merchantability and fitness 
# for a particular purpose are disclaimed. In no event shall the regents 
# or contributors be liable for any direct, indirect, incidental, special, 
# exemplary, or consequential damages (including, but not limited to, 
# procurement of substitute goods or services; loss of use, data, or 
# profits; or business interruption) however caused and on any theory of 
# liability, whether in contract, strict liability, or tort (including 
# negligence or otherwise) arising in any way out of the use of this 
# software, even if advised of the possibility of such damage. 
###########################################################################
