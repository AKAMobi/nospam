#
# 北京互联网接警中心邮件过滤器
# Company: AKA Information & Technology Co., Ltd.
# Author: Ed Lee
# EMail: zixia@zixia.net
# Date: 2004-02-10

package AKA::Mail::Content::Rule;

use AKA::Mail::Log;
use AKA::Mail::Content::Conf;
#use Exporter;
#use vars qw(@ISA @EXPORT);

#@ISA=qw(Exporter);

#@EXPORT=("function1", "function2", "function3");

use Data::Dumper;
# 改变$转义、缩进
$Data::Dumper::Useperl = 1;
$Data::Dumper::Indent = 1;

sub new
{
	my $class = shift;
	my $self = {};

	bless $self, $class;

	my ($parent) = shift;

	$self->{parent} = $parent;

	$self->{zlog} = $parent->{zlog} || new AKA::Mail::Log($self) ;
	#$self->{conf} = $parent->{conf} || new AKA::Mail::Conf($self) ;
	$self->{content_conf} = $parent->{content_conf} || new AKA::Mail::Content::Conf($self) ;

	return $self;
}

sub get_match_rule
{
	my $self = shift;
	
	my $mail_info = shift;

	# check GA rule
	my $rule_id = check_GA_rule( $self, $mail_info );

	if ( $rule_id ){
		#$self->{zlog}->debug( "pf: GA rule id $rule_id info: \n" . Dumper($self->{filterdb}->{$rule_id}) ), 
		# we should let other know which type of rule we matched.
		# 0 for user rule, >0 for GA.
		my $rule_info = $self->{filterdb}->{$rule_id};
		$rule_info->{id_type} = 'user';
		return (1,$rule_info);
	}

	# check user rule
	$rule_id = $self->check_user_rule( $mail_info );

	if ( $rule_id ){
		#$self->{zlog}->debug( "pf: user rule id $rule_id info: \n" . Dumper($self->{user_filterdb}->{$rule_id}) ), 
		# we should let other know which type of rule we matched.
		# 0 for user rule, > 0 for GA.
		return (0,$self->{user_filterdb}->{$rule_id});
	}

	return undef;
}

sub load_user_filter_db
{
	my $self = shift;

	if ( defined $self->{user_filterdb} ) { return; }
	
	$self->{user_filterdb} = $self->{content_conf}->get_user_filter_db();

	# 得到以 rule_id 为 key 的表
	$self->{user_filterdb} = $self->{user_filterdb}->{'rule-add-modify'}->{rule};
}


sub load_GA_filter_db
{
	my $self = shift;

	if ( defined $self->{filterdb} ) { return; }
	
	$self->{filterdb} = $self->{content_conf}->get_filter_db();

	# 得到以 rule_id 为 key 的表
	$self->{filterdb} = $self->{filterdb}->{'rule-add-modify'}->{rule};
}

sub check_GA_rule
{
	my $self = shift;
	my $mail_info = shift;

	$self->load_GA_filter_db();

	return $self->check_all_rule_backend('filterdb',$mail_info);
}

sub check_user_rule
{
	my $self = shift;
	my $mail_info = shift;

	$self->load_user_filter_db();

	return $self->check_all_rule_backend('user_filterdb',$mail_info);
}

