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
open (STDERR,">/dev/null");
#open (STDERR,">>/tmp/ns-queue.STDERR");

# 时间记录

delete @ENV{qw(IFS CDPATH ENV BASH_ENV QMAILMFTFILE QMAILINJECT)};

my $rm_binary="/bin/rm";

# What directory to use for storing temporary files.
my $scandir = '/home/NoSPAM/spool';

#What maildir folder to store working files in
my $wmaildir='working';

#Name of file in $scandir where debugging output goes
my $debuglog="ns-queue.debug";


$ENV{'PATH'}='/bin:/usr/bin';

#Generate nice random filename
my $hostname='gw.nospam.aka.cn';
#my $hostname=`/bin/hostname -f`; #could get via call I suppose...
#chomp $hostname;

my $MAXTIME=3*60;

#Want debugging? Enable this and read $scandir/qmail-queue.log
my $DEBUG='1';

#Want microsec times for debugging
use POSIX qw(strftime);
use Time::HiRes qw(gettimeofday tv_interval );

# CORE DATA STRUCTURE
my $mail_info;

# 判断是否由内向外发的mail
if ( defined $ENV{RELAYCLIENT} ){
	$mail_info->{aka}->{RELAYCLIENT} = $ENV{RELAYCLIENT};
}elsif (defined $ENV{TCPREMOTEINFO}){
	# 如果经过身份认证，则 TCPREMOTEINFO 内存的是用户名
	$mail_info->{aka}->{TCPREMOTEINFO} = $ENV{TCPREMOTEINFO};
}

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
  local $SIG{ALRM} = sub { die "Maximum time exceeded. Something cannot handle this message." };
  alarm $MAXTIME;

  delete $ENV{'QMAILQUEUE'};
  
  #This SMTP session is incomplete until we see dem envelope headers!
  &grab_envelope_hdrs;

  &AKA_engine_run;

  if ( length($mail_info->{aka}->{resp}->{smtp_code}) ){
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

&clean_up();
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
  &clean_up();
  exit $errcode;
}

sub debug {
  print LOG "$nowtime:$$: ",@_,"\n" if ($DEBUG);
}

sub grab_envelope_hdrs {
  select(STDOUT); $|=1;
  open(SOUT,"<&1")||&error_condition("cannot dup fd 0 - $!");
  $_ = <SOUT>;
  close(SOUT);
  unless ( defined $_ && $_ ne "F\0T\0\0") {
#At the very least this is supposed to be $env_returnpath='F' - so
#qmail-smtpd must be officially dropping the incoming message for
#some (valid) reason (including the other end dropping the connection).
	  &debug("g_e_h: no sender and no recips.");
	  unlink "$scandir/$wmaildir/new/$file_id";
	  exit;
  }
  unless ( -s "$scandir/$wmaildir/new/$file_id" ){
	  &debug("g_e_h: zero size emlfile.");
	  unlink "$scandir/$wmaildir/new/$file_id";
	  exit;
  }
  $mail_info->{aka}->{fd1} = $_;
}


sub AKA_engine_run {
  chdir("$ENV{'TMPDIR'}/");
  
  use AKA::MailClient;
  my $AMC = new AKA::MailClient;

  $start_time=[gettimeofday];

use Data::Dumper;
print LOG "mail_info.orig\@ns-queue\n";
print LOG Dumper($mail_info);


  &qmail_parent_check;
  $mail_info = $AMC->net_process( $mail_info );

use Data::Dumper;
print LOG "mail_info.result\@ns-queue\n";
print LOG Dumper($mail_info);

  my $run_time = int(1000*tv_interval ($start_time, [gettimeofday]))/1000;

  &debug ("run_time: $run_time" );
  chdir("$scandir");
}

sub qmail_parent_check {
  my $ppid=getppid;
  &debug("q_s_c: PPID=$ppid");
  if ($ppid == 1)  {
    &debug("\n!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!q_s_c: Whoa! parent process is dead! (ppid=$ppid) Better die too...");
    close(LOG);
    #Exit with temp error anyway - just to be real anal...
    exit 111; 
  }
}


sub clean_up
{
	unlink "$scandir/$wmaildir/new/$file_id";
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
