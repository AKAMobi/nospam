#
# qmail file & system file & install control
# Company: AKA Information & Technology Co., Ltd.
# Author: Ed Lee
# EMail: zixia@zixia.net
# Date: 2004-03-21


package AKA::Mail::GW;

use AKA::Mail::Conf;
use AKA::Mail::Log;


sub new
{
	my $class = shift;

	my $parent = shift;

	my $self = {};

	bless $self, $class;

	$self->{parent} = $parent;
	$self->{conf} = $parent->{conf} || new AKA::Conf;
	$self->{zlog} = $parent->{zlog} || new AKA::Log;

	return $self;

}

sub post_install
{
	my $self = shift;
	my $oem_factory_name = shift;

	my @oems = ('siwei','shikong' );

# TODO: move shell script from ks.cfg to here
	chdir '/home/NoSPAM/admin/';

	if ( $oem_factory_name ){
		my $cmd = "mv index.$oem_factory_name.ns index.ns";
		`$cmd`;
	}

	system("rm -f index.*.ns");
}

sub get_srvip_from_domain
{
}

sub get_domain_from_srvip
{
}

# ������
#	��Ҫ����� domain, ip
# ������
#	�� ip ���� ismtp tcp
#	�� domain ���� hosts,morercpthosts,smtproutes
#
sub add_email_domain
{
# ��� zixia.net �Ǳ��ص� virtualdomain����ʹ zixia.net �� smtproutes �У�Ҳ���ᱻ route �ߣ���Ȼ����Ͷ�ݵ����ء�
}

# ������
#	��Ҫɾ���� domain, ip
# ������
#	�� ip �� ismtp tcp ��ɾ��
#	�� domain �� hosts,morercpthosts,smtproutes ��ɾ��
#
sub del_email_domain
{
}

#
# ��ά��˾��tap����
#
sub heart_beat_siwei
{
	my $self = shift;

	eval {
		use Device::SerialPort 0.05;
		use Time::HiRes qw(usleep);
	}; if ( $@ ) {
		$self->{zlog}->fatal ("GW::heart_beat_siwei: failed to load modules");	
		return 0;
	}

	$| = 1;

	my $file = "/dev/ttyS0";

	my $ob = Device::SerialPort->new ($file) || die "Can't open $file: $!";

	$ob->baudrate(19200)    || die "fail setting baudrate";
	$ob->parity("none")     || die "fail setting parity";
	$ob->databits(8)        || die "fail setting databits";
	$ob->stopbits(1)        || die "fail setting stopbits";
	$ob->handshake("none")  || die "fail setting handshake";

	$ob->write_settings || die "no settings";

	$ob->error_msg(1);              # use built-in error messages
	$ob->user_msg(1);

	my $in = 1;
	while ($in) {
		$ob->write("#sw#");
		usleep(200000);
		#print int($in++/5),"\n";
	}

}

1;