sub check_all_rule_backend
{
	my $self = shift;
	my ($which_db,$mail_info) = @_;

	my $has_rule;
	my ($rule_logic,$attach_logic,$size_logic,$keyword_logic);
	# 规则检查顺序：以rule由小到大为序，依次检查
	foreach my $rule_id ( sort keys %{$self->{$which_db}} ){
		next if ( ! $rule_id );
		#$self->{zlog}->debug ( "pf: checking user rule id: $rule_id..." );

		# AND / OR / NOT
		# attachment & size & keyword is not controled by match_logic, it always use 'AND'
		# only sub rule ( ie, sub size rule ) should use match logic.
		$rule_logic = $self->{$which_db}->{$rule_id}->{rule_logic} || 'AND';
		$attach_logic = $self->{$which_db}->{$rule_id}->{attach_logic} || 'AND';
		$size_logic = $self->{$which_db}->{$rule_id}->{size_logic} || 'AND';
		$keyword_logic = $self->{$which_db}->{$rule_id}->{keyword_logic} || 'AND';

		$has_rule = 0;
		if ( $self->{$which_db}->{$rule_id}->{attachment} ){
			# 如果有相关的 rule，则必须匹配才可能符合
			# 不匹配则 next
			if ( 'OR' eq $rule_logic ){
				return $rule_id if $self->check_attachment_rule ( $which_db, $rule_id, $mail_info, $attach_logic );
			}elsif ( 'NOT' eq $rule_logic ){
				next until ! $self->check_attachment_rule ( $which_db, $rule_id, $mail_info, $attach_logic );
			}else{
				next until $self->check_attachment_rule ( $which_db, $rule_id, $mail_info, $attach_logic );
			}
			$has_rule = 1;
		}
		if ( $self->{$which_db}->{$rule_id}->{size} ){
			if ( 'OR' eq $rule_logic ){
				return $rule_id if $self->check_size_rule ( $which_db, $rule_id, $mail_info, $size_logic ) ;
			}elsif ( 'NOT' eq $rule_logic ){
				next until ! $self->check_size_rule ( $which_db, $rule_id, $mail_info, $size_logic ) ;
			}else{
				next until $self->check_size_rule ( $which_db, $rule_id, $mail_info, $size_logic ) ;
			}
			$has_rule = 1;
		}
		if ( $self->{$which_db}->{$rule_id}->{rule_keyword} ){
			if ( 'OR' eq $rule_logic ){
				return $rule_id if $self->check_keyword_rule ( $which_db, $rule_id, $mail_info, $keyword_logic );
			}elsif ( 'NOT' eq $rule_logic ){
				next until ! $self->check_keyword_rule ( $which_db, $rule_id, $mail_info, $keyword_logic );
			}else{
				next until $self->check_keyword_rule ( $which_db, $rule_id, $mail_info, $keyword_logic );
			}
#$self->{zlog}->debug ( "RULE: logic: MATCH check keyword rule " . $rule_id  . ' of logic ' . $keyword_logic );  
			$has_rule = 1;
		}
		if ( $has_rule ){
			#$self->{zlog}->debug ( "pf: rule id $rule_id MATCH!" );
			# 'NOT' and 'AND' return here.
			if ( $rule_logic eq 'OR' ){
				return undef;
			}else{ #'NOT' 'AND'
				return $rule_id;
			}
		}
	}	
	return undef;
}

sub check_attachment_rule
{
	my $self = shift;
	my ($which_db,$rule_id,$mail_info,$match_logic) = @_;

	# 没有附件，则不匹配任何附件规则
	if ( ! $mail_info->{attachment} ) { return 0; }

	my $attachment_rule = $self->{$which_db}->{$rule_id}->{attachment};

	# 如果没有规则，则认为匹配成功
	return 1 if ( ! $attachment_rule );

	if ( 'HASH' ne ref $attachment_rule ){
		#多条
		foreach my $sub_attachment_rule ( @{$attachment_rule} ){
			if ( 'OR' eq $match_logic ){
				return 1 if ( check_single_attachment_rule ( $self, $sub_attachment_rule, $mail_info ) );
			}elsif ( 'NOT' eq $match_logic ){
				return 0 if ( check_single_attachment_rule ( $self, $sub_attachment_rule, $mail_info ) );
			}else{# AND, is the default 
				return 0 if ( ! check_single_attachment_rule ( $self, $sub_attachment_rule, $mail_info ) );
			}
		}
		# if OR success, it has already returned, so here is NO-MATCH OR
		return 0 if ( 'OR' eq $match_logic );
		# AND / NOT will return if it not match, so here is MATCH
		return 1;
	}

	if ( 'NOT' eq $match_logic ){
		return ! check_single_attachment_rule ( $self, $attachment_rule, $mail_info );
#	}elsif ( 'OR' eq $match_logic ){
#		# if 'NOR' match, it should already return , so here is no match
#		return 0;
	}else{ # 'AND' 'OR' is same if there's only one match rule
		return check_single_attachment_rule ( $self, $attachment_rule, $mail_info );
	}
}

sub check_size_rule
{
	my $self = shift;
	my ($which_db,$rule_id,$mail_info,$match_logic) = @_;

	my $size_rule = $self->{$which_db}->{$rule_id}->{size};

	return if ( ! $size_rule );

	if ( 'HASH' ne ref $size_rule ){
		#多条
		foreach my $sub_size_rule ( @{$size_rule} ){
			if ( 'OR' eq $match_logic ){
				return 1 if ( check_single_size_rule ( $self, $sub_size_rule, $mail_info ) );
			}elsif ( 'NOT' eq $match_logic ){
				return 0 if ( check_single_size_rule ( $self, $sub_size_rule, $mail_info ) );
			}else{# AND, is the default 
				return 0 if ( ! check_single_size_rule ( $self, $sub_size_rule, $mail_info ) );
			}
		}
		# if OR success, it has already returned, so here is NO-MATCH OR
		return 0 if ( 'OR' eq $match_logic );
		# AND / NOT will return if it not match, so here is MATCH
		return 1;
	}
	if ( 'NOT' eq $match_logic ){
		return ! check_single_size_rule ( $self, $size_rule, $mail_info );
#	}elsif ( 'OR' eq $match_logic ){
#		# if 'NOR' match, it should already return , so here is no match
#		return 0;
	}else{ #'AND' 'OR' is same if there's only one match rule
		return check_single_size_rule ( $self, $size_rule, $mail_info );
	}
}

