#
# 北京互联网接警中心邮件过滤器
# Company: AKA Information & Technology Co., Ltd.
# Author: Ed Lee
# EMail: zixia@zixia.net
# Date: 2004-02-10

package AKA::Mail::Police::Filter;

use AKA::Mail::Log;
use AKA::Mail::Police::Conf;
use AKA::Mail::Police::Rule;
use AKA::Mail::Police::Parser;

use MIME::Base64;
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

	my ($parent) = shift;

	$self->{parent} = $parent;

	$self->{zlog} = $parent->{zlog} || new AKA::Mail::Log($self) ;
	$self->{conf} = $parent->{conf} || new AKA::Mail::Police::Conf($self) ;
	$self->{parser} = $parent->{parser} || new AKA::Mail::Police::Parser($self);
	$self->{ruler} = $parent->{ruler} || new AKA::Mail::Police::Rule($self);
	$self->{verify} = $parent->{verify} || new AKA::Mail::Police::Verify($self);

	return $self;
}

sub get_action
{
	my $self = shift;
	
	my $fh = shift;

	my $mail_info = $self->{parser}->get_mail_info ( $fh );

	my $rule_info = $self->{ruler}->get_match_rule ( $mail_info );
	
	my ( $action, $param );

	if ( $rule_info ){
		$self->log_match($rule_info, $mail_info), 
		$action = $rule_info->{rule_action}->{action};
		$param = $rule_info->{rule_action}->{action_param};
	}else{
		# 缺省接收邮件 7、accept 接受该邮件，正常分发。无参数
		$action = 7;
		$param = "";
	}


	$self->{zlog}->debug ( "pf: return action [$action] param [$param] for " . $mail_info->{head}->{from} .  ":" . $mail_info->{head}->{server_ip} . "=>" . $mail_info->{head}->{to} );

	if ( 1==$action ){ 
		$param ||= 'This message was rejected';
		# 1、reject：弹回、拒绝邮件。带一个字符串参数，内容为拒收邮件时返回的错误信息，
		# 缺省为'This message was rejected'
	}elsif ( 2==$action ){ # 2、discard 丢弃邮件。无参数
	}elsif ( 3==$action ){
		# 3、quarantine 隔离邮件。带一个字符串参数，内容为隔离邮件的存放目录，
		# 缺省为'/var/spool/uncmgw/Quarantines'
		$param ||= '/var/spool/uncmgw/Quarantines';
		if ( ! -d $param ){
			if ( `mkdir -p $param > /dev/null 2>&1` ){
				$self->{zlog}->log ( "pf: quarantines dir not exist and FAIL to create: [$param]" );
			}else{
				$self->{zlog}->log ( "pf: quarantines dir not exist and created it: [$param]" );
			}
		}
	}elsif ( 4==$action ){
		# FIXME 
		# 4、strip 剥离邮件中的附件。带一个字符串参数，内容为替换被剥除附件的文本信息内容，
		# 缺省为'邮件附件中包含有不安全文件\$file，已经被剥离！'
		$self->{zlog}->log ( "pf: FIXME: strip attachment action not support yet" );
	}elsif ( 5==$action ){
		# 5、 delay 给邮件处理操作加延时(秒)。带一个整数参数，内容为添加延时的秒数
		if ( $param ){
			if ( $param < 600 ){
				sleep ( $param );
			}else{
				$self->{zlog}->log ( "pf: delay time too long! param: [$param], set to 600" );
				sleep ( 600 );
			}
		}
	}elsif ( 6==$action ){
		# 6、 null 不做任何操作。无参数
	}elsif ( 7==$action ){
		# 7、accept 接受该邮件，正常分发。无参数
	}elsif ( 8==$action ){
		# 8、addrcpt 添加其他收件人。带一个字符串参数，内容为添加的收件人邮件地址
		if ( ! $param ){
			$self->{zlog}->log ( "pf: addrcpt can't find param!" );
		}
	}elsif ( 9==$action ){
		# 9、delrcpt 删除指定收件人（该动作只允许在信封收件人的信头规则中使用）。无参数
		if ( ! $param ){
			$self->{zlog}->log ( "pf: delrcpt can't find param!" );
		}
	}elsif ( 10==$action ){
		# 10、chgrcpt 改变指定的收件人为新的收件人（该动作只允许在信封收件人的信头规则中使用）。
		# 带一个字符串参数，内容为新的收件人邮件地址
		if ( ! $param ){
			$self->{zlog}->log ( "pf: chgrcpt can't find param!" );
		}
	}elsif ( 11==$action ){
		# 11、addhdr 添加信头纪录。带一个字符串参数，内容为新的信头记录
		if ( ! $param ){
			$self->{zlog}->log ( "pf: addhdr can't find param!" );
		}else{
			if ( $param =~ /([^\:]+):\s*(.*)/ ){
				my ( $tag, $data ) = ( $1, $2 );
				my $head = $self->{parser}->{entity}->head;
				$head->add( $tag, $data );
			}else{
				$self->{zlog}->log ( "pf: addhdr cannot parse param [$param] to tag: text." );
			}
		}
	}elsif ( 12==$action ){
		# 12、delhdr 删除信头纪录，删除匹配到指定信头规则的信头记录（该动作只允许在信头规则中使用）。无参数
		if ( ! $param ){
			$self->{zlog}->log ( "pf: delhdr can't find param!" );
		}else{
			my $head = $self->{parser}->{entity}->head;
			$head->delete( $tag );
		}
	}elsif ( 13==$action ){
		# 13、chghdr 修改信头纪录，将匹配到指定信头规则的信头记录换成新的信头记录（该动作只允许在信头规则中使用）。
		# 带一个字符串参数，内容为新的信头记录
		if ( ! $param ){
			$self->{zlog}->log ( "pf: chghdr can't find param!" );
		}else{
			# FIXME: param 的格式是这样吗？
			if ( $param =~ /([^\:]+):\s*(.*)/ ){
				my ( $tag, $data ) = ( $1, $2 );
				my $head = $self->{parser}->{entity}->head;
				$head->delete( $tag );
				$head->add( $tag, $data );
			}else{
				$self->{zlog}->log ( "pf: chghdr cannot parse param [$param] to tag: text." );
			}
		}
	
	}	

	($action, $param)
}

