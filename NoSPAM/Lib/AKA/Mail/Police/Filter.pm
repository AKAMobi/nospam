#
# 北京互联网接警中心邮件过滤器
# Company: AKA Information & Technology Co., Ltd.
# Author: Ed Lee
# EMail: zixia@zixia.net
# Date: 2004-02-10

package AKA::Mail::Police::Filter;

use AKA::Mail::Police::Log;
use AKA::Mail::Police::Conf;
use AKA::Mail::Police::Rule;
use AKA::Mail::Police::Parser;
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

	$self->{zlog} = $parent->{zlog} || new AKA::Mail::Police::Log($self) ;
	$self->{conf} = $parent->{conf} || new AKA::Mail::Police::Conf($self) ;
	$self->{parser} = $parent->{parser} || new AKA::Mail::Police::Parser($self);
	$self->{ruler} = $parent->{ruler} || new AKA::Mail::Police::Rule($self);
	$self->{verify} = $parent->{verify} || new AKA::Mail::Police::Rule($self);

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
		$self->{zlog}->log_match($rule_info, $mail_info), 
		$action = $rule_info->{rule_action}->{action};
		$param = $rule_info->{rule_action}->{action_param};
	}else{
		# 缺省接收邮件 7、accept 接受该邮件，正常分发。无参数
		$action = 7;
		$param = "";
	}


	$self->{zlog}->log ( "pf: return action [$action] param [$param]" );

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
			$self->{zlog}->log ( "pf: quarantines dir not exist: [$param]" );
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

sub print
{
	my $self = shift;
	my $action = shift;
	if ( $action != 1 && $action != 2 && $action != 3 ){
		$self->{parser}->print ( \*STDOUT );
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
