#
# NoSPAM网关配置文件读取模块
# Company: AKA Information & Technology Co., Ltd.
# Author: Ed Lee
# EMail: zixia@zixia.net
# Date: 2004-02-29


package AKA::Mail::Conf;

use AKA::Mail::Log;

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

	my $parent = shift;

	$self->{parent} = $parent;

	$self->{define}->{home} = "/home/NoSPAM/";
	$self->{define}->{conffile} = $self->{define}->{home} . "/etc/NoSPAM.conf";
	$self->{define}->{intconffile} = $self->{define}->{home} . "/etc/NoSPAM.intconf";
	$self->{define}->{licensefile} = $self->{define}->{home} . "/etc/License.dat";

	#$self->{zlog} = $parent->{zlog};

	$self->init_config;	# config
	$self->init_intconf;	# intconf
	$self->init_licconf;	# licconf

	return $self;
}


sub init_licconf
{
	my $self = shift;

        my $licconf;
        
	use Config::Tiny;
	my $C = Config::Tiny->read( $self->{define}->{licensefile} );

	$licconf = $C->{_};
                        
        $self->{licconf} = $licconf;
}                       


sub init_intconf
{
	my $self = shift;

        my $intconf;
        
	use Config::Tiny;
	my $C = Config::Tiny->read( $self->{define}->{intconffile} );

	$intconf = $C->{_};
                        
        $intconf->{GAViewable} ||= 'N';
        $intconf->{UserLogUpload} ||= 'N';
        $intconf->{MailGatewayInternalIP} ||= '10.4.3.7';
        $intconf->{MailGatewayInternalMask} ||= 32;
                        
        $self->{intconf} = $intconf;
}                       

sub init_config
{
	my $self = shift;

#	return $self->{config} if ( $self->{config} );

	use Config::Tiny;
	my $config = Config::Tiny->read( $self->{define}->{conffile} );

	#
	# System
	#
	$config->{System}->{ServerGateway} ||= "Gateway";

	#
	# Spam
	#
	$config->{SpamEngine}->{Traceable} ||= "N";
	my @default_trace_type = ('Mail','IP');
	$config->{SpamEngine}->{TraceType} = cut_comma_to_array_ref( $self,$config->{TraceType} ) || \@default_trace_type;
	$config->{SpamEngine}->{TraceSpamMask} ||= "16";
	$config->{SpamEngine}->{TraceMaybeSpamMask} ||= "22";

	$config->{SpamEngine}->{BlockFrom} ||= "N";
	$config->{SpamEngine}->{BlackFromList} = cut_comma_to_array_ref( $self,$config->{SpamEngine}->{BlackFromList} );
	$config->{SpamEngine}->{WhiteFromList} = cut_comma_to_array_ref( $self,$config->{SpamEngine}->{WhiteFromList} );

	$config->{SpamEngine}->{BlockDomain} ||= "N";
	$config->{SpamEngine}->{BlackDomainList} = cut_comma_to_array_ref( $self,$config->{SpamEngine}->{BlackDomainList} );
	$config->{SpamEngine}->{WhiteDomainList} = cut_comma_to_array_ref( $self,$config->{SpamEngine}->{WhiteDomainList} );

	$config->{SpamEngine}->{BlockIP} ||= "N";
	$config->{SpamEngine}->{BlackIPList} = cut_comma_to_array_ref( $self,$config->{SpamEngine}->{BlackIPList} );
	$config->{SpamEngine}->{WhiteIPList} = cut_comma_to_array_ref( $self,$config->{SpamEngine}->{WhiteIPList} );

	$config->{SpamEngine}->{SpamTag} ||= "【垃圾邮件】";
	$config->{SpamEngine}->{MaybeSpamTag} ||= "【疑似垃圾】";

	$config->{SpamEngine}->{RefuseSpam} ||= "N";

	$config->{SpamEngine}->{TagHead} ||= "Y";
	$config->{SpamEngine}->{TagSubject} ||= "Y";
	$config->{SpamEngine}->{TagReason} ||= "Y";

	#
	# Dynamic
	#
	$config->{DynamicEngine}->{ConnPerIP} ||= 0;
	$config->{DynamicEngine}->{ConnRatePerIP} ||= "0/0/0";
	$config->{DynamicEngine}->{SendRatePerSubject} ||= "0/0/0";
	$config->{DynamicEngine}->{SendRatePerFrom} ||= "0/0/0";

	$config->{DynamicEngine}->{WhiteIPConcurList} = $self->cut_comma_to_array_ref( 
								$config->{DynamicEngine}->{WhiteIPConcurList} 
							);
	$config->{DynamicEngine}->{WhiteFromList} = 	$self->cut_comma_to_array_ref( 
								$config->{DynamicEngine}->{WhiteFromList} 
							);
	$config->{DynamicEngine}->{WhiteSubjectList} = $self->cut_comma_to_array_ref( 
								$config->{DynamicEngine}->{WhiteSubjectList} 
							);
	$config->{DynamicEngine}->{WhiteIPRateList} = $self->cut_comma_to_array_ref( 
								$config->{DynamicEngine}->{WhiteIPRateList} 
							);


	#
	# Network
	#
	$config->{Network}->{Hostname} ||= "factory.gw.nospam.aka.cn";
	$config->{Network}->{NetMask} ||= "24";

	$config->{Network}->{IP} ||= "192.168.0.150";

	#
	# Archive
	#
	$config->{ArchiveEngine}->{ArchiveEngine} ||= "N";
	$config->{ArchiveEngine}->{ArchiveType} = $self->cut_comma_to_array_ref( 
								$config->{ArchiveEngine}->{ArchiveType} 
							);

	$config->{ArchiveEngine}->{ArchiveAddress} = $self->cut_comma_to_array_ref( 
								$config->{ArchiveEngine}->{ArchiveAddress} 
							);

	#
	# MailServer
	#
	$config->{MailServer}->{ProtectDomain} = $self->get_protectd_domain_hash_ref($config);
	$config->{MailServer}->{VirtualDomain} = $self->get_virtual_domain_hash_ref($config);

	$self->{config} = $config;
}

