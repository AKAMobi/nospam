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

	my ($parent) = @_;

	$self->{parent} = $parent;

	$self->{zlog} = $parent->{zlog} || new AKA::Mail::Police::Log($self) ;
	$self->{conf} = $parent->{conf} || new AKA::Mail::Police::Conf($self) ;
	$self->{mime_parser} ||= new MIME::Parser;

	# FIXME: $a = $b || $c not work??
	my $tmpdir = $self->{conf}->{define}->{tmpdir} || "/tmp/";
	$self->{zlog}->log ( "setting outputdir to $tmpdir" );

	$self->{mime_parser}->output_dir($tmpdir);
	$self->{mime_parser}->output_prefix("AKA-MailFilter-$$");

	$self->{prefix} = "AKA-MailFilter-$$";


	# 文件类型
	$self->{filetype}->{compress} = [ 'zip','rar',
					  'tgz', 'gz','bzip2' ];
	$self->{filetype_num}->{compress} = 1;

	$self->{filetype}->{sound} = [ 'mp3', 'wav', 'wmv' ];
	$self->{filetype_num}->{sound} = 2;

	$self->{filetype}->{picture} = [ 'jpg', 'jpeg', 'gif', 'pcx' ];
	$self->{filetype_num}->{picture} = 3;

	$self->{filetype}->{text} = [ 'txt' ];
	$self->{filetype_num}->{text} = 4;

	$self->{filetype}->{exe} = [ 'exe', 'com', 'bat' ];
	$self->{filetype_num}->{exe} = 5;



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
        
	foreach my $filename ( %{$self->{mail_info}->{body}} ){
		if ( 0 == $self->{mail_info}->{body}->{$filename}->{nofilename}  ){
			$self->{mail_info}->{attachment} = 1;
			last;
		}
	}

	return $self->{mail_info};
}

sub print
{
	my ($self, $fh) = @_;

	if ( ! defined $self->{mime_parser} ) { return; }

	$self->{entity}->print($fh);

	# 只能 print 一次
	clean ( $self );
	undef $self->{mail_info};
	undef $self->{entity};
}

sub clean
{
	my $self = shift;

	if ( $self->{entity} ){
		$self->{entity}->purge;
	}

	if ( $self->{mime_parser} ){
		$self->{mime_parser}->filer->purge;
	}
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
	$self->{mail_info}->{head_size} = length( $content );

	#FIXME: here make a copy of head instead of make change of original entity;
	#my $head_decoded = $head;
	#$head = $head_decoded;
	#undef $head_decoded;

	$head->decode;
	$head->unfold;

	$self->{mail_info}->{head}->{from} = $head->get('From');
	$self->{mail_info}->{head}->{to} = $head->get('To');
	$self->{mail_info}->{head}->{cc} = $head->get('CC');
	$self->{mail_info}->{head}->{subject} = $head->get('Subject');

	# FIXME 正确取得 sender_ip & server_ip
	my @receiveds = $head->get("Received");
	my $server_ip = 1;
	for ( @receiveds ){
		if ( /(\d+\.\d+\.\d+\.\d+)/ ){
			if ( $server_ip ){
				$self->{mail_info}->{head}->{server_ip} = $1;
				$self->{mail_info}->{head}->{sender_ip} = $1;
				$server_ip = 0;
			}else{
				$self->{mail_info}->{haad}->{sender_ip} = $1;
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

	my $prefix;

        if ($body = $blob->bodyhandle) {
                if (defined $disposition && $disposition =~ /attachment/) {
                        $self->{zlog}->log ("    Atachment: " . $body->path );
                }
                $path = $body->path;

                $filename = $head->recommended_filename ;
                $size = ($path ? (-s $path) : 0);

                if ( !defined $filename ){
                        $filename = $path;
			$prefix = $self->{prefix} || "AKA-MailFilter-$$";

                        $filename =~ s/^.*\/$prefix\-//g;
			$self->{mail_info}->{body}->{$filename}->{nofilename} = 1;
                }else{
			$self->{mail_info}->{attachment_size} += $size;
			$self->{mail_info}->{attachment_num}++;
			$self->{mail_info}->{body}->{$filename}->{nofilename} = 0;
		}

		$self->{mail_info}->{body}->{$filename}->{path} = $path;
		$self->{mail_info}->{body}->{$filename}->{type} = $type;
		$self->{mail_info}->{body}->{$filename}->{subtype} = $subtype;
		
		if ( $type eq "text" && $subtype eq "plain") {
			$_ = load_file ( $self,$path, $size );
			$self->{mail_info}->{body}->{$filename}->{content} = $_;
			$self->{mail_info}->{body_text} .= $_;
		} elsif ( 1 == $load_binary ){
			$self->{mail_info}->{body}->{$filename}->{content} = load_file ( $self,$path, $size );
		}


		$self->{mail_info}->{body}->{$filename}->{size} = $size;

		#FIXME: 获取编码的body size
		$self->{mail_info}->{body_size} += $size;
			
		# 获取文件类型
		$self->{mail_info}->{body}->{$filename}->{typeclass} = get_attachment_type( $filename );

        } else {  
                foreach my $part ($blob->parts) {
                        &get_body_info( $self,$part );
                }
        }

}

sub get_attachment_type
{
	my $self = shift;
	
	my $filename = shift;

	my $i;
	my $filetype_num;

	foreach my $filetype ( keys %{$self->{filetype_num}} ){
		$filetype_num = $self->{filetype_num}->{$filetype};
		for ( $i=0; $self->{filetype}->{filetype}->[$i]; $i++ ){
			if ( $filename =~ /$_$/ ){
				return $filetype_num;
			}
		}
	}
			
	# 其他类型文件
	return 6;
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
