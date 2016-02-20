#
# 北京互联网接警中心邮件过滤器
# Company: AKA Information & Technology Co., Ltd.
# Author: Ed Lee
# EMail: zixia@zixia.net
# Date: 2004-02-10

package AKA::Mail::Content;

use Locale::TextDomain ('engine.nospam.cn');

use AKA::Mail::Log;
use AKA::Mail::Content::Conf;
use AKA::Mail::Content::Rule;
use AKA::Mail::Content::Parser;
use AKA::Mail::Content::Verify;
use MIME::Base64;
use Time::HiRes qw( usleep ualarm gettimeofday tv_interval );
use strict;
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
	$self->{conf} = $parent->{conf} || new AKA::Mail::Conf($self) ;
	$self->{content_conf} = new AKA::Mail::Content::Conf($self) ;
	$self->{parser} = $parent->{parser} || new AKA::Mail::Content::Parser($self);
	$self->{ruler} = $parent->{ruler} || new AKA::Mail::Content::Rule($self);
	$self->{verify} = $parent->{verify} || new AKA::Mail::Content::Verify($self);

	return $self;
}

#
# Main Process, must return mail_info
#
sub process
{
	my $self = shift;
	my $mail_info = shift;

        my $start_time=[gettimeofday];

	unless ( open ( MAIL, '<' . $mail_info->{aka}->{emlfilename} ) ){
		$self->{zlog}->fatal ( "Content::process can't open emlfile [" . $mail_info->{aka}->{emlfilename} . "]" );
                $mail_info->{aka}->{engine}->{content} = {
                                        result  => 0,
                                        desc    => __("internal error"),
                                        action  => 0,

                                        enabled => 1,
                                        runned  => 1,
                                        runtime => int(1000*tv_interval ($start_time, [gettimeofday]))
			};
		return $mail_info;
	}

	my ( $rule_info, $mail_info_detail);
	eval { # Parser will fatal error when some mail is unformed
		( $rule_info, $mail_info_detail) = $self->get_rule ( \*MAIL );
	};

	close MAIL;

	# update our mail_info
	$mail_info_detail->{aka} = $mail_info->{aka};
	$mail_info = $mail_info_detail;
	$self->{mail_info} = $mail_info;
	$mail_info->{aka}->{rule_info} = $rule_info;

	my ( $action, $param, $rule_id );

	if ( $rule_info ){
		# XXX change 'msp' to 'user'
		if ( 'msp' ne lc $rule_info->{id_type} ){
			use AKA::Mail::GA;
			my $AMG = new AKA::Mail::GA;
			$AMG->check_match($mail_info);
		}else{ # user rule
			;
		}
		$action = $rule_info->{rule_action}->{action};
		$param = $rule_info->{rule_action}->{action_param};
		$rule_id = $rule_info->{rule_id};
	}else{
		# 缺省接收邮件 6、accept 接受该邮件，正常分发。无参数
		$action = 6;
		$param = "";
		$rule_id = "";
	}

	$mail_info->{aka}->{engine}->{content} = {
		result  => ($rule_info->{rule_id}||0),
		desc    => $param,
		action  => $action,

		enabled => 1,
		runned  => 1,
		rule_info  => $rule_info,
		runtime => int(1000*tv_interval ($start_time, [gettimeofday]))
	};

	return $mail_info;
}

sub get_rule
{
	my $self = shift;
	
	my $fh = shift;

	my $mail_info = $self->{parser}->get_mail_info ( $fh );

	my ($is_user_rule, $rule_info) = $self->{ruler}->get_match_rule ( $mail_info );
	
	return ($rule_info, $mail_info);

}

sub log_match
{
	my $self = shift;
	my ( $rule_info, $mail_info ) = @_;

	my $serialno = rand;
	$serialno = $serialno * 9999;
	$serialno = int ( $serialno );

	my $logfile = $self->{content_conf}->{define}->{home} . "/log/" . $self->{content_conf}->{define}->{mspid} . "." . $self->{zlog}->get_time_stamp() . "." . $serialno . ".log";
	my $emlfile = $self->{content_conf}->{define}->{home} . "/log/" . $self->{content_conf}->{define}->{mspid} . "." . $self->{zlog}->get_time_stamp() . "." . $serialno . ".eml";

	my ( $head_data, $body_data );
	$head_data = $self->{parser}->{entity}->stringify_header;
	$body_data = $self->{parser}->{entity}->stringify_body;

	my $logdata = {};

	$logdata->{'asc-msp'}->{'log-data'}->{'match_record'}->{'time'} = $self->{zlog}->get_time_stamp();
	$logdata->{'asc-msp'}->{'log-data'}->{'match_record'}->{'rule_id'} = $rule_info->{rule_id};
	$logdata->{'asc-msp'}->{'log-data'}->{'match_record'}->{'category_id'} = $rule_info->{category_id};
	$logdata->{'asc-msp'}->{'log-data'}->{'match_record'}->{'client_ip'} = $mail_info->{head}->{sender_ip};
	$logdata->{'asc-msp'}->{'log-data'}->{'match_record'}->{'ip_zone'} = 0; #XXX

	# modified by Ed 2004-06-13 获取邮件原始的尺寸
	$logdata->{'asc-msp'}->{'log-data'}->{'match_record'}->{'size'} = $mail_info->{aka}->{size} ;
	#$logdata->{'asc-msp'}->{'log-data'}->{'match_record'}->{'size'} = $mail_info->{head_size} + $mail_info->{body_size}; #FIXME

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
	

	my $xs = $self->{content_conf}->get_filterdb_xml_simple();
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
