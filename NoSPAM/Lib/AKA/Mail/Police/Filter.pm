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
	$self->{parser} = new AKA::Mail::Police::parser($self);
	$self->{ruler} = new AKA::Mail::Police::Rule($self);

	return $self;
}

sub filter
{
	my $self = shift;
	
	my $fh = shift;

	my $mail_info = $self->{parser}->get_mail_info ( $fh );

	my $rule_info = $self->{ruler}->get_match_rule ( $mail_info );
	
	if ( $rule_info ){
		$self->{zlog}->log_match($rule_info, $mail_info), 
		return ($rule_info->{rule_action}->{action}, $rule_info->{rule_action}->{action_param});
	}

	# 缺省接收邮件
	# 	7、accept 接受该邮件，正常分发。无参数
	return (7,"");
		
}


#sub DESTROY
#{
#	# 删除临时文件
#}

1;
