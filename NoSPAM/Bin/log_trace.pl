#!/usr/bin/perl -w
# 如果有误判，用户一般会直接回复给对方而不修改主题，如果对方也直接回复了并且没有修改主题，就会出现主题包含[垃圾]的日志
# 这时从 NoSPAM.csv 中 grep 出标题中含有 [垃圾] 的信，然后就可以得到可追查检查所需要的IP和域名
        
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