sub check_keyword_rule
{
	my $self = shift;
	my ($which_db,$rule_id,$mail_info,$match_logic) = @_;

	my $keyword_rule = $self->{$which_db}->{$rule_id}->{rule_keyword};

	return if ( ! $keyword_rule );

#$self->{zlog}->debug ( "RULE: ENTER: check keyword rule " . $rule_id  . ' of logic ' . $match_logic );  
	if ( 'ARRAY' eq ref $keyword_rule ){
		#多条
		foreach my $sub_keyword_rule ( @{$keyword_rule} ){
			if ( 'OR' eq $match_logic ){
#$self->{zlog}->debug ( "RULE: logic: check keyword rule " . $rule_id  . ' of logic ' . $match_logic );  
				return 1 if ( check_single_keyword_rule ( $self, $sub_keyword_rule, $mail_info ) );
#$self->{zlog}->debug ( "RULE: logic: not MATCH check keyword rule " . $rule_id  . ' of logic ' . $match_logic );  
			}elsif ( 'NOT' eq $match_logic ){
#$self->{zlog}->debug ( "RULE: logic: check keyword rule " . $rule_id  . ' of logic ' . $match_logic );  
				return 0 if ( check_single_keyword_rule ( $self, $sub_keyword_rule, $mail_info ) );
#$self->{zlog}->debug ( "RULE: logic: not MATCH check keyword rule " . $rule_id  . ' of logic ' . $match_logic );  
			}else{# AND, is the default 
				return 0 if ( ! check_single_keyword_rule ( $self, $sub_keyword_rule, $mail_info ) );
			}
		}
		# if OR success, it has already returned, so here is NO-MATCH OR
		return 0 if ( 'OR' eq $match_logic );
		# AND / NOT will return if it not match, so here is MATCH
		return 1;
	}

#$self->{zlog}->debug ( "RULE: logic: check keyword rule " . $rule_id  . ' of logic ' . $match_logic );  
	if ( 'NOT' eq $match_logic ){
		return ! check_single_keyword_rule( $self, $keyword_rule, $mail_info );
#	}elsif ( 'OR' eq $match_logic ){
#		# if 'NOR' match, it should already return , so here is no match
#		return 0;
	}else{ #'AND' 'OR' is same if there's only one match rule
		return check_single_keyword_rule( $self, $keyword_rule, $mail_info );
	}
}

sub check_single_attachment_rule
{
	my $self = shift;
	my ( $rule, $mail_info ) = @_;

	my ( $match_filename, $match_filetype, $match_filesize );
	$match_filename = $rule->{filename};
	$match_filetype = $rule->{filetype};
	$match_filesize = $rule->{sizevalue};

	foreach my $filename ( keys %{$mail_info->{body}} ){
		if ( $mail_info->{body}->{$filename}->{nofilename} ){
			next;
		}
		my $typeclass = $mail_info->{body}->{$filename}->{typeclass};
		my $size = $mail_info->{body}->{$filename}->{size} || 0;

		if ( defined $match_filename && (lc($filename) ne lc($match_filename)) ){
			next;
		}
		if ( defined $match_filetype && ($typeclass != $match_filetype) ){
			next;
		}
		if ( defined $match_filesize ){
			if ( ! check_size_value( $self, $size, $match_filesize ) ){
				next;
			}
		}
		# got match!
		return 1
	}

	return 0;
} 

