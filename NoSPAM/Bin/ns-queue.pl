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
# 时间记录
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

# MSP 1.8 协议动作
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
my $MAXTIME=20*60;

#Want debugging? Enable this and read $scandir/qmail-queue.log
my $DEBUG='1';

#Want microsec times for debugging
use POSIX;

use vars qw/ $opt_h $opt_z/;

use Getopt::Std;

getopts('vhgrz');

(my $prog=$0) =~ s/^.*\///g;

# 判断是否由内向外发的mail
my $ins_queue = 0;
#if ('ins-queue' eq $prog){
if ( defined $ENV{RELAYCLIENT} ){
	$ins_queue = 1 ;
}elsif (defined $ENV{TCPREMOTEINFO}){
	# 如果经过身份认证，则 TCPREMOTEINFO 内存的是用户名
	$ins_queue = 2 ;
}

if ( $opt_h ) {
  print "

$prog $ins_queue

    -h - This help
    -z - and cleanup old temp files\n";
  exit;
}

if ($opt_z) {
  &clean_zombie_file;
  exit 0;
}

umask(0022);


# XXX
my $file_id = $ENV{'AKA_FILE_ID'};
unless ( -f "$scandir/$wmaildir/tmp/$file_id" ){
    &error_condition("443 ns can't get file.", 150);
}

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
  &debug("incoming SMTP connection from $smtp_sender");
} else {
  $smtp_sender="via local process $$";
  $remote_smtp_ip='127.0.0.1';
  &debug("incoming pipe connection from $smtp_sender");
}

my (%headers );
my ($CRYPTO_TYPE,$altered_subject, $HEADERS, $env_returnpath, $returnpath);
my ($env_recips, $recips, $trecips, $recip, $one_recip);
my ($alarm_status,$elapsed_time,$msg_size,$file_desc);
my ($description,$quarantine_description,$illegal_mime);
my $xstatus=0;

# 将邮件进行初步检测，写入tmp，然后 link 覆盖原mail文件
$start_time = [gettimeofday];
&working_copy;
$engine_netio_time = int(1000*tv_interval ($start_time, [gettimeofday]))/1000;
&debug("AKA_netio_engine $$: in $engine_netio_time secs, data size: $mail_size ");

#Now alarm this area so that hung networks/virus scanners don't cause 
#double-delivery...

