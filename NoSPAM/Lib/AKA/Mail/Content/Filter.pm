#
# �����������Ӿ������ʼ�������
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
# �ı�$ת�塢����
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
		# ȱʡ�����ʼ� 7��accept ���ܸ��ʼ��������ַ����޲���
		$action = 7;
		$param = "";
	}


	$self->{zlog}->log ( "pf: return action [$action] param [$param]" );

	if ( 1==$action ){ 
		$param ||= 'This message was rejected';
		# 1��reject�����ء��ܾ��ʼ�����һ���ַ�������������Ϊ�����ʼ�ʱ���صĴ�����Ϣ��
		# ȱʡΪ'This message was rejected'
	}elsif ( 2==$action ){ # 2��discard �����ʼ����޲���
	}elsif ( 3==$action ){
		# 3��quarantine �����ʼ�����һ���ַ�������������Ϊ�����ʼ��Ĵ��Ŀ¼��
		# ȱʡΪ'/var/spool/uncmgw/Quarantines'
		$param ||= '/var/spool/uncmgw/Quarantines';
		if ( ! -d $param ){
			$self->{zlog}->log ( "pf: quarantines dir not exist: [$param]" );
		}
	}elsif ( 4==$action ){
		# FIXME 
		# 4��strip �����ʼ��еĸ�������һ���ַ�������������Ϊ�滻�������������ı���Ϣ���ݣ�
		# ȱʡΪ'�ʼ������а����в���ȫ�ļ�\$file���Ѿ������룡'
		$self->{zlog}->log ( "pf: FIXME: strip attachment action not support yet" );
	}elsif ( 5==$action ){
		# 5�� delay ���ʼ������������ʱ(��)����һ����������������Ϊ�����ʱ������
		if ( $param ){
			if ( $param < 600 ){
				sleep ( $param );
			}else{
				$self->{zlog}->log ( "pf: delay time too long! param: [$param], set to 600" );
				sleep ( 600 );
			}
		}
	}elsif ( 6==$action ){
		# 6�� null �����κβ������޲���
	}elsif ( 7==$action ){
		# 7��accept ���ܸ��ʼ��������ַ����޲���
	}elsif ( 8==$action ){
		# 8��addrcpt ��������ռ��ˡ���һ���ַ�������������Ϊ��ӵ��ռ����ʼ���ַ
		if ( ! $param ){
			$self->{zlog}->log ( "pf: addrcpt can't find param!" );
		}
	}elsif ( 9==$action ){
		# 9��delrcpt ɾ��ָ���ռ��ˣ��ö���ֻ�������ŷ��ռ��˵���ͷ������ʹ�ã����޲���
		if ( ! $param ){
			$self->{zlog}->log ( "pf: delrcpt can't find param!" );
		}
	}elsif ( 10==$action ){
		# 10��chgrcpt �ı�ָ�����ռ���Ϊ�µ��ռ��ˣ��ö���ֻ�������ŷ��ռ��˵���ͷ������ʹ�ã���
		# ��һ���ַ�������������Ϊ�µ��ռ����ʼ���ַ
		if ( ! $param ){
			$self->{zlog}->log ( "pf: chgrcpt can't find param!" );
		}
	}elsif ( 11==$action ){
		# 11��addhdr �����ͷ��¼����һ���ַ�������������Ϊ�µ���ͷ��¼
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
		# 12��delhdr ɾ����ͷ��¼��ɾ��ƥ�䵽ָ����ͷ�������ͷ��¼���ö���ֻ��������ͷ������ʹ�ã����޲���
		if ( ! $param ){
			$self->{zlog}->log ( "pf: delhdr can't find param!" );
		}else{
			my $head = $self->{parser}->{entity}->head;
			$head->delete( $tag );
		}
	}elsif ( 13==$action ){
		# 13��chghdr �޸���ͷ��¼����ƥ�䵽ָ����ͷ�������ͷ��¼�����µ���ͷ��¼���ö���ֻ��������ͷ������ʹ�ã���
		# ��һ���ַ�������������Ϊ�µ���ͷ��¼
		if ( ! $param ){
			$self->{zlog}->log ( "pf: chghdr can't find param!" );
		}else{
			# FIXME: param �ĸ�ʽ��������
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
#	# ɾ����ʱ�ļ�
#}

1;