#
# bytes,[NUMBER-NUMBER]，0表示不作限制
#
sub check_size_value
{
	my $self = shift;

	my ( $size, $match_size ) = @_;

	if ( ! defined $size || 0==length($size) ){
		$self->{zlog}->fatal ( "error: cannot get  SIZE:  it's undef?" );
		return 0;
	}

	if ( defined $match_size && $match_size =~ /(\d+)\-(\d+)/ ){
		$size_low = $1;
		$size_high = $2;
	}elsif ( defined $match_filesize ){
		$self->{zlog}->fatal ( "error: cannot parse  SIZEVALUE: [$match_size] to number-number" );
		return 0;
	}


	if ( 0==$size_low && $size <= $size_high ){
		return 1;
	}
	if ( 0==$size_high && $size >= $size_low ){
		return 1;
	}
	if ( $size >= $size_low && $size <= $size_high ){
		return 1;
	}

	# got no match!
	return 0;
}

sub ip2int{
	my $self = shift;
        my $ip = shift ;

        return undef unless $ip ;

        $ip =~ /0*(\d+)\.0*(\d+)\.0*(\d+)\.0*(\d+)/ ;
        $ip[0] = $1 ; $ip[1] = $2 ; $ip[2] = $3 ; $ip[3] = $4 ;

        $ip[0] = 0 if( !$ip[0] ) ; $ip[1] = 0 if( !$ip[1] ) ;
        $ip[2] = 0 if( !$ip[2] ) ; $ip[3] = 0 if( !$ip[3] ) ;

        ($ip[0] << 24) + ($ip[1]<<16) + ($ip[2]<<8) + $ip[3] ;
}

#
#	1 一个具体的IP，如："202.116.12.34"
# 	2 用减号"-"连接两个IP值，表示一个连续的IP段（包括两个断点），如："202.116.22.1-202.116.22.24"
#	3 用斜杠"/"分隔的一个IP值和一个数字。如："202.116.22.0/24"表示202.116.22.*
#
sub check_ip_range
{
	my $self = shift;

	my ( $ip, $ip_range ) = @_;

	my ( $ip_long, $start_long, $end_long );

	if ( !defined $ip_range ){ 
		$self->{zlog}->fatal ( "error: check_ip_range no range found!" );
		return 0;
	}

	if ( $ip_range =~ /^(\d+\.\d+\.\d+\.\d+)$/ ){
		#	1 一个具体的IP，如："202.116.12.34"
		return ( $ip eq $1 );
	}elsif ( $ip_range =~ /(\d+\.\d+\.\d+\.\d+)\-(\d+\.\d+\.\d+\.\d+)/ ){
		# 	2 用减号"-"连接两个IP值，表示一个连续的IP段（包括两个断点），如："202.116.22.1-202.116.22.24"
		my ( $ip_start, $ip_end ) = ( $1, $2 );

		$ip_long = ip2int($self, $ip);
		$start_long = ip2int($self, $ip_start);
		$end_long = ip2int($self, $ip_end);

		return ( ($ip_long >= $start_long) && ($ip_long <= $end_long) );
	}elsif ( $ip_range =~ /(\d+\.\d+\.\d+\.\d+)\/(\d+)/ ){
		#	3 用斜杠"/"分隔的一个IP值和一个数字。如："202.116.22.0/24"表示202.116.22.*
		my $bits = 32-$2;
		my $match_long = ip2int($self, $1);
		$ip_long = ip2int($self, $ip);

		$match_long = $match_long >> $bits;
		$ip_long = $ip_long >> $bits;

		return ( $ip_long == $match_long );
	}

	$self->{zlog}->fatal ( "error: check_ip_range got invalid ip range: [$ip_range]" );
	# got no match!
	return 0;
}
	
sub check_single_size_rule
{
	my $self = shift;
	my ( $rule, $mail_info ) = @_;

	my ( $match_key, $match_size );

	$match_key = $rule->{key};
	$match_size = $rule->{sizevalue};

	if ( ! $match_key || ! $match_size ){
		$self->{zlog}->fatal ( "error: cannot find SIZE KEY & SIZEVALUE: [$match_size]" );
		return 0;
	}

	if ( 1==$match_key ){ # 全文大小
		my $mail_size;
		$mail_size = $mail_info->{body_size} + $mail_info->{head_size};
		return ( check_size_value( $self, $mail_size, $match_size ) );
	}elsif ( 2==$match_key ){ # 信头
		return ( check_size_value( $self, $mail_info->{head_size}, $match_size ) );
	}elsif ( 3==$match_key ){ # 信体
		return ( check_size_value( $self, $mail_info->{body_size}, $match_size ) );
	}elsif ( 4==$match_key ){ # 附件
		return ( check_size_value( $self, $mail_info->{attachment_size}, $match_size ) );
	}elsif ( 5==$match_key ){ # 附件个数
		return ( check_size_value( $self, $mail_info->{attachment_num}, $match_size ) );
	#
	# 以下是对 MSP1.8 的扩展 
	#
	}elsif ( 150==$match_key ){ # To+Cc+Bcc 个数 
		return ( check_size_value( $self, $mail_info->{head}->{to_cc_bcc_num}, $match_size ) );
	}
	
	$self->{zlog}->fatal ( "error: unimplement size key: [$match_key]" );
	return 0;
} 