eval {
  $SIG{ALRM} = sub { die "Maximum time exceeded. Something cannot handle this message." };
  alarm $MAXTIME;

  #Now unset env var QMAILQUEUE so any further Email's sent don't
  #go through the Qmail-Scanner again
  &debug("unsetting QMAILQUEUE env var");
  delete $ENV{'QMAILQUEUE'};
  
  #This SMTP session is incomplete until we see dem envelope headers!
  &grab_envelope_hdrs;
  &debug("from=$returnpath,to=$recips, smtp=$remote_smtp_ip");


  &init_scanners;
  
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


#Msg has been delivered now, so don't want hangs in this part
#to affect delivery

if ($log_details) {
  if ($trecips =~ /\0T/) {
    for $recip (split(/\0T/,$trecips)) {
      #&log_msg("qmail-scanner",($quarantine_event ne "0" ? "$quarantine_event$tag_score" : "Clear$tag_score"),$elapsed_time,$msg_size,$returnpath,$recip,$headers{'subject'},$headers{$qsmsgid},$file_desc) if ($recip ne "");
    }
  } else {
    #Only one recip
    #&log_msg("qmail-scanner",($quarantine_event ne "0" ? "$quarantine_event$tag_score" : "Clear$tag_score"),$elapsed_time,$msg_size,$returnpath,$recips,$headers{'subject'},$headers{$qsmsgid},$file_desc);
  }
}
&cleanup;

($sec,$min,$hour,$mday,$mon,$year) = localtime(time);
$nowtime = sprintf "%02d/%02d/%02d %02d:%02d:%02d", $mday, $mon+1, $year+1900, $hour, $min, $sec;

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

sub working_copy {
  my ($hdr,$last_hdr,$value,$num_of_headers,$last_header,$last_value,$attachment_filename);
  
  &debug("w_c: mkdir $ENV{'TMPDIR'}");
  mkdir("$ENV{'TMPDIR'}",0700)||&error_condition("$file_id exists - try again later...");
  chdir("$ENV{'TMPDIR'}")||&error_condition("cannot chdir to $ENV{'TMPDIR'}/");

  open(TMPFILE,"<$scandir/$wmaildir/tmp/$file_id")||&error_condition("cannot read from $scandir/$wmaildir/tmp/$file_id - $!");
  
  my $still_headers=1;
  my $begin_content='';
  my $still_attachment='';
  while (<TMPFILE>) {
   if ( $still_headers ){
	if ( /^Subject: ([^\n]+)/i) {
#&debug( "SUBJECT $_" );
		$decoded_subject = $1 || '';
		$decoded_subject=~s/[\r\n]*$//g;
		if ($decoded_subject=~/^=\?[\w-]+\?B\?(.*)\?=$/) { 
   			use MIME::Base64; 
   			$decoded_subject = decode_base64($1); 
#&debug( "SUBJECT $1 / $decoded_subject" );
		}elsif ($decoded_subject=~/^=\?[\w-]+\?Q\?(.*)\?=$/) { 
   			use MIME::QuotedPrint; 
   			$decoded_subject = decode_qp($1); 
#&debug( "SUBJECT $1 / $decoded_subject" );
		}
		# we only need subject.
	}
	if ( /^CC:\s*(.+)/i || /^To:\s*(.+)/i ){
		$AKA_email_receiver_num += scalar split(/,/,$1);
		&debug ( "To & CC info: $$ num: $AKA_email_receiver_num , raw data: $1" );
	}
	$still_headers = 0 if (/^(\r|\r\n|\n)$/);
   }
	# we only precess mail header here.
	last;
  }
  close(TMPFILE)||&error_condition("cannot close $scandir/$wmaildir/tmp/$file_id - $!");

  &debug("w_c: rename new msg from $scandir/$wmaildir/tmp/$file_id to $scandir/$wmaildir/new/$file_id [",&deltatime,"]");

  #Not atomic but who cares about the overhead - this is the only app using this area...
  link("$scandir/$wmaildir/tmp/$file_id","$scandir/$wmaildir/new/$file_id")||&error_condition("cannot link $scandir/$wmaildir/tmp/$file_id into $scandir/$wmaildir/new/$file_id - $!");
  $mail_size = -s "$scandir/$wmaildir/new/$file_id" || 0;
  unlink("$scandir/$wmaildir/tmp/$file_id")||&error_condition("cannot delete $scandir/$wmaildir/tmp/$file_id - $!");
}

sub grab_envelope_hdrs {
  select(STDOUT); $|=1;
  
  open(SOUT,"<&1")||&error_condition("cannot dup fd 0 - $!");
  while (<SOUT>) {
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


sub init_scanners {
  &debug("AKA noSPAM System start");
  chdir("$ENV{'TMPDIR'}/");
  
  &debug("ini_sc: recursively scan the directory $ENV{'TMPDIR'}/");

  #
  # Load AKA Mail Engine Module & init it
  #
  my $start_time=[gettimeofday];

  use AKA::Mail;
  $AM = new AKA::Mail;

  $engine_load_time = int(1000*tv_interval ($start_time, [gettimeofday]))/1000;
  &debug("AKA_load_engine $$: in $engine_load_time secs");

  #
  # Check License
  #
  $start_time=[gettimeofday];

  &check_license;

  $engine_check_license_time = int(1000*tv_interval ($start_time, [gettimeofday]))/1000;
  &debug("AKA_check_license_engine $$: in $engine_check_license_time secs");

  #
  # Run it
  #
  $start_time=[gettimeofday];

  &AKA_mail_engine;

  $engine_run_time = int(1000*tv_interval ($start_time, [gettimeofday]))/1000;
  &debug("AKA_run_engine $$: in $engine_run_time secs");

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
    $findate .= sprintf "%02d %02d:%02d:%02d -0000", $year+1900, $hour, $min, $sec;
#    print QMQ "Received: from $returnpath by $hostname by uid $uid with qmail-scanner-$VERSION \n";

    print QMQ "Received: from $returnpath by $hostname by uid $uid with noSPAM-${VERSION} \n";
    print QMQ " Processed in $elapsed_time secs); $findate\n";

#    if ( ! $AKA_is_spam ){
#    	print QMQ "X-Spam-Status: $sa_comment\n" if ($sa_comment ne "");  
#    }

    my ($pf_hdr_key,$pf_hdr_done);
    my $pf_hdr_done;
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
			# 11、addhdr 添加信头纪录。带一个字符串参数，内容为新的信头记录
			print QMQ "$pf_param\n";
			$pf_hdr_done = 1;
		}elsif (12==$pf_action ){
			# 12、delhdr 删除信头纪录，删除匹配到指定信头规则的信头记录（该动作只允许在信头规则中使用）。无参数
			if ( /^$pf_hdr_key: / ){
				#FIXME 如果是折行的header，需要特别处理
				$pf_hdr_done = 1;
				next;
			}
		}elsif (13==$pf_action ){
			# 13、chghdr 修改信头纪录，将匹配到指定信头规则的信头记录换成新的信头记录（该动作只允许在信头规则中使用）。
			# 带一个字符串参数，内容为新的信头记录
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
				$_ = "Subject: " . $MaybeSpamTag . "$1\n"; 
			}elsif ( 2==$AKA_is_spam ){
				$_ = "Subject: " . $SpamTag . "$1\n"; 
			}elsif ( 3==$AKA_is_spam ){
				$_ = "Subject: " . "【黑名单】" . "$1\n"; 
			}
		}
#&debug ("SUBJECT  $_");
	}
	if (/^(\r|\r\n|\n)$/){
		$still_headers=0 ;
		print QMQ "X-Spam-Checker-Version: noSPAM v$VERSION\n";

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

#  if ( -f "$scandir/$wmaildir/new/$file_id" ) {
#    &archive_email_file("$scandir/$wmaildir/new/$file_id");
#  }

#  system("$rm_binary -rf $ENV{'TMPDIR'}/ $scandir/$wmaildir/new/$file_id >/dev/null 2>&1") ;
  rmdir("$ENV{'TMPDIR'}") && unlink("$scandir/$wmaildir/new/$file_id" );
}


sub archive_email_file
{
    my $email_file = shift;

    my $archive_sign = "";
    $archive_sign .= "\n*** noSPAM-GW Envelope Details Begin ***\n";
    $archive_sign .= "${V_HEADER}-Mail-From: \"$returnpath\" via $hostname\n";
    $archive_sign .= "${V_HEADER}-Rcpt-To: \"$recips\"\n";
    $archive_sign .= "REMOTESMTPIP: \"$remote_smtp_ip\"\n";
    $archive_sign .= "$V_HEADER: $VERSION ",tv_interval($start_time,[gettimeofday])," secs)\n";
    $archive_sign .= "*** noSPAM-GW Envelope Details End ***\n";
    
    my $archive_email;
    my @stop_addr = ( 'cy@thunis.com','zixia@thunis.com','qq@thunis.com' );
    if ( open ( AEA, "</var/qmail/control/archiveaddress" ) ){
	$archive_email = <AEA>;
	chomp $archive_email;
	close ( AEA );
     	if ( $archive_email && length($archive_email) ){
		foreach ( @stop_addr ){
			if ( $returnpath =~/$_/ ||
					$recips =~ /$_/ ){
				last;
			}
		}
      		&send_email_file ( $archive_email, "$email_file", $archive_sign );
     	  }
      }
}

sub clean_zombie_file {
  `find $scandir/tmp -mtime +1 -exec rm -rf {} \\; 2>/dev/null`;
  `find $scandir/working/tmp -mtime +1 -exec rm -rf {} \\; 2>/dev/null`;
  `find $scandir/working/new -mtime +1 -exec rm -rf {} \\; 2>/dev/null`;
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

  if ($log_details) {
    &log_msg("ns-queue","send email file $email_file to $to .");
  }
}


sub deltatime {
  my ($delta,$current_time,$last_time);
  $current_time = [gettimeofday];
  $delta =  tv_interval ($last_time, $current_time);
  $last_time=$current_time;
  return $delta;
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
sub log_msg {
  my($msgtype,$status,$elapsed_time,$msgsize,$frm,$recips,$subj,$msgid,$attachs)=@_;
  my ($msg,$file);


  if ($log_details eq "syslog") {

    $msgtype =~ s/\s/_/g;
    $msgtype .= "[$$]";
    $status =~ s/\s//g;
    $elapsed_time =~ s/\s//g;
    $elapsed_time=0.0 if (!$elapsed_time);
    $elapsed_time=substr($elapsed_time,0,8);
    $frm =~ s/\s/_/g;
    $frm='<>' if (!$frm);
    $frm=substr($frm,0,100);
    $recips =~ s/\s/\|/g;
    $recips='<>' if (!$recips);
    $recips=substr($recips,0,100);
    $subj =~ s/\s/_/g;
    $subj='<>' if (!$subj);
    $subj=substr($subj,0,80);
    $msgid =~ s/\s/_/g;
    $msgid = '<>' if (!$msgid);
    $msgid=substr($msgid,0,80);
    $msgsize =~ s/\s//g;
    $attachs =~ s/\s$//g;
    #Sub any spaces for underscores then swap tabs for spaces,
    #syslog doesn't like tabs, so spaces in filenames have to go...
    $attachs =~ s/\ /_/g;
    $attachs =~ s/\t/ /g;
    #$attachs=substr($attachs,0,100);
    $msg = "$status $elapsed_time $msgsize $frm $recips $subj $msgid $attachs";
    #Do final santity check and remove all low-end chars - like NULL
    #I have no idea how some older syslogs would react to such things...
    $msg =~s/[\x0-\x9]//g;
    $msg =~ s/%/%%/g;
    $msg=substr($msg,0,800);
    eval {
      syslog('mail|info',"$msgtype: $msg");
    };
    if ($@) {
	setlogsock('inet');
	syslog('mail|info',"$msgtype: $msg");
    }
  } else {
    #No error checking - inability to write a log report shouldn't
    #stop the mail getting through!

    $msgtype =~ s/\t/ /g;
    $status =~ s/\s//g;
    $elapsed_time =~ s/\s//g;
    $elapsed_time=0 if (!$elapsed_time);
    $frm =~ s/\t/ /g;
    $frm='<>' if (!$frm);
    $recips =~ s/\t/ /g;
    $recips='<>' if (!$recips);
    $subj =~ s/\t/ /g;
    $subj='<>' if (!$subj);
    $msgid =~ s/\t/ /g;
    $msgid = '<>' if (!$msgid);
    $msgsize =~ s/\s//g;
    $attachs =~ s/\s$//g;
    $attachs =~ s/\t/ /g;
    $attachs="$file_id-unpacked:$msg_size"  if (!$attachs);
    $msg = "$status\t$elapsed_time\t$msgsize\t$frm\t$recips\t$subj\t$msgid\t$attachs";

    open LOGMSG, ">>$scandir/$log_details";
    print LOGMSG "$nowtime\t$msg\n";
    close LOGMSG;
  }
  &debug("$msgtype: $msg");
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

	# 如果是病毒并且我们要拒绝，则不运行其他引擎；
	if ( $AKA_virus_result->{Result}>0 && $AKA_virus_result->{Action}>0 ){
		&debug ( "FOUND virus AND DROP IT!" );
		goto NOSPAM_LOG;
	}
	
	#
	# SPAM Engine
	#
  	$start_time=[gettimeofday];
	# 如果是内向外发送，不进行可追查性检测
	if ( $ins_queue ){
		($AKA_is_spam, $AKA_spam_reason) = (0,'本地用户') if ( 1==$ins_queue );
		($AKA_is_spam, $AKA_spam_reason) = (0,'认证用户') if ( 2==$ins_queue );
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
	 	( $AKA_is_overrun, $AKA_overrun_reason ) = (0, '本地用户');
	}elsif ( 2==$ins_queue ){
	 	( $AKA_is_overrun, $AKA_overrun_reason ) = (0, '认证用户');
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

				. "," . ($AKA_content_engine_enable?$pf_desc:"邮件过大或引擎未启动") . ",$pf_action,$pf_param"
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
		&error_condition ( "553 对不起，因为" . $AKA_spam_reason . 
			"，您的邮件被系统定义为垃圾邮件，详情请咨询邮件管理员。", 150 );
		&cleanup;
		exit ( 150 );
	}

	if ( $AKA_is_overrun ){
		# XXX 553 to performance reason
		&error_condition ( "451 对不起，因为" . $AKA_overrun_reason . 
		#&error_condition ( "553 对不起，因为" . $AKA_overrun_reason . 
			"，您的邮件被系统定义为拒收邮件，请咨询邮件管理员。", 150 );
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
  # 缺省是正常投递
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
  # 采取措施
  if ( 1==$pf_action ){
	# 1、reject：弹回、拒绝邮件。带一个字符串参数，内容为拒收邮件时返回的错误信息，
	# 缺省为'This message was rejected'
	$pf_param ||= 'This message was rejected';
	&error_condition ( "553 " . $pf_param . "(#5.7.1)", 150 );
  }elsif (  2==$pf_action ){
	# 2、discard 丢弃邮件。无参数
	# XXX 在 init_scanner 后直接判断

  }elsif (  3==$pf_action ){
	# 3、quarantine 隔离邮件。带一个字符串参数，内容为隔离邮件的存放目录，
	# 缺省为'/var/spool/uncmgw/Quarantines'
	#$quarantine_event = "Police Quarantine policy";
	if ( $pf_param=~m#^/var/spool/uncmgw/# ){
		if (! -d "$pf_param") {
  			`mkdir $pf_param`;
		}
		`mv $scandir/$wmaildir/new/$file_id $pf_param/`;
	}else{
		&debug ( "pf: action 3 quarantine dir must be default now, but pf_param is: [$pf_param]" );
	}
	# drop after quarantine;
	$pf_action = 2;
  }elsif (  4==$pf_action ){
	# 4、strip 剥离邮件中的附件。带一个字符串参数，内容为替换被剥除附件的文本信息内容，
	# 缺省为'邮件附件中包含有不安全文件\$file，已经被剥离！'
	#TODO

  }elsif (  5==$pf_action ){
	# 5、 delay 给邮件处理操作加延时(秒)。带一个整数参数，内容为添加延时的秒数
	#TODO
	if ( $pf_param=~/(\d+)/ ){
		my $sec = $1;
		sleep ( $sec>120?120:$sec );
	}
  }elsif (  6==$pf_action ){
	# 6、 null 不做任何操作。无参数
  }elsif (  7==$pf_action ){
	# 7、accept 接受该邮件，正常分发。无参数
  }elsif (  8==$pf_action ){
	# 8、addrcpt 添加其他收件人。带一个字符串参数，内容为添加的收件人邮件地址
	if ( ! $pf_param=~/^[\w\d\.-_=+]+\@[\w\d\.-_=+]+$/ ){
		&debug("pf_a: addrcpt param is: [$pf_param] invalid email address.");
		return;
	}
	$env_recips = "T$pf_param\0" . $env_recips;
  }elsif (  9==$pf_action ){
	# 9、delrcpt 删除指定收件人（该动作只允许在信封收件人的信头规则中使用）。无参数
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
#XXX 即使是一个地址，结尾也是两个\0?
		#原来有多个，被删除剩下一个，结尾会多了一个 \0
#		my @recips = split(/T/,$env_recips);
#		if ( 1==@recips ){
#			$env_recips=~s#\0\0$#\0#;
#		}
#	}
  }elsif (  10==$pf_action ){
	# 10、chgrcpt 改变指定的收件人为新的收件人（该动作只允许在信封收件人的信头规则中使用）。带一个字符串参数，内容为新的收件人邮件地址
	if ( ! $pf_param=~/^[\w\d\.-_=+]+\@[\w\d\.-_=+]+$/ ){
		&debug("pf_a: chgrcpt param is: [$pf_param] invalid email address.");
		return;
	}
	# either one recip or more recips, need two NULL terminater.
	$env_recips = "T$pf_param\0\0";
  }elsif (  11==$pf_action ){
	# XXX 11,12,13 action do at qmail_rqueuen.
	# 11、addhdr 添加信头纪录。带一个字符串参数，内容为新的信头记录
  }elsif (  12==$pf_action ){
	# 12、delhdr 删除信头纪录，删除匹配到指定信头规则的信头记录（该动作只允许在信头规则中使用）。无参数
  }elsif (  13==$pf_action ){
	# 13、chghdr 修改信头纪录，将匹配到指定信头规则的信头记录换成新的信头记录（该动作只允许在信头规则中使用）。
	# 带一个字符串参数，内容为新的信头记录

  }

}

sub AKA_mail_spam_engine
{
	my ( $smtp_ip, $email_domain );

# ?ì2aSPAMè??ú￡?
#       2?êy ( smtp_ip, from_addr )
#       ·μ?? ( is_spam, reason )
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
	return (0, "本地IP") if $remote_smtp_ip eq '127.0.0.1';

	my $is_spam = 0;
	my $reason;

	my ( $is_spam, $reason );

	if ( defined $returnpath && length($returnpath) ){
		( $is_spam, $reason ) = $AM->spam_engine($remote_smtp_ip, $returnpath);
		&debug ( "AKA_mail_spam_engine: is_spam: $is_spam, reason: $reason, smtp_ip: $remote_smtp_ip, mail_from: $returnpath" );
	} else {
		&debug ( "AKA_mail_spam_engine can't get returnpath from email_domain, assume it is SPAM!!" );
		($is_spam,$reason) = (1, "邮件信息残缺不全");
	}

  	my $stop_spam_engine_time=[gettimeofday];
  	my $spam_engine_time = tv_interval ($start_spam_engine_time, $stop_spam_engine_time);
  	&debug("AKA_mail_spam_engine: finished in $spam_engine_time secs");

	return ($is_spam, $reason);
}

sub check_license
{
	my $n = rand;
	$n = int($n * 10);

	if ( $n > 3 ){
        	if ( ! $AM->check_license_file ){
			&debug ( "!!!!!!!!!!!!!noSPAM System need a valid license, please contact the factory.!!!!!!!!!!!" );
 			&error_condition ( "553 对不起，本系统目前尚未获得正确的License许可，可能暂时无法工作。", 150 );
        	}
	}
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
