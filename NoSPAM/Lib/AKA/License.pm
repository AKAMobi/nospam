#
# License Control
# Company: AKA Information & Technology Co., Ltd.
# Author: Ed Lee
# EMail: zixia@zixia.net
# Date: 2004-03-07


package AKA::License;

use AKA::Mail::Log;

use Digest::MD5 qw(md5_base64 md5_hex);

sub new
{
	my $class = shift;

	my $self = {};

	bless $self, $class;

	my $parent = shift;

	#$self->{parent} = $parent;
	$self->{zlog} = $parent->{zlog} || new AKA::Mail::Log; #die "AKA::IPUtil can't get parent zlog";

	return $self;
}

sub get_valid_license
{
	my $self = shift;

	my $hd_serialno = shift;

	return md5_hex( 'okboy' . $hd_serialno . 'zixia' . $hd_serialno . '@2004-03-07' );
}

sub get_checksum
{
	my $self = shift;

	my $data = shift;

	my $checksum = md5_base64( 'okboy' . $data . 'zixia' . $data . '@2004-03-07' );
#print "get sum for [$data], result: $checksum\n"; 
	return $checksum;
}

sub is_valid_checksum
{
	my $self = shift;

	# 不包括 checksum 那行
	my ($license_content,$license_checksum) = @_;

	my $right_sum = $self->get_checksum($license_content);

	if ( $license_checksum eq $right_sum ){
		return 1
	}
#print "right: $right_sum, this: $license_checksum\n";
#print "for data [$license_content]\n";
	return 0;
}

sub get_prodno
{
	my $self = shift;
	
	my $IDserial = '';
	my $id = '';

	$id = &get_IDE_serial;
	$IDserial .= $id if ( $id );

	$id = &get_SCSI_serial;
	$IDserial .= $id if ( $id );

	return md5_hex( 'okboy' . $IDserial . 'zixia' . $IDserial . '@2004-03-07' );
}

sub get_SCSI_serial
{
	my $self = shift;

	my $id = '';

	my @lines;

	if ( open ( FD, "</proc/scsi/aic7xxx/0" ) ){
		@lines = <FD>;
		@lines = grep ( /^0x/, @lines );
	}

	$id = join ( "", @lines );

	$id =~ s/[\s\n\r]*//g;

	return $id;
}

sub get_IDE_serial
{
	my $self = shift;

	my $id=' ' x 512;
	my $ret;

	use Fcntl;
	return undef unless open ( HDAFD, "</dev/hda" ) or open ( HDAFD, "</dev/hdb" ) ;
	ioctl( HDAFD, 0x030d, $id ) or die "can't ioctl\n";
	close ( HDAFD );

	# reference to /usr/include/linux/hdreg.h : struct hd_driveid 
	@id = (unpack ( "S10 C20", $id ))[10...29];
	$id = join ( "", @id );

	return $id;
}


1;



