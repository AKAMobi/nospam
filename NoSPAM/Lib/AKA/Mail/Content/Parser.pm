
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

	my ($police, $mail) = @_;

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

	my $entity = $self->{mime_parser}->parse(\*STDIN);

	&get_head_info( $entity->head );
	&get_body_info( $entity->body );
	
}

sub get_head_info
{
	my ($self, $head) = @_;

	$self->{mail_info}->{head}->{content} = $head->as_string || "";
	$self->{mail_info}->{head}->{size} = length( $self->{mail_ifno}->{head}->{content} );

	$head->decode;

	$self->{mail_info}->{haed}->{from} = $head->get('From');
	$self->{mail_info}->{haed}->{to} = $head->get('To');
	$self->{mail_info}->{haed}->{cc} = $head->get('CC');
	$self->{mail_info}->{haed}->{subject} = $head->get('Subject');

	# FIXME 正确取得 sender_ip & server_ip
	$self->{mail_info}->{haed}->{sender_ip} = $head->get('Received');
	# FIXME 正确取得 sender_ip & server_ip
	$self->{mail_info}->{haed}->{server_ip} = $self->{mail_info}->{haed}->{sender_ip};
	
}

sub get_body_info
{
        my ($self, $blob, $load_binary) = @_;

	my ($path,$filename,$size,$type,$subtype);

        ($type, $subtype) = split('/', $blob->head->mime_type);

        my $disposition = $blob->head->mime_attr("Content-Disposition");

        my $head = $blob->head;
        $head->decode;

        my $body = $blob->bodyhandle;

        if ($body = $blob->bodyhandle) {
                if (defined $disposition && $disposition =~ /attachment/) {
                        $police->{zlog}->log ("    Atachment: " . $body->path );
                }
                $path = $body->path;
                $filename = $head->recommended_filename ;
                if ( !defined $filename ){
                        $filename = $path;
                        $filename =~ s/^.*\/$prefix\-//g;
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
			$self->{mail_info}->{body}->{content} = load_file ( $path, $size );
		}

			
        } else {  
                foreach my $part ($blob->parts) {
                        &get_body_info( $part );
                }
        }

}

sub load_file
{
	my ($self,$path,$size) = @_;
	
	my $data;
	$data = ' ' x $size;

	open ( FD, "<$path" ) or return "";
	read ( FD, $data, $size );
	close ( FD );

	return $data;
}

sub DESTROY
{
	my $self = shift;

	# 删除临时文件
	$self->{mime_parser}->filter->purge;
	delete $self->{mime_parser};
}

1;
