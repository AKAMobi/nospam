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

sub make_license
{
	my $self = shift;
	
	my ( $license_orig, $prodno ) = @_;

	my ( $license_data, $license_checksum );

	$license_data = $self->get_valid_license( $prodno );

	$license_ret = $license_orig . "\nProductLicense=$license_data\n";

	$license_checksum = $self->get_checksum($license_ret);

	$license_ret .= "ProductLicenseExt=$license_checksum";

	return $license_ret;
}

sub check_license_file
{
	my $self = shift;

	use AKA::Mail::Conf;
	my $MC = new AKA::Mail::Conf;
	
	my $licensefile = $MC->{define}->{licensefile};

	if ( ! open( LFD, "<$licensefile" ) ){
		#$self->{zlog}->fatal ( "AKA::License::check_license_file can't open [$licensefile]" );
		# No license
		return 0;
	}
	
	my $license_content;
	my $license_data;
	my $license_checksum;
	
	while ( <LFD> ){
		chomp;
		s/[\r\n]$//;
		if ( /^ProductLicenseExt=(.+)$/ ){
			$license_checksum = $1;
			next;
		}elsif ( /^ProductLicense=(.+)$/ ){
			$license_data = $1;
			$license_data =~ s/\s*//g;
		}

		$license_content .= $_ . "\n";
	}
	# trim tail \n
	$license_content =~ s/\n+$//;

	unless ( defined $license_content && defined $license_checksum && 
			length($license_content) && length($license_checksum) ){
		$self->{zlog}->fatal ( "AKA::License::check_license_file can't get enough information from [$licensefile]" );
		return 0;
	}

	my $cmp_str;

	$cmp_str=$self->get_valid_license($self->get_prodno) ;

	if ( $cmp_str ne $license_data ){
		#print "license_data $license_data ne $cmpstr\n";
		return 0;
	}
	if( !$self->is_valid_checksum( $license_content, $license_checksum ) ){
		#print "checksum $license_checksum not valid for [$license_content]\n";
		return 0;
	}
	# it's valid
	return 1;
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
	
	my $HD_serial = &get_HD_serial;

	return md5_hex( 'okboy' . $HD_serial . 'zixia' . $HD_serial . '@2004-03-07' );
}

sub get_HD_serial
{
	my $self = shift;

	my $id=' ' x 512;
	my $ret;

	use Fcntl;
	open ( HDAFD, "</dev/hda" ) or open ( HDAFD, "</dev/hdb" ) or die "can't open\n";
	ioctl( HDAFD, 0x030d, $id ) or die "can't ioctl\n";
	close ( HDAFD );

	# reference to /usr/include/linux/hdreg.h : struct hd_driveid 
	@id = (unpack ( "S10 C20", $id ))[10...29];
	$id = join ( "", @id );

	return $id;
}


1;



