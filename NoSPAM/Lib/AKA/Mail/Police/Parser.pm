#
# 北京互联网接警中心邮件过滤器
# Company: AKA Information & Technology Co., Ltd.
# Author: Ed Lee
# EMail: zixia@zixia.net
# Date: 2004-02-10

package AKA::Mail::Police::Parser;

use MIME::Parser;
use AKA::Mail::Police::Log;
use AKA::Mail::Police::Conf;
#use Exporter;
#use vars qw(@ISA @EXPORT);

#@ISA=qw(Exporter);

#@EXPORT=("function1", "function2", "function3");

#use Data::Dumper;
# 改变$转义、缩进
#$Data::Dumper::Useperl = 1;
#$Data::Dumper::Indent = 1;

sub new
{
	my $class = shift;
	my $self = {};

	bless $self, $class;

	my ($police) = @_;

	$self->{police} = $police;

	$self->{zlog} = $police->{zlog} || new AKA::Mail::Police::Log($self);
	$self->{conf} = $police->{conf} || new AKA::Mail::Police::Conf($self);
	$self->{mime_parser} ||= new MIME::Parser;

	my $tmpdir = $self->{conf}->{tmpdir} || "/tmp";
	$self->{mime_parser}->output_dir($tmppath);
	$self->{mime_parser}->output_prefix($$);

	return $self;
}

sub get_mail_info
{
	my ($self, $fh) = @_;

	if ( defined $self->{mail_info} ){ return $self->{mail_info}; }

	my ( $type, $subtype, $body_content );

	my $entity = $self->{mime_parser}->parse($fh);
	$self->{entity} = $entity;

	&get_head_info( $self,$entity->head );

       
	my @Parts = $entity->parts;
        
	$partnum = @Parts;
        
	foreach my $blob (@Parts) {
		&get_body_info( $self,$blob );
	}
        

	return $self->{mail_info};
}

sub print
{
	my ($self, $fh) = @_;

	if ( ! defined $self->{mime_parser} ) { return; }

	$self->{entity}->print($fh);

	# 只能 print 一次
	$self->{mime_parser}->filer->purge;

	undef $self->{mail_info};
	undef $self->{entity};
}

sub get_head_info
{
	my ($self, $head) = @_;

	if ( ! defined $head ){
		$slef->{zlog}->log( "error: get_head_info no head found?" );;
		return;
	}

	my $content = $head->stringify || "";
	$self->{mail_info}->{head}->{content} = $content;
	$self->{mail_info}->{head}->{size} = length( $content );

	#FIXME: here make a copy of head instead of make change of original entity;
	#my $head_decoded = $head;
	#$head = $head_decoded;
	#undef $head_decoded;

	$head->decode;
	$head->unfold;

	$self->{mail_info}->{haed}->{from} = $head->get('From');
	$self->{mail_info}->{haed}->{to} = $head->get('To');
	$self->{mail_info}->{haed}->{cc} = $head->get('CC');
	$self->{mail_info}->{haed}->{subject} = $head->get('Subject');

	# FIXME 正确取得 sender_ip & server_ip
	my @receiveds = $head->get("Received");
	my $server_ip = 1;
	for ( @receiveds ){
		if ( /(\d+\.\d+\.\d+\.\d+)/ ){
			if ( $server_ip ){
				$self->{mail_info}->{haed}->{server_ip} = $1;
				$self->{mail_info}->{haed}->{sender_ip} = $1;
				$server_ip = 0;
			}else{
				$self->{mail_info}->{haed}->{sender_ip} = $1;
			}
		}
	}
}

sub get_body_info
{
        my ($self, $blob, $load_binary) = @_;

	my ($path,$filename,$size,$type,$subtype);

        ($type, $subtype) = split('/', $blob->head->mime_type);

        my $disposition = $blob->head->mime_attr("Content-Disposition");

        my $head = $blob->head;

	# FIXME: here make a copy of head instead of make change of original entity;
	#my $head_decoded = $head;
	#$head = $head_decoded;
	#undef $head_decoded;

        $head->decode;

        my $body = $blob->bodyhandle;

        if ($body = $blob->bodyhandle) {
                if (defined $disposition && $disposition =~ /attachment/) {
                        $self->{zlog}->log ("    Atachment: " . $body->path );
                }
                $path = $body->path;
                $filename = $head->recommended_filename ;
                if ( !defined $filename ){
                        $filename = $path;
                        $filename =~ s/^.*\/$$\-//g;
                }
                $size = ($path ? (-s $path) : '???');
		#print "faint, [$size], [$path], [$filename] [$type / $subtype ]\n";
		$self->{mail_info}->{body}->{filename} = $filename;
		$self->{mail_info}->{body}->{path} = $path;
		$self->{mail_info}->{body}->{size} = $size;
		$self->{mail_info}->{body}->{type} = $type;
		$self->{mail_info}->{body}->{subtype} = $subtype;
		
		if ( ($type eq "text" && $subtype eq "plain") || 
				1 == $load_binary ){
			$self->{mail_info}->{body}->{content} = load_file ( $self,$path, $size );
		}

			
        } else {  
                foreach my $part ($blob->parts) {
                        &get_body_info( $self,$part );
                }
        }

}

sub load_file
{
	my ($self,$path,$size) = @_;
	
	my $data;
	$data = ' ' x $size;

	open ( FD, "<$path" ) or return "";
	binmode FD;
	read ( FD, $data, $size );
	close ( FD );

	return $data;
}

#sub DESTROY
#{
#	# 删除临时文件
#}

1;
