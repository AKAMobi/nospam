#!/usr/bin/perl -w
# ��������У��û�һ���ֱ�ӻظ����Է������޸����⣬����Է�Ҳֱ�ӻظ��˲���û���޸����⣬�ͻ�����������[����]����־
# ��ʱ�� NoSPAM.csv �� grep �������к��� [����] ���ţ�Ȼ��Ϳ��Եõ���׷��������Ҫ��IP������
        
        my ( $timestamp, $direction
                        , $ip, $from, $to, $subject, $size
                        , $virus, $virus_name, $virus_action
                        , $spam, $spam_reason, $spam_action
                        , $rule, $rule_action, $rule_param
                        , $dynamic, $dynamic_reason
           );

	my $domain;
	my $mx = {};
	my $net ;
#print NSOUT time, "\n";
        while ( <STDIN> ){
                ( $timestamp, $direction
                  , $ip, $from, $to, $subject, $size
                  , $virus, $virus_name, $virus_action
                  , $spam, $spam_reason, $spam_action
                  , $rule, $rule_action, $rule_param
                  , $dynamic, $dynamic_reason
                ) = split ',';
		next if ( $from=~/thunis/ );
		next unless ( $from=~/\@(\S+)/ );
		$domain=$1;

		next unless $ip=~/^(\d+\.\d+\.\d+)/;
		$net = $1;

		foreach ( keys %{$mx->{$domain}} ){
			/^(\d+\.\d+\.\d+)/;		
			$ip = $_ if ( $1 eq $net );
		}

		
		$mx->{$domain}->{$ip} = 1;
		$mx->{$domain}->{$ip}->{subject} = $subject;

#		print "$ip, $from, $to, $subject\n";
	}

	my $num = 0;
	foreach $domain ( keys %$mx ){
		$num = 0;
		foreach $ip ( keys %{$mx->{$domain}} ){
			if ( $num ){
				print "				IN	A	$ip\n"
			} else{
				print "$domain.mx	IN	A	$ip\n"
			}
			$num++;
		}
	}