#
# 检查：1、模糊，2【罚�3、正则匹配
#
sub check_re_match
{
	my $self = shift;
	my ( $content, $match_keyword, $match_type ) = @_;

	if ( ! defined $match_keyword || ! defined $match_type || ! defined $content ){
		#$self->{zlog}->fatal ( "error: check_regex not enough param. re: $re, is_re: $is_re, content: $content" );
		return 0;
	}

	#FIXME: 0 & 9 should not use RE match
	if ( 0==$match_type ){
		#字符串模糊匹配
#print "in [$content] find [$match_keyword], result: " . "[" . index($content,$match_keyword) . "]\n\n\n";
		#return ( -1 != rindex($content,$match_keyword) );
		return ( $content=~/$match_keyword/ );
	}elsif( 1==$match_type ){
		#正则匹配
		return ( $content=~/$match_keyword/ );
	}elsif( 9==$match_type ){
		#字符串精确匹配
		#return ( -1 != index($content,$match_keyword) );
		return ( $content=~/$match_keyword/ );
	}

}

sub check_single_keyword_rule
{
	my $self = shift;
	my ( $rule, $mail_info ) = @_;

	my ( $match_key, $match_decode, $match_case_sensitive, $match_type, $match_keyword );
	$match_key = $rule->{key};
	$match_type = $rule->{type};
	$match_keyword = $rule->{keyword};

	# XXX fix it, or find out reason.
	if ( ! length($mail_info->{body_text}) ){
		$self->{zlog}->fatal( "match_key: $match_key, match_keyword: $match_keyword, match_type: $match_type " . $mail_info->{head}->{subject} . ", " . $mail_info->{head}->{from} . ", " . $mail_info->{head}->{from} )
	}
	if ( 1==$match_key ){ #1主题包含关键字
		return check_re_match ( $self, $mail_info->{head}->{subject}, $match_keyword, $match_type );
	}elsif ( 2==$match_key ){ #2发件人包含关键字
		return check_re_match ( $self, $mail_info->{head}->{from}, $match_keyword, $match_type );
	}elsif ( 3==$match_key ){ #3收件人包含关键字
		return check_re_match ( $self, $mail_info->{head}->{to}, $match_keyword, $match_type );
	}elsif ( 4==$match_key ){ #4抄送人包含关键字
		return check_re_match ( $self, $mail_info->{head}->{cc}, $match_keyword, $match_type );
	}elsif ( 5==$match_key ){ #5信头包含关键字
		return check_re_match ( $self, $mail_info->{head}->{content}, $match_keyword, $match_type );
	}elsif ( 6==$match_key ){ #6信体包含关键字
		return check_re_match ( $self, $mail_info->{body_text}, $match_keyword, $match_type );
	}elsif ( 7==$match_key ){ #7全文包含关键字
		return (    	    check_re_match ( $self, $mail_info->{head}->{content}, $match_keyword, $match_type )
				||  check_re_match ( $self, $mail_info->{body_text}, $match_keyword, $match_type )
			);
	}elsif ( 8==$match_key ){ #8附件包含关键字
		#FIXME 当前是匹配文件名而不是内容
		foreach my $filename ( keys %{$mail_info->{body}} ){
			if ( check_re_match ( $self, $filename, $match_keyword, $match_type ) ){
				return 1;
			}
		}
		#
		# FIXME 匹配文件名后，匹配所有的文本类型的附件；
		#
		return check_re_match ( $self, $mail_info->{body_text}, $match_keyword, $match_type );
		# return 0;
	}elsif ( 9==$match_key ){ #9客户端IP为指定值或在指定范围内
		return check_ip_range( $self, $mail_info->{head}->{server_ip}, $match_keyword );
	}elsif ( 10==$match_key ){ #10源客户端IP（邮件中标识的起始的IP地址）为指定值或在指定范围内
		return check_ip_range( $self, $mail_info->{head}->{sender_ip}, $match_keyword );
	}
	
	$self->{zlog}->fatal ( "error: check_single_keyword_rule find unknown key value [$match_key]." );

	return 0;
} 

#
#sub DESTROY
#{
#	# 删除临时文件
#}

1;
