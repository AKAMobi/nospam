#!/usr/bin/perl -w

use POSIX qw(strftime);
use Digest::MD5 qw(md5_base64 md5_hex);

use strict;

my $NSVER='2.0-4.26';
my $ISOVER='2.0RC5';

my $PATCHVER='2';

#
# ����Patch��
#	���ú�����İ汾��Ϣ
#	����patchĿ¼������Ҫ���µ��ļ�����Ŀ¼��ʽ������ȥ
#	��patchĿ¼�½�����
#		VER	���û��������ð汾
#		INFO	��������������һ��Ϊ��������Ȼ��Ϊ���У�����Ϊ������

#		REBOOT	�����������ҪREBOOT�����������ļ�
#		root/post_patch	�����Ϻ��ִ�нű�
#		SUM	�����Զ�����		
#		TIMESTAMP	�����Զ�����		
#

my $PATCHDIR = $ARGV[0] or die "which dir?\n";

`rm -f $PATCHDIR/*.{no,ns}`;

my $PATCHVERSION=sprintf( "%04d%02d", strftime("%m%d", localtime), $PATCHVER );

my $NSVERSION;
if ( $NSVER=~/(\d+)\.(\d+)-(\d+)\.(\d+)/ ){
        $NSVERSION=sprintf("%02d%02d%02d%02d",$1,$2,$3,$4);
}else{
	die "NSVER: [$NSVER] error!\n";
}

my $PATCHNAME=sprintf ( "U%s%s",$NSVERSION,$PATCHVERSION );

print $PATCHNAME, "\n";

chdir $PATCHDIR or die "can't chdir to [$PATCHDIR]\n";

my $now = time;
`echo $now > TIMESTAMP`;

`chmod +x root/post_patch`;
print "Tar patch $PATCHVER for $NSVER $ISOVER ...\n";
`tar cvf $PATCHNAME.ns *`;
print "Zip & Encrypt pkg...\n";
`zip -P zixia\@noSPAM_OKBoy_GNULinux! $PATCHNAME.zip $PATCHNAME.ns`;
print "Rename to strip .zip ext...\n";
unlink "$PATCHNAME.ns";
rename "$PATCHNAME.zip", "$PATCHNAME.ns";

print "Making SUM...\n";
open ( FD, "/usr/bin/md5sum $PATCHNAME.ns|" ) or die "can't md5sum\n";
my $md5sum = <FD>;
close FD;
chomp $md5sum;
if ( $md5sum=~/^(\S+)\s+/ ){
	$md5sum = $1;
}else{
	die "md5sum format err!\n";
}

my $checksum = md5_base64( 'okboy' . $md5sum . 'zixia' . $md5sum . '@2004-03-07' );
open ( FD, ">SUM" ) or die "can't open sum for write!\n";
print FD $checksum;
close FD;

print "adding VER & INFO & SUM & TIMESTAMP ...\n";
`tar cf $PATCHNAME.no $PATCHNAME.ns SUM VER INFO`;
unlink "$PATCHNAME.ns";

print "Build SUCCEED!\n";
