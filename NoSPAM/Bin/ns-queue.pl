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

# ʱ���¼

delete @ENV{qw(IFS CDPATH ENV BASH_ENV QMAILMFTFILE QMAILINJECT)};

my $rm_binary="/bin/rm";

# What directory to use for storing temporary files.
my $scandir = '/home/NoSPAM/spool';

#What maildir folder to store working files in
my $wmaildir='working';

#Name of file in $scandir where debugging output goes
my $debuglog="ns-queue.debug";

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
use Time::HiRes qw(gettimeofday tv_interval );

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
}

if ($ENV{'TCPREMOTEIP'}) {
  $mail_info->{aka}->{TCPREMOTEIP} = $ENV{'TCPREMOTEIP'};
} else {
  $mail_info->{aka}->{TCPREMOTEIP} = '127.0.0.1';
}

my ($alarm_status,$elapsed_time);
my $xstatus=0;

#Now alarm this area so that hung networks/virus scanners don't cause 
#double-delivery...

eval {
  $SIG{ALRM} = sub { die "Maximum time exceeded. Something cannot handle this message." };
  alarm $MAXTIME;

  delete $ENV{'QMAILQUEUE'};
  
  #This SMTP session is incomplete until we see dem envelope headers!
  &grab_envelope_hdrs;

  &AKA_engine_run;
  
  &qmail_parent_check;

  if ( $mail_info->{aka}->{resp} ){
	my $smtp_code = $mail_info->{aka}->{resp}->{smtp_code};
	my $smtp_info = $mail_info->{aka}->{resp}->{smtp_info};
	my $exit_code = $mail_info->{aka}->{resp}->{exit_code};
	&error_condition ( "$smtp_code $smtp_info", $exit_code );
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

exit 0;

############################################################################
# Error handling
############################################################################


# Fail with the given message and a temporary failure code.
sub error_condition {
  my ($string,$errcode)=@_;
  $errcode=111 if (!$errcode);
  $nowtime = sprintf "%02d/%02d/%02d %02d:%02d:%02d", $mday, $mon+1, $year+1900, $hour, $min, $sec;
  &debug("error_condition: $string");

  print NSOUT $string, "\r\n";
  exit $errcode;
}

sub debug {
  print LOG "$nowtime:$$: ",@_,"\n" if ($DEBUG);
}

sub grab_envelope_hdrs {
  select(STDOUT); $|=1;
  open(SOUT,"<&1")||&error_condition("cannot dup fd 0 - $!");
  $mail_info->{aka}->{fd1} = <SOUT>;
  close(SOUT);
}


sub AKA_engine_run {
  chdir("$ENV{'TMPDIR'}/");
  
  #
  # Load AKA Mail Engine Module & init it
  #
  #use AKA::Mail;
  #$AM = new AKA::Mail;
  use AKA::MailClient;
  my $AMC = new AKA::MailClient;

  #
  # Check License
  #
  $start_time=[gettimeofday];

  #&check_license;

  $mail_info = $AMC->net_process( $mail_info );

open ( FD, ">/tmp/zixia.debug" );
use Data::Dumper;
print FD Dumper($mail_info);
close FD;

  my $run_time = int(1000*tv_interval ($start_time, [gettimeofday]))/1000;

  &debug ("run_time: $run_time" );
  chdir("$scandir");
}

sub qmail_parent_check {
  my $ppid=getppid;
  &debug("q_s_c: PPID=$ppid");
  if ($ppid == 1)  {
    &debug("q_s_c: Whoa! parent process is dead! (ppid=$ppid) Better die too...");
    close(LOG);
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