#逗号分割的管理员列表
#VirtualDomain_zixia.net_Admin=zixia,qinling
# Bytes，0或者不存在key代表不限制
#VirtualDomain_zixia.net_Quota=1024000
#最多用户数
#VirtualDomain_zixia.net_MaxUser=100
#域的类别（分类）
#VirtualDomain_zixia.net_Cate=个人域

sub get_virtual_domain_hash_ref
{
	my $self = shift;
	my $config = shift;

	my $MailServer = $config->{MailServer};

	#
	# $h->{$domain}->{Admin}
	#		->{Quota}
	#		->{MaxUser}
	#		->{Cate}
	my $h = {};
	my ( $key, $val );
	my $domain;
	while ( ($key,$val) = each %{$MailServer} ){
		if ( $key=~/^VirtualDomain_(.+)_Admin$/ ){
			my @array = split ( /,/, $val );
			$h->{$1}->{Admin} = \@array;
		}elsif ( $key =~ /^VirtualDomain_(.+)_Quota$/ ){
			$h->{$1}->{Quota} = $val;
		}elsif ( $key =~ /^VirtualDomain_(.+)_MaxUser$/ ){
			$h->{$1}->{MaxUser} = $val;
		}elsif ( $key =~ /^VirtualDomain_(.+)_Cate$/ ){
			$h->{$1}->{Cate} = $val;
		}
	}

	return $h;
}


#ProtectDomain_zixia.net_IPPort=202.205.10.7:25
#ProtectDomain_zixia.net_Cate=个人域
sub get_protectd_domain_hash_ref
{
	my $self = shift;
	my $config = shift;

	my $MailServer = $config->{MailServer};

	#
	# $h->{$domain}->{IP}
	#		->{Port}
	#		->{Cate}
	my $h = {};
	my ( $key, $val );
	my $domain;
	while ( ($key,$val) = each %{$MailServer} ){
		if ( $key=~/^ProtectDomain_(.+)_IPPort$/ ){
			$domain = $1;
			if ( $val =~ /^(\d+\.\d+\.\d+\.\d+)/ ){
				$h->{$domain}->{IP} = $1;
			}
			if ( $val =~ /:(\d+)$/ ){
				$h->{$domain}->{Port} = $1;
			}else{
				$h->{$domain}->{Port} = 25;
			}
		}elsif ( $key =~ /^ProtectDomain_(.+)_Cate$/ ){
			$h->{$1}->{Cate} = $val;
		}
	}

	return $h;
}

sub cut_comma_to_array_ref
{
	my $self = shift;
	my $conf_line = shift;
	return undef if ( !defined $conf_line || !length($conf_line) );

	my @ret;
	foreach ( split(',', $conf_line) ){
		next if ( !defined $_ || !length($_) );
		#strip comments from list
		s/#.*//;
		push ( @ret, $_ );
	}

	return \@ret;
}

sub DESTROY
{
	my $self = shift;

	delete $self->{parent};

}

1;
