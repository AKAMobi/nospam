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
open (NSOUT, ">&=2") or die "can't open NSOUT";
close (STDERR);
#open (STDERR,">/dev/null");
open (STDERR,">>/tmp/ns-queue.STDERR");

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
my $MAXTIME=3*60;

#Want debugging? Enable this and read $scandir/qmail-queue.log
my $DEBUG='1';

#Want microsec times for debugging
use POSIX qw(strftime);

my $mail_info;
# 判断是否由内向外发的mail
my $ins_queue = 0;
if ( defined $ENV{RELAYCLIENT} ){
	$mail_info->{aka}->{RELAYCLIENT} = $ENV{RELAYCLIENT};
	$ins_queue = 1 ;
}elsif (defined $ENV{TCPREMOTEINFO}){
	# 如果经过身份认证，则 TCPREMOTEINFO 内存的是用户名
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
  &debug("+++ starting debugging for process $$ by at $nowtime");
}

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
  
  &qmail_parent_check;
   # &qmail_requeue($env_returnpath,$env_recips,"$scandir/$wmaildir/new/$file_id"); 
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

  if ( $mail_info->{aka}->{resp} ){
	my $smtp_code = $mail_info->{aka}->{resp}->{smtp_code};
	my $smtp_info = $mail_info->{aka}->{resp}->{smtp_info};
	my $exit_code = $mail_info->{aka}->{resp}->{exit_code};
	&error_condition ( "$smtp_code $smtp_info", $exit_code );
  }

  undef $AM;
  chdir("$scandir");
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
sub check_license
{
#	my $n = rand;
#	$n = int($n * 10);
#
	#if ( $n > 7 ){
        	if ( ! $AM->check_license_file ){
			&debug ( "!!!!!!!!!!!!!noSPAM System need a valid license, please contact the factory.!!!!!!!!!!!" );
 			&error_condition ( "553 对不起，本系统目前尚未获得正确的License许可，可能暂时无法工作。", 150 );
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