sub log_match
{
	my $self = shift;
	my ( $rule_info, $mail_info ) = @_;

	my $serialno = rand;
	$serialno = $serialno * 9999;
	$serialno = int ( $serialno );

	my $logfile = $self->{conf}->{define}->{home} . "/log/" . $self->{conf}->{define}->{mspid} . "." . $self->{zlog}->get_time_stamp() . "." . $serialno . ".log";
	my $emlfile = $self->{conf}->{define}->{home} . "/log/" . $self->{conf}->{define}->{mspid} . "." . $self->{zlog}->get_time_stamp() . "." . $serialno . ".eml";

	my ( $head_data, $body_data );
	$head_data = $self->{parser}->{entity}->stringify_header;
	$body_data = $self->{parser}->{entity}->stringify_body;

	my $logdata = {};

	$logdata->{'asc-msp'}->{'log-data'}->{'match_record'}->{'time'} = $self->{zlog}->get_time_stamp();
	$logdata->{'asc-msp'}->{'log-data'}->{'match_record'}->{'rule_id'} = $rule_info->{rule_id};
	$logdata->{'asc-msp'}->{'log-data'}->{'match_record'}->{'category_id'} = $rule_info->{category_id};
	$logdata->{'asc-msp'}->{'log-data'}->{'match_record'}->{'client_ip'} = $mail_info->{head}->{sender_ip};
	$logdata->{'asc-msp'}->{'log-data'}->{'match_record'}->{'ip_zone'} = 0; #XXX
	$logdata->{'asc-msp'}->{'log-data'}->{'match_record'}->{'size'} = $mail_info->{head_size} + $mail_info->{body_size}; #FIXME
	$logdata->{'asc-msp'}->{'log-data'}->{'match_record'}->{'body_size'} = $mail_info->{body_size};

	$emlfile =~ m#/([^/]+)$#;
	$logdata->{'asc-msp'}->{'log-data'}->{'match_record'}->{'mail_file'} = $1 || $emlfile;

	$logdata->{'asc-msp'}->{'log-data'}->{'match_record'}->{'condition'} = [ $rule_info->{rule_action}->{action_param} ];
	$logdata->{'asc-msp'}->{'log-data'}->{'match_record'}->{'action'} = [ $rule_info->{rule_action}->{action} ];
	$logdata->{'asc-msp'}->{'log-data'}->{'match_record'}->{'sender'} = [ $mail_info->{head}->{from}] ;
	$logdata->{'asc-msp'}->{'log-data'}->{'match_record'}->{'subject'} = [ $mail_info->{head}->{subject} ];
	$logdata->{'asc-msp'}->{'log-data'}->{'match_record'}->{'mail_header'} = [ &encode_base64( $head_data ) ];
	$logdata->{'asc-msp'}->{'log-data'}->{'match_record'}->{'mail_content'} = [ &encode_base64( $body_data ) ];

	open ( FD, ">$emlfile" ) or $self->{zlog}->log ( "pf: open $emlfile for writing error" );
	print FD $head_data;
	print FD "\n";
	print FD $body_data;
	close ( FD );
	

	my $xs = $self->{conf}->get_filterdb_xml_simple();
	my $xml = $xs->XMLout( $logdata, XMLDecl=>'<?xml version="1.0" encoding="ISO-8859-1"?>',NoAttr=>0 );

	open ( FD, ">$logfile" ) or $self->{zlog}->log ( "pf: open $logfile for writing error" );
	print FD $xml;
	close ( FD );
	
	if ( ! $self->{verify}->sign_key($emlfile) ){
		$self->{zlog}->log ( "pf: error for sign file [$emlfile]" );
		unlink $emlfile;
	}
	if ( ! $self->{verify}->sign_key($logfile) ){
		$self->{zlog}->log ( "pf: error for sign file [$logfile]" );
		unlink $logfile;
	}
}


sub print
{
	my $self = shift;
	my ($action,$output_fd) = @_;

	if ( $action != 1 && $action != 2 && $action != 3 ){
		$self->{parser}->print ( $output_fd );
	}
}

sub clean
{
	my $self = shift;

	$self->{parser}->clean();
}

#sub DESTROY
#{
#	# 删除临时文件
#}

1;
