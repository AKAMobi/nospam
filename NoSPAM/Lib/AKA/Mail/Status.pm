#
# RRD 监控图生成
# Company: AKA Information & Technology Co., Ltd.
# Author: Ed Lee
# EMail: zixia@zixia.net
# Date: 2004-05-03

package AKA::Mail::Status;

use strict;
use RRDs;
use POSIX qw(strftime);

sub new
{
	my $class = shift;

	my $self = {};

	bless $self, $class;

	$self->{define}->{rrdpath} = '/home/NoSPAM/var/rrd/';
	$self->{define}->{gifpath} = "/home/NoSPAM/admin/status/";
	return $self;
}

sub gen_gif
{
	my $self = shift;
	
	my $now = strftime "%Y-%m-%d %H:%M:%S", localtime;

	#my $rrdfile = $self->{define}->{rrdfile};

	my $rrdgraph_func = {};
	my $rrdgraph_param = {};

	my ( $start_time,$end_time,@vrules );

	#( $start_time,$end_time,@vrules ) = $self->get_day_param;
	my @day_params = $self->get_day_param;
	$rrdgraph_param->{day} = \@day_params;
	my @week_params = $self->get_week_param;
	$rrdgraph_param->{week} = \@week_params;
	my @month_params = $self->get_month_param;
	$rrdgraph_param->{month} = \@month_params;
	my @year_params = $self->get_year_param;
	$rrdgraph_param->{year} = \@year_params;

	$rrdgraph_func->{mail_size} = \&rrdgraph_size;
	$rrdgraph_func->{mail_traffic} = \&rrdgraph_traffic;
	$rrdgraph_func->{mail_engine} = \&rrdgraph_engine;
	$rrdgraph_func->{mail_type} = \&rrdgraph_type;
	$rrdgraph_func->{dns} = \&rrdgraph_dns;

	my $rrdpath = $self->{define}->{rrdpath};
	my $gifpath = $self->{define}->{gifpath};

	umask 022;
	foreach my $name ( keys %$rrdgraph_func ){
		foreach my $period ( keys %$rrdgraph_param ){
			my $rrdfile = $rrdpath . $name . '.rrd';
			my $giffile = $gifpath . $name . "-$period.gif";
			my @params = @{$rrdgraph_param->{$period}};
#print "gen gif : $name , $rrdfile, $giffile, $period, " . join (',',@params) . "\n";
			&{$rrdgraph_func->{$name}}( $self, $rrdfile, $giffile, $now, @params );

			my $err=RRDs::error;
			if ($err) {print "problem generating the graph: $err\n";}
		}
	}

=pod
	$self->rrdgraph_size($rrdfile, $gifpath . 'mail_size-day.gif', $now, $start_time, $end_time, @vrules);
	$self->rrdgraph_traffic($rrdfile, $gifpath . 'mail_traffic-day.gif', $now, $start_time, $end_time, @vrules);
	$self->rrdgraph_engine($rrdfile, $gifpath . 'mail_engine-day.gif', $now, $start_time, $end_time, @vrules);
	$self->rrdgraph_type($rrdfile, $gifpath . 'mail_type-day.gif', $now, $start_time, $end_time, @vrules);
	$self->rrdgraph_dns($rrdfile, $gifpath . 'dns-day.gif', $now, $start_time, $end_time, @vrules);

	( $start_time,$end_time,@vrules ) = $self->get_week_param;
	$self->rrdgraph_size($rrdfile, $gifpath . 'mail_size-week.gif', $now, $start_time, $end_time, @vrules);
	$self->rrdgraph_traffic($rrdfile, $gifpath . 'mail_traffic-week.gif', $now, $start_time, $end_time, @vrules);
	$self->rrdgraph_engine($rrdfile, $gifpath . 'mail_engine-week.gif', $now, $start_time, $end_time, @vrules);
	$self->rrdgraph_type($rrdfile, $gifpath . 'mail_type-week.gif', $now, $start_time, $end_time, @vrules);
	$self->rrdgraph_dns($rrdfile, $gifpath . 'dns-week.gif', $now, $start_time, $end_time, @vrules);

	( $start_time,$end_time,@vrules ) = $self->get_month_param;
	$self->rrdgraph_size($rrdfile, $gifpath . 'mail_size-month.gif', $now, $start_time, $end_time, @vrules);
	$self->rrdgraph_traffic($rrdfile, $gifpath . 'mail_traffic-month.gif', $now, $start_time, $end_time, @vrules);
	$self->rrdgraph_engine($rrdfile, $gifpath . 'mail_engine-month.gif', $now, $start_time, $end_time, @vrules);
	$self->rrdgraph_type($rrdfile, $gifpath . 'mail_type-month.gif', $now, $start_time, $end_time, @vrules);
	$self->rrdgraph_dns($rrdfile, $gifpath . 'dns-month.gif', $now, $start_time, $end_time, @vrules);

	( $start_time,$end_time,@vrules ) = $self->get_year_param;
	$self->rrdgraph_size($rrdfile, $gifpath . 'mail_size-year.gif', $now, $start_time, $end_time, @vrules);
	$self->rrdgraph_traffic($rrdfile, $gifpath . 'mail_traffic-year.gif', $now, $start_time, $end_time, @vrules);
	$self->rrdgraph_engine($rrdfile, $gifpath . 'mail_engine-year.gif', $now, $start_time, $end_time, @vrules);
	$self->rrdgraph_type($rrdfile, $gifpath . 'mail_type-year.gif', $now, $start_time, $end_time, @vrules);
	$self->rrdgraph_dns($rrdfile, $gifpath . 'dns-year.gif', $now, $start_time, $end_time, @vrules);
=cut

}

sub get_day_param
{
	my $self = shift;

	my $end_time = time();                # setting current time
	my $start_time = $end_time - 129600; #  600 5-minute samples:    2   days and 2 hours
	my $day_start = time - time%86400 - 28800;
	my $yesterday_start = $day_start - 86400; # - 28800; #86400; # - 28800;
	my @vrules = ("VRULE:$day_start#AA0000:", "VRULE:$yesterday_start#AA0000:");

	return ($start_time,$end_time, @vrules);
}


sub get_week_param
{
	my $self = shift;

	my $end_time = time();                # setting current time
	my $start_time = $end_time - 907200; #  1.5 week #600 30-minute samples:  12.5 days
	my $day = strftime "%w", localtime; # %w     The  day of the week as a decimal, range 0 to 6, Sunday being 0.
	my $week_start = time - time%86400 + 86400 - ($day*86400) - 28800; # 28800; #86400; # - 28800;
	#my $week_start = time - time%86400 - 28800 - ($day*86400); # 28800; #86400; # - 28800;
	my $lastweek_start = $week_start - 604800; # - 28800; #86400; # - 28800;
	my @vrules = ("VRULE:$week_start#AA0000:", "VRULE:$lastweek_start#AA0000:");
	#%u(1-7) %w(0-6)

	return ($start_time,$end_time, @vrules);
}

sub get_month_param
{
	my $self = shift;

	my $end_time = time();                # setting current time
	my $start_time = $end_time - 3888000; #  1.5 month, #600 2-hour samples:     50   days
	my $day = strftime "%d", localtime; # The day of the month as a decimal number (range 01 to 31).
	my $month_start = time - time%86400 + 86400 - ($day*86400) -28800 ;
	my $lastmonth_start = $month_start - 2592000; # 30 * 86400
	my @vrules = ("VRULE:$month_start#AA0000:", "VRULE:$lastmonth_start#AA0000:");

	return ($start_time,$end_time, @vrules);
}

sub get_year_param
{
	my $self = shift;

	my $end_time = time();                # setting current time
	my $start_time = $end_time - 47304000; #  1.5 year #732 1-day samples:     732   days
	my $day = strftime "%j", localtime; # %j     The day of the year as a decimal number (range 001 to 366).
	my $year_start = time - time%86400 + 86400 - ($day*86400) - 28800 ;
	my $lastyear_start = $year_start - 31536000; # 365 * 86400
	my @vrules = ("VRULE:$year_start#AA0000:","VRULE:$lastyear_start#AA0000:");

	return ($start_time,$end_time, @vrules);
}


sub create_rrd
{
	my $self = shift;
	my $rrdpath = $self->{define}->{rrdpath};

	RRDs::create(
		"$rrdpath/mail_type.rrd"
            	,'DS:num_all:GAUGE:600:U:U'
            	,'DS:num_ok:GAUGE:600:U:U'
            	,'DS:num_in:GAUGE:600:U:U'
            	,'DS:num_out:GAUGE:600:U:U'

            	,'DS:num_virus:GAUGE:600:U:U'
            	,'DS:num_spam:GAUGE:600:U:U'
            	,'DS:num_content:GAUGE:600:U:U'
            	,'DS:num_overrun:GAUGE:600:U:U'
            	,'DS:num_archive:GAUGE:600:U:U'

            	,'RRA:MIN:0.5:1:600'
            	,'RRA:MIN:0.5:6:700'
            	,'RRA:MIN:0.5:24:775'
            	,'RRA:MIN:0.5:288:797'
            	,'RRA:AVERAGE:0.5:1:600'
            	,'RRA:AVERAGE:0.5:6:700'
            	,'RRA:AVERAGE:0.5:24:775'
            	,'RRA:AVERAGE:0.5:288:797'
            	,'RRA:MAX:0.5:1:600'
            	,'RRA:MAX:0.5:6:700'
            	,'RRA:MAX:0.5:24:775'
            	,'RRA:MAX:0.5:288:797'

	);
	my $ERR = RRDs::error;
	if ( $ERR ){
		die "RRDs mail_type.rrd err: $ERR\n";
	}


	RRDs::create(
		"$rrdpath/mail_traffic.rrd"
            	,'DS:size_all:GAUGE:600:U:U'
            	,'DS:size_in:GAUGE:600:U:U'
            	,'DS:size_out:GAUGE:600:U:U'
            	,'DS:size_in_ok:GAUGE:600:U:U'
            	,'DS:size_out_ok:GAUGE:600:U:U'

            	,'RRA:MIN:0.5:1:600'
            	,'RRA:MIN:0.5:6:700'
            	,'RRA:MIN:0.5:24:775'
            	,'RRA:MIN:0.5:288:797'
            	,'RRA:AVERAGE:0.5:1:600'
            	,'RRA:AVERAGE:0.5:6:700'
            	,'RRA:AVERAGE:0.5:24:775'
            	,'RRA:AVERAGE:0.5:288:797'
            	,'RRA:MAX:0.5:1:600'
            	,'RRA:MAX:0.5:6:700'
            	,'RRA:MAX:0.5:24:775'
            	,'RRA:MAX:0.5:288:797'

	);
	$ERR = RRDs::error;
	if ( $ERR ){
		die "RRDs mail_traffic.rrd err: $ERR\n";
	}

	RRDs::create(
		"$rrdpath/mail_size.rrd"
            	,'DS:num_all:GAUGE:600:U:U'
            	,'DS:size_4K:GAUGE:600:U:U'
            	,'DS:size_16K:GAUGE:600:U:U'
            	,'DS:size_32K:GAUGE:600:U:U'
            	,'DS:size_64K:GAUGE:600:U:U'
            	,'DS:size_128K:GAUGE:600:U:U'
            	,'DS:size_256K:GAUGE:600:U:U'
            	,'DS:size_512K:GAUGE:600:U:U'
            	,'DS:size_1M:GAUGE:600:U:U'
            	,'DS:size_5M:GAUGE:600:U:U'
            	,'DS:size_10M:GAUGE:600:U:U'
            	,'DS:size_gt10M:GAUGE:600:U:U'

            	,'RRA:MIN:0.5:1:600'
            	,'RRA:MIN:0.5:6:700'
            	,'RRA:MIN:0.5:24:775'
            	,'RRA:MIN:0.5:288:797'
            	,'RRA:AVERAGE:0.5:1:600'
            	,'RRA:AVERAGE:0.5:6:700'
            	,'RRA:AVERAGE:0.5:24:775'
            	,'RRA:AVERAGE:0.5:288:797'
            	,'RRA:MAX:0.5:1:600'
            	,'RRA:MAX:0.5:6:700'
            	,'RRA:MAX:0.5:24:775'
            	,'RRA:MAX:0.5:288:797'

	);
	$ERR = RRDs::error;
	if ( $ERR ){
		die "RRDs mail_size.rrd err: $ERR\n";
	}
				
	RRDs::create(
		"$rrdpath/mail_engine.rrd"
            	,'DS:time_all:GAUGE:600:U:U'
            	,'DS:time_virus:GAUGE:600:U:U'
            	,'DS:time_spam:GAUGE:600:U:U'
            	,'DS:time_content:GAUGE:600:U:U'
            	,'DS:time_overrun:GAUGE:600:U:U'
            	,'DS:time_archive:GAUGE:600:U:U'
            				
            	,'DS:cpu_all:GAUGE:600:U:U'
            	,'DS:cpu_virus:GAUGE:600:U:U'
            	,'DS:cpu_spam:GAUGE:600:U:U'
            	,'DS:cpu_content:GAUGE:600:U:U'
            	,'DS:cpu_overrun:GAUGE:600:U:U'
            	,'DS:cpu_archive:GAUGE:600:U:U'

            	,'RRA:MIN:0.5:1:600'
            	,'RRA:MIN:0.5:6:700'
            	,'RRA:MIN:0.5:24:775'
            	,'RRA:MIN:0.5:288:797'
            	,'RRA:AVERAGE:0.5:1:600'
            	,'RRA:AVERAGE:0.5:6:700'
            	,'RRA:AVERAGE:0.5:24:775'
            	,'RRA:AVERAGE:0.5:288:797'
            	,'RRA:MAX:0.5:1:600'
            	,'RRA:MAX:0.5:6:700'
            	,'RRA:MAX:0.5:24:775'
            	,'RRA:MAX:0.5:288:797'

	);
	$ERR = RRDs::error;
	if ( $ERR ){
		die "RRDs mail_engine.rrd err: $ERR\n";
	}
				
	RRDs::create(
		"$rrdpath/dns.rrd"
            	,'DS:dns_success:COUNTER:600:U:U'
            	,'DS:dns_referral:COUNTER:600:U:U'
            	,'DS:dns_nxrrset:COUNTER:600:U:U'
            	,'DS:dns_nxdomain:COUNTER:600:U:U'
            	,'DS:dns_recursion:COUNTER:600:U:U'
            	,'DS:dns_failure:COUNTER:600:U:U'
            				
            	,'RRA:MIN:0.5:1:600'
            	,'RRA:MIN:0.5:6:700'
            	,'RRA:MIN:0.5:24:775'
            	,'RRA:MIN:0.5:288:797'
            	,'RRA:AVERAGE:0.5:1:600'
            	,'RRA:AVERAGE:0.5:6:700'
            	,'RRA:AVERAGE:0.5:24:775'
            	,'RRA:AVERAGE:0.5:288:797'
            	,'RRA:MAX:0.5:1:600'
            	,'RRA:MAX:0.5:6:700'
            	,'RRA:MAX:0.5:24:775'
            	,'RRA:MAX:0.5:288:797'
	);

	$ERR = RRDs::error;
	if ( $ERR ){
		die "RRDs dns.rrd err: $ERR\n";
	}
}

sub rrdgraph_size
{
	my $self = shift;
	my ($rrdfile, $giffile, $now, $start_time, $end_time, @vrules) = @_;

	RRDs::graph ("$giffile", 
			"--title=Size Status",  
			"--vertical-label=Number per Minute", 
			"--start=$start_time",      
			"--end=$end_time",        
			#"--color=BACK#CCCCCC",   
			#"--color=CANVAS#CCFFFF",
			#"--color=SHADEB#9999CC",
			"--height=200",        
			"--width=500",        
			"--upper-limit=20",  
			"--lower-limit=0",   
			"--lazy",
			#"--rigid",          
			#"--base=1024",     
			"DEF:num_all_raw=$rrdfile:num_all:AVERAGE", 
			"CDEF:num_all_pm=num_all_raw,5,/",
			"CDEF:num_all_prev1=PREV(num_all_pm)",
			"CDEF:num_all_prev2=PREV(num_all_prev1)",
			"CDEF:num_all_prev3=PREV(num_all_prev2)",
			"CDEF:num_all=num_all_prev1,num_all_prev2,num_all_prev3,+,+,3,/",

			"DEF:size_4K_raw=$rrdfile:size_4K:AVERAGE", 
			"CDEF:size_4K_percent=100,size_4K_raw,*,num_all_raw,/,FLOOR",
			"CDEF:size_4K_pm=size_4K_raw,5,/",
			"CDEF:size_4K_prev1=PREV(size_4K_pm)",
			"CDEF:size_4K_prev2=PREV(size_4K_prev1)",
			"CDEF:size_4K_prev3=PREV(size_4K_prev2)",
			"CDEF:size_4K=size_4K_prev1,size_4K_prev2,size_4K_prev3,+,+,3,/",

			"DEF:size_16K_raw=$rrdfile:size_16K:AVERAGE", 
			"CDEF:size_16K_percent=100,size_16K_raw,*,num_all_raw,/,FLOOR",
			"CDEF:size_16K_pm=size_16K_raw,5,/",
			"CDEF:size_16K_prev1=PREV(size_16K_pm)",
			"CDEF:size_16K_prev2=PREV(size_16K_prev1)",
			"CDEF:size_16K_prev3=PREV(size_16K_prev2)",
			"CDEF:size_16K=size_4K,size_16K_prev1,size_16K_prev2,size_16K_prev3,+,+,3,/,+",

			"DEF:size_32K_raw=$rrdfile:size_32K:AVERAGE", 
			"CDEF:size_32K_percent=100,size_32K_raw,*,num_all_raw,/,FLOOR",
			"CDEF:size_32K_pm=size_32K_raw,5,/",
			"CDEF:size_32K_prev1=PREV(size_32K_pm)",
			"CDEF:size_32K_prev2=PREV(size_32K_prev1)",
			"CDEF:size_32K_prev3=PREV(size_32K_prev2)",
			"CDEF:size_32K=size_16K,size_32K_prev1,size_32K_prev2,size_32K_prev3,+,+,3,/,+",


			"DEF:size_64K_raw=$rrdfile:size_64K:AVERAGE", 
			"CDEF:size_64K_percent=100,size_64K_raw,*,num_all_raw,/,FLOOR",
			"CDEF:size_64K_pm=size_64K_raw,5,/",
			"CDEF:size_64K_prev1=PREV(size_64K_pm)",
			"CDEF:size_64K_prev2=PREV(size_64K_prev1)",
			"CDEF:size_64K_prev3=PREV(size_64K_prev2)",
			"CDEF:size_64K=size_32K,size_64K_prev1,size_64K_prev2,size_64K_prev3,+,+,3,/,+",

			"DEF:size_128K_raw=$rrdfile:size_128K:AVERAGE",
			"CDEF:size_128K_percent=100,size_128K_raw,*,num_all_raw,/,FLOOR",
			"CDEF:size_128K_pm=size_128K_raw,5,/",
			"CDEF:size_128K_prev1=PREV(size_128K_pm)",
			"CDEF:size_128K_prev2=PREV(size_128K_prev1)",
			"CDEF:size_128K_prev3=PREV(size_128K_prev2)",
			"CDEF:size_128K=size_64K,size_128K_prev1,size_128K_prev2,size_128K_prev3,+,+,3,/,+",

			"DEF:size_256K_raw=$rrdfile:size_256K:AVERAGE",
			"CDEF:size_256K_percent=100,size_256K_raw,*,num_all_raw,/,FLOOR",
			"CDEF:size_256K_pm=size_256K_raw,5,/",
			"CDEF:size_256K_prev1=PREV(size_256K_pm)",
			"CDEF:size_256K_prev2=PREV(size_256K_prev1)",
			"CDEF:size_256K_prev3=PREV(size_256K_prev2)",
			"CDEF:size_256K=size_128K,size_256K_prev1,size_256K_prev2,size_256K_prev3,+,+,3,/,+",

			"DEF:size_512K_raw=$rrdfile:size_512K:AVERAGE", 
			"CDEF:size_512K_percent=100,size_512K_raw,*,num_all_raw,/,FLOOR",
			"CDEF:size_512K_pm=size_512K_raw,5,/",
			"CDEF:size_512K_prev1=PREV(size_512K_pm)",
			"CDEF:size_512K_prev2=PREV(size_512K_prev1)",
			"CDEF:size_512K_prev3=PREV(size_512K_prev2)",
			"CDEF:size_512K=size_256K,size_512K_prev1,size_512K_prev2,size_512K_prev3,+,+,3,/,+",

			"DEF:size_1M_raw=$rrdfile:size_1M:AVERAGE", 
			"CDEF:size_1M_percent=100,size_1M_raw,*,num_all_raw,/,FLOOR",
			"CDEF:size_1M_pm=size_1M_raw,5,/",
			"CDEF:size_1M_prev1=PREV(size_1M_pm)",
			"CDEF:size_1M_prev2=PREV(size_1M_prev1)",
			"CDEF:size_1M_prev3=PREV(size_1M_prev2)",
			"CDEF:size_1M=size_512K,size_1M_prev1,size_1M_prev2,size_1M_prev3,+,+,3,/,+",

			"DEF:size_5M_raw=$rrdfile:size_5M:AVERAGE", 
			"CDEF:size_5M_percent=100,size_5M_raw,*,num_all_raw,/,FLOOR",
			"CDEF:size_5M_pm=size_5M_raw,5,/",
			"CDEF:size_5M_prev1=PREV(size_5M_pm)",
			"CDEF:size_5M_prev2=PREV(size_5M_prev1)",
			"CDEF:size_5M_prev3=PREV(size_5M_prev2)",
			"CDEF:size_5M=size_1M,size_5M_prev1,size_5M_prev2,size_5M_prev3,+,+,3,/,+",

			"DEF:size_10M_raw=$rrdfile:size_10M:AVERAGE", 
			"CDEF:size_10M_percent=100,size_10M_raw,*,num_all_raw,/,FLOOR",
			"CDEF:size_10M_pm=size_10M_raw,5,/",
			"CDEF:size_10M_prev1=PREV(size_10M_pm)",
			"CDEF:size_10M_prev2=PREV(size_10M_prev1)",
			"CDEF:size_10M_prev3=PREV(size_10M_prev2)",
			"CDEF:size_10M=size_5M,size_10M_prev1,size_10M_prev2,size_10M_prev3,+,+,3,/,+",

			"DEF:size_gt10M_raw=$rrdfile:size_gt10M:AVERAGE", 
			"CDEF:size_gt10M_percent=100,size_gt10M_raw,*,num_all_raw,/,FLOOR",
			"CDEF:size_gt10M_pm=size_gt10M_raw,5,/",
			"CDEF:size_gt10M_prev1=PREV(size_gt10M_pm)",
			"CDEF:size_gt10M_prev2=PREV(size_gt10M_prev1)",
			"CDEF:size_gt10M_prev3=PREV(size_gt10M_prev2)",
			"CDEF:size_gt10M=size_10M,size_gt10M_prev1,size_gt10M_prev2,size_gt10M_prev3,+,+,3,/,+",


			'COMMENT:List by Size --------Max----------Avg----------Min----------Cur---------Percent---------\n'

			,"LINE1:num_all#FFFFFF:Total    "
			,"GPRINT:num_all_pm:MAX:%11.0lf"
			,"GPRINT:num_all_pm:AVERAGE:%11.0lf"
			,"GPRINT:num_all_pm:MIN:%11.0lf"
			,"GPRINT:num_all_pm:LAST:%11.0lf"
			,'COMMENT:        100%\n'

			,"AREA:size_gt10M#FF0000:>10MB    "
			,"GPRINT:size_gt10M_pm:MAX:%11.0lf"
			,"GPRINT:size_gt10M_pm:AVERAGE:%11.0lf"
			,"GPRINT:size_gt10M_pm:MIN:%11.0lf"
			,"GPRINT:size_gt10M_pm:LAST:%11.0lf"
			,'GPRINT:size_gt10M_percent:LAST:%11lg%%\\n'

			,"AREA:size_10M#F40B03:5MB-10MB "
			,"GPRINT:size_10M_pm:MAX:%11.0lf"
			,"GPRINT:size_10M_pm:AVERAGE:%11.0lf"
			,"GPRINT:size_10M_pm:MIN:%11.0lf"
			,"GPRINT:size_10M_pm:LAST:%11.0lf"
			,'GPRINT:size_10M_percent:LAST:%11lg%%\\n'

			,"AREA:size_5M#D22D0A:1MB-5MB  "
			,"GPRINT:size_5M_pm:MAX:%11.0lf"
			,"GPRINT:size_5M_pm:AVERAGE:%11.0lf"
			,"GPRINT:size_5M_pm:MIN:%11.0lf"
			,"GPRINT:size_5M_pm:LAST:%11.0lf"
			,'GPRINT:size_5M_percent:LAST:%11lg%%\\n'


			,"AREA:size_1M#C03F0F:512KB-1MB"
			,"GPRINT:size_1M_pm:MAX:%11.0lf"
			,"GPRINT:size_1M_pm:AVERAGE:%11.0lf"
			,"GPRINT:size_1M_pm:MIN:%11.0lf"
			,"GPRINT:size_1M_pm:LAST:%11.0lf"
			,'GPRINT:size_1M_percent:LAST:%11lg%%\\n'

			,"AREA:size_512K#FFFC00:256-512KB"
			,"GPRINT:size_512K_pm:MAX:%11.0lf"
			,"GPRINT:size_512K_pm:AVERAGE:%11.0lf"
			,"GPRINT:size_512K_pm:MIN:%11.0lf"
			,"GPRINT:size_512K_pm:LAST:%11.0lf"
			,'GPRINT:size_512K_percent:LAST:%11lg%%\\n'

			,"AREA:size_256K#B8F706:128-256KB"
			,"GPRINT:size_256K_pm:MAX:%11.0lf"
			,"GPRINT:size_256K_pm:AVERAGE:%11.0lf"
			,"GPRINT:size_256K_pm:MIN:%11.0lf"
			,"GPRINT:size_256K_pm:LAST:%11.0lf"
			,'GPRINT:size_256K_percent:LAST:%11lg%%\\n'

			,"AREA:size_128K#92F408:64-128KB "
			,"GPRINT:size_128K_pm:MAX:%11.0lf"
			,"GPRINT:size_128K_pm:AVERAGE:%11.0lf"
			,"GPRINT:size_128K_pm:MIN:%11.0lf"
			,"GPRINT:size_128K_pm:LAST:%11.0lf"
			,'GPRINT:size_128K_percent:LAST:%11lg%%\\n'

			,"AREA:size_64K#65B72B:32-64KB  "
			,"GPRINT:size_64K_pm:MAX:%11.0lf"
			,"GPRINT:size_64K_pm:AVERAGE:%11.0lf"
			,"GPRINT:size_64K_pm:MIN:%11.0lf"
			,"GPRINT:size_64K_pm:LAST:%11.0lf"
			,'GPRINT:size_64K_percent:LAST:%11lg%%\\n'

			,"AREA:size_32K#46B92B:16-32KB  "
			,"GPRINT:size_32K_pm:MAX:%11.0lf"
			,"GPRINT:size_32K_pm:AVERAGE:%11.0lf"
			,"GPRINT:size_32K_pm:MIN:%11.0lf"
			,"GPRINT:size_32K_pm:LAST:%11.0lf"
			,'GPRINT:size_32K_percent:LAST:%11lg%%\\n'

			,"AREA:size_16K#2BD432:4-16KB   "
			,"GPRINT:size_16K_pm:MAX:%11.0lf"
			,"GPRINT:size_16K_pm:AVERAGE:%11.0lf"
			,"GPRINT:size_16K_pm:MIN:%11.0lf"
			,"GPRINT:size_16K_pm:LAST:%11.0lf"
			,'GPRINT:size_16K_percent:LAST:%11lg%%\\n'

			,"AREA:size_4K#00FF00:<4KB     "
			,"GPRINT:size_4K_pm:MAX:%11.0lf"
			,"GPRINT:size_4K_pm:AVERAGE:%11.0lf"
			,"GPRINT:size_4K_pm:MIN:%11.0lf"
			,"GPRINT:size_4K_pm:LAST:%11.0lf"
			,'GPRINT:size_4K_percent:LAST:%11lg%%\\n'



			,'COMMENT:\n'
			,@vrules
			,'HRULE:0#000000:Last Updated\: '
			,"COMMENT:$now\\n"


		);

}

sub rrdgraph_dns
{
	my $self = shift;
	my ($rrdfile, $giffile, $now, $start_time, $end_time, @vrules) = @_;
#print "rrdfile: $rrdfile, giffile: $giffile, now: $now, start_time: $start_time, end_time: $end_time, vrules: [" . join(',', @vrules) . "]\n" ;

	RRDs::graph ("$giffile", 
			"--title=DNS Status",  
			"--vertical-label=Query per Minute", 
			"--start=$start_time",      
			"--end=$end_time",        
			#"--color=BACK#CCCCCC",   
			#"--color=CANVAS#CCFFFF",
			#"--color=SHADEB#9999CC",
			"--height=200",        
			"--width=500",        
			"--upper-limit=20",  
			"--lower-limit=-10",   
			"--lazy",
			#"--rigid",          
			#"--base=1024",     

#			($ds->{success},$ds->{referral},$ds->{nxrrset},$ds->{nxdomain},$ds->{recursion},$ds->{failure});


			"DEF:dns_success_raw=$rrdfile:dns_success:AVERAGE", 
			"CDEF:max_dns_query=30000,dns_success_raw,UN,0,dns_success_raw,dns_success_raw,-,IF,+",

			"CDEF:dns_success_raw_ok=dns_success_raw,max_dns_query,GT,UNKN,dns_success_raw,IF",
			"CDEF:dns_success_pm=dns_success_raw_ok,60,*",
			"CDEF:dns_success_prev1=PREV(dns_success_pm)",
			"CDEF:dns_success_prev2=PREV(dns_success_prev1)",
			"CDEF:dns_success_prev3=PREV(dns_success_prev2)",
			"CDEF:dns_success=dns_success_prev1,dns_success_prev2,dns_success_prev3,+,+,3,/",

			"DEF:dns_recursion_raw=$rrdfile:dns_recursion:AVERAGE", 
			"CDEF:dns_recursion_raw_ok=dns_recursion_raw,max_dns_query,GT,UNKN,dns_recursion_raw,IF",
			"CDEF:dns_recursion_pm=dns_recursion_raw_ok,60,*",
			"CDEF:dns_recursion_prev1=PREV(dns_recursion_pm)",
			"CDEF:dns_recursion_prev2=PREV(dns_recursion_prev1)",
			"CDEF:dns_recursion_prev3=PREV(dns_recursion_prev2)",
			"CDEF:dns_recursion=dns_success,dns_recursion_prev1,dns_recursion_prev2,dns_recursion_prev3,+,+,3,/,+",

			"DEF:dns_referral_raw=$rrdfile:dns_referral:AVERAGE", 
			"CDEF:dns_referral_raw_ok=dns_referral_raw,max_dns_query,GT,UNKN,dns_referral_raw,IF",
			"CDEF:dns_referral_pm=dns_referral_raw_ok,60,*",
			"CDEF:dns_referral_prev1=PREV(dns_referral_pm)",
			"CDEF:dns_referral_prev2=PREV(dns_referral_prev1)",
			"CDEF:dns_referral_prev3=PREV(dns_referral_prev2)",
			"CDEF:dns_referral=dns_referral_prev1,dns_referral_prev2,dns_referral_prev3,+,+,3,/",

			"DEF:dns_nxrrset_raw=$rrdfile:dns_nxrrset:AVERAGE", 
			"CDEF:dns_nxrrset_raw_ok=dns_nxrrset_raw,max_dns_query,GT,UNKN,dns_nxrrset_raw,IF",
			"CDEF:dns_nxrrset_pm=dns_nxrrset_raw_ok,60,*",
			"CDEF:dns_nxrrset_prev1=PREV(dns_nxrrset_pm)",
			"CDEF:dns_nxrrset_prev2=PREV(dns_nxrrset_prev1)",
			"CDEF:dns_nxrrset_prev3=PREV(dns_nxrrset_prev2)",
			"CDEF:dns_nxrrset=0,dns_nxrrset_prev1,dns_nxrrset_prev2,dns_nxrrset_prev3,+,+,3,/,-",

			"DEF:dns_nxdomain_raw=$rrdfile:dns_nxdomain:AVERAGE", 
			"CDEF:dns_nxdomain_raw_ok=dns_nxdomain_raw,max_dns_query,GT,UNKN,dns_nxdomain_raw,IF",
			"CDEF:dns_nxdomain_pm=dns_nxdomain_raw_ok,60,*",
			"CDEF:dns_nxdomain_prev1=PREV(dns_nxdomain_pm)",
			"CDEF:dns_nxdomain_prev2=PREV(dns_nxdomain_prev1)",
			"CDEF:dns_nxdomain_prev3=PREV(dns_nxdomain_prev2)",
			"CDEF:dns_nxdomain=dns_nxrrset,dns_nxdomain_prev1,dns_nxdomain_prev2,dns_nxdomain_prev3,+,+,3,/,-",

			"DEF:dns_failure_raw=$rrdfile:dns_failure:AVERAGE", 
			"CDEF:dns_failure_raw_ok=dns_failure_raw,max_dns_query,GT,UNKN,dns_failure_raw,IF",
			"CDEF:dns_failure_pm=dns_failure_raw_ok,60,*",
			"CDEF:dns_failure_prev1=PREV(dns_failure_pm)",
			"CDEF:dns_failure_prev2=PREV(dns_failure_prev1)",
			"CDEF:dns_failure_prev3=PREV(dns_failure_prev2)",
			"CDEF:dns_failure=dns_nxdomain,dns_failure_prev1,dns_failure_prev2,dns_failure_prev3,+,+,3,/,-",


			"CDEF:dns_all_raw=dns_success_raw_ok,dns_referral_raw_ok,dns_nxrrset_raw_ok,dns_nxdomain_raw_ok,dns_recursion_raw_ok,dns_failure_raw_ok,+,+,+,+,+", 
			"CDEF:dns_all_pm=dns_all_raw,60,*",
			"CDEF:dns_all_prev1=PREV(dns_all_pm)",
			"CDEF:dns_all_prev2=PREV(dns_all_prev1)",
			"CDEF:dns_all_prev3=PREV(dns_all_prev2)",
			"CDEF:dns_all=dns_all_prev1,dns_all_prev2,dns_all_prev3,+,+,3,/",

			"CDEF:dns_success_percent=100,dns_success_raw,*,dns_all_raw,/,FLOOR",
			"CDEF:dns_referral_percent=100,dns_referral_raw,*,dns_all_raw,/,FLOOR",
			"CDEF:dns_nxrrset_percent=100,dns_nxrrset_raw,*,dns_all_raw,/,FLOOR",
			"CDEF:dns_nxdomain_percent=100,dns_nxdomain_raw,*,dns_all_raw,/,FLOOR",
			"CDEF:dns_recursion_percent=100,dns_recursion_raw,*,dns_all_raw,/,FLOOR",
			"CDEF:dns_failure_percent=100,dns_failure_raw,*,dns_all_raw,/,FLOOR",
			"CDEF:dns_err_percent=100,dns_failure_raw,dns_nxrrset_raw,dns_nxdomain_raw,+,+,*,dns_all_raw,/,FLOOR",


			'COMMENT:Succ DNS Query(qpm) -Max----------Avg----------Min----------Cur---------Percent---------\n'

			,"LINE2:dns_all_raw#FFFFFF:Total    "
			,"GPRINT:dns_all_pm:MAX:%11.0lf"
			,"GPRINT:dns_all_pm:AVERAGE:%11.0lf"
			,"GPRINT:dns_all_pm:MIN:%11.0lf"
			,"GPRINT:dns_all_pm:LAST:%11.0lf"
			,'COMMENT:        100%\n'

			,'AREA:dns_recursion#00FFFF:Above 1  '
			,"GPRINT:dns_recursion_pm:MAX:%11.0lf"
			,"GPRINT:dns_recursion_pm:AVERAGE:%11.0lf"
			,"GPRINT:dns_recursion_pm:MIN:%11.0lf"
			,"GPRINT:dns_recursion_pm:LAST:%11.0lf"
			,'GPRINT:dns_recursion_percent:LAST:%11lg%%\\n'

			,'AREA:dns_success#00FF00:1 Query  '
			,"GPRINT:dns_success_pm:MAX:%11.0lf"
			,"GPRINT:dns_success_pm:AVERAGE:%11.0lf"
			,"GPRINT:dns_success_pm:MIN:%11.0lf"
			,"GPRINT:dns_success_pm:LAST:%11.0lf"
			,'GPRINT:dns_success_percent:LAST:%11lg%%\n'


			,'COMMENT:\n'
			,'COMMENT:Failed DNS Query                                               '
			,'GPRINT:dns_err_percent:LAST:%11lg%%\n'

			,'AREA:dns_failure#FF0000:Failure  '
			,"GPRINT:dns_failure_pm:MAX:%11.0lf"
			,"GPRINT:dns_failure_pm:AVERAGE:%11.0lf"
			,"GPRINT:dns_failure_pm:MIN:%11.0lf"
			,"GPRINT:dns_failure_pm:LAST:%11.0lf"
			,'GPRINT:dns_failure_percent:LAST:%11lg%%\\n'


			,'AREA:dns_nxdomain#FF8800:No Domain'
			,"GPRINT:dns_nxdomain_pm:MAX:%11.0lf"
			,"GPRINT:dns_nxdomain_pm:AVERAGE:%11.0lf"
			,"GPRINT:dns_nxdomain_pm:MIN:%11.0lf"
			,"GPRINT:dns_nxdomain_pm:LAST:%11.0lf"
			,'GPRINT:dns_nxdomain_percent:LAST:%11lg%%\\n'

			,'AREA:dns_nxrrset#FFFF00:No Record'
			,"GPRINT:dns_nxrrset_pm:MAX:%11.0lf"
			,"GPRINT:dns_nxrrset_pm:AVERAGE:%11.0lf"
			,"GPRINT:dns_nxrrset_pm:MIN:%11.0lf"
			,"GPRINT:dns_nxrrset_pm:LAST:%11.0lf"
			,'GPRINT:dns_nxrrset_percent:LAST:%11lg%%\\n'

			,'COMMENT:\n'

			,@vrules
			,'HRULE:0#000000:Last Updated\: '
			,"COMMENT:$now\\n"


		);

}



sub rrdgraph_traffic
{
	my $self = shift;
	my ($rrdfile, $giffile, $now, $start_time, $end_time, @vrules) = @_;

	RRDs::graph ("$giffile", 
			"--title=Traffic Status",  
			"--vertical-label=Bits per Second", 
			"--start=$start_time",      
			"--end=$end_time",        
			#"--color=BACK#CCCCCC",   
			#"--color=CANVAS#CCFFFF",
			#"--color=SHADEB#9999CC",
			"--height=200",        
			"--width=500",        
			"--upper-limit=1024",  
			"--lower-limit=-1024",   
			"--lazy",
			#"--rigid",          
			"--base=1024",     

			"DEF:size_all_raw=$rrdfile:size_all:AVERAGE", 
			"CDEF:size_all_bps=size_all_raw,5,/,60,/,8,*",
			"CDEF:size_all_prev1=PREV(size_all_bps)",
			"CDEF:size_all_prev2=PREV(size_all_prev1)",
			"CDEF:size_all_prev3=PREV(size_all_prev2)",
			"CDEF:size_all=size_all_prev1,size_all_prev2,size_all_prev3,+,+,3,/",

			"DEF:size_out_raw=$rrdfile:size_out:AVERAGE", 
			"CDEF:size_out_percent=100,size_out_raw,*,size_all_raw,/,FLOOR",
			"CDEF:size_out_bps=size_out_raw,5,/,60,/,8,*",
			"CDEF:size_out_prev1=PREV(size_out_bps)",
			"CDEF:size_out_prev2=PREV(size_out_prev1)",
			"CDEF:size_out_prev3=PREV(size_out_prev2)",
			"CDEF:size_out=size_out_prev1,size_out_prev2,size_out_prev3,+,+,3,/",

			"DEF:size_in_raw=$rrdfile:size_in:AVERAGE", 
			"CDEF:size_in_percent=100,size_in_raw,*,size_all_raw,/,FLOOR",
			"CDEF:size_in_bps=size_in_raw,5,/,60,/,8,*",
			"CDEF:size_in_prev1=PREV(size_in_bps)",
			"CDEF:size_in_prev2=PREV(size_in_prev1)",
			"CDEF:size_in_prev3=PREV(size_in_prev2)",
			"CDEF:size_in=size_out,size_in_prev1,size_in_prev2,size_in_prev3,+,+,3,/,+",

			"DEF:size_out_ok_raw=$rrdfile:size_out_ok:AVERAGE", 
			"CDEF:size_out_ok_bps=size_out_ok_raw,5,/,60,/,8,*",
			"CDEF:size_out_ok_prev1=PREV(size_out_ok_bps)",
			"CDEF:size_out_ok_prev2=PREV(size_out_ok_prev1)",
			"CDEF:size_out_ok_prev3=PREV(size_out_ok_prev2)",
			"CDEF:size_out_ok=0,size_out_ok_prev1,size_out_ok_prev2,size_out_ok_prev3,+,+,3,/,-",

			"DEF:size_in_ok_raw=$rrdfile:size_in_ok:AVERAGE", 
			"CDEF:size_in_ok_bps=size_in_ok_raw,5,/,60,/,8,*",
			"CDEF:size_in_ok_prev1=PREV(size_in_ok_bps)",
			"CDEF:size_in_ok_prev2=PREV(size_in_ok_prev1)",
			"CDEF:size_in_ok_prev3=PREV(size_in_ok_prev2)",
			"CDEF:size_in_ok=size_out_ok,size_in_ok_prev1,size_in_ok_prev2,size_in_ok_prev3,+,+,3,/,-",

			"CDEF:size_all_ok_raw=size_in_ok_raw,size_out_ok_raw,+", 
			"CDEF:size_all_ok_bps=size_all_ok_raw,5,/,60,/,8,*",
			"CDEF:size_all_ok_prev1=PREV(size_all_ok_bps)",
			"CDEF:size_all_ok_prev2=PREV(size_all_ok_prev1)",
			"CDEF:size_all_ok_prev3=PREV(size_all_ok_prev2)",
			"CDEF:size_all_ok=0,size_all_ok_prev1,size_all_ok_prev2,size_all_ok_prev3,+,+,3,/,-",

			"CDEF:size_in_ok_percent=100,size_in_ok_raw,*,size_all_ok_raw,/,FLOOR",
			"CDEF:size_out_ok_percent=100,size_out_ok_raw,*,size_all_ok_raw,/,FLOOR",
			"CDEF:size_all_ok_percent=100,size_all_ok_raw,*,size_all_raw,/,FLOOR",


			'COMMENT:All Traffic(bps) ----Max----------Avg----------Min----------Cur---------Percent---------\n'

			,"LINE2:size_all#FFFFFF:Total    "
			,"GPRINT:size_all_bps:MAX:%11.0lf"
			,"GPRINT:size_all_bps:AVERAGE:%11.0lf"
			,"GPRINT:size_all_bps:MIN:%11.0lf"
			,"GPRINT:size_all_bps:LAST:%11.0lf"
			,'COMMENT:        100%\n'

			,'AREA:size_in#00FFFF:In       '
			,"GPRINT:size_in_bps:MAX:%11.0lf"
			,"GPRINT:size_in_bps:AVERAGE:%11.0lf"
			,"GPRINT:size_in_bps:MIN:%11.0lf"
			,"GPRINT:size_in_bps:LAST:%11.0lf"
			,'GPRINT:size_in_percent:LAST:%11lg%%\\n'

			,'AREA:size_out#FF00FF:Out      '
			,"GPRINT:size_out_bps:MAX:%11.0lf"
			,"GPRINT:size_out_bps:AVERAGE:%11.0lf"
			,"GPRINT:size_out_bps:MIN:%11.0lf"
			,"GPRINT:size_out_bps:LAST:%11.0lf"
			,'GPRINT:size_out_percent:LAST:%11lg%%\\n'


			,'COMMENT:\n'
			,'COMMENT:Normal Traffic\n'

			,'LINE2:size_all_ok#FFFFFF:Total    '
			,"GPRINT:size_all_ok_bps:MAX:%11.0lf"
			,"GPRINT:size_all_ok_bps:AVERAGE:%11.0lf"
			,"GPRINT:size_all_ok_bps:MIN:%11.0lf"
			,"GPRINT:size_all_ok_bps:LAST:%11.0lf"
			,'GPRINT:size_all_ok_percent:LAST:%11lg%%\\n'


			,'AREA:size_in_ok#00FF00:In       '
			,"GPRINT:size_in_ok_bps:MAX:%11.0lf"
			,"GPRINT:size_in_ok_bps:AVERAGE:%11.0lf"
			,"GPRINT:size_in_ok_bps:MIN:%11.0lf"
			,"GPRINT:size_in_ok_bps:LAST:%11.0lf"
			,'GPRINT:size_in_ok_percent:LAST:%11lg%%\\n'

			,'AREA:size_out_ok#0000FF:Out      '
			,"GPRINT:size_out_ok_bps:MAX:%11.0lf"
			,"GPRINT:size_out_ok_bps:AVERAGE:%11.0lf"
			,"GPRINT:size_out_ok_bps:MIN:%11.0lf"
			,"GPRINT:size_out_ok_bps:LAST:%11.0lf"
			,'GPRINT:size_out_ok_percent:LAST:%11lg%%\\n'


			,'COMMENT:\n'
			,@vrules
			,'HRULE:0#000000:Last Updated\: '
			,"COMMENT:$now\\n"


		);

}

sub rrdgraph_engine
{
	my $self = shift;
	my ($rrdfile, $giffile, $now, $start_time, $end_time, @vrules) = @_;

	RRDs::graph ("$giffile", 
			"--title=Engine Status",  
			"--vertical-label=Time per Mail(ms)", 
			"--start=$start_time",      
			"--end=$end_time",        
			#"--color=BACK#CCCCCC",   
			#"--color=CANVAS#CCFFFF",
			#"--color=SHADEB#9999CC",
			"--height=200",        
			"--width=500",
			"--interlaced",
			"--lazy",
			#'--imginfo "<IMG SRC="%s" WIDTH="%lu" HEIGHT="%lu" ALT="Demo">"',
			"--upper-limit=20",  
			"--lower-limit=-10",   
			#"--rigid",          
			#"--base=1024",     
			"DEF:time_all_raw=$rrdfile:time_all:AVERAGE", 
			"CDEF:time_all_prev1=PREV(time_all_raw)",
			"CDEF:time_all_prev2=PREV(time_all_prev1)",
			"CDEF:time_all_prev3=PREV(time_all_prev2)",
			"CDEF:time_all=time_all_prev1,time_all_prev2,time_all_prev3,+,+,3,/",

			"DEF:time_virus_raw=$rrdfile:time_virus:AVERAGE",
			"CDEF:time_virus_prev1=PREV(time_virus_raw)",
			"CDEF:time_virus_prev2=PREV(time_virus_prev1)",
			"CDEF:time_virus_prev3=PREV(time_virus_prev2)",
			"CDEF:time_virus=time_virus_prev1,time_virus_prev2,time_virus_prev3,+,+,3,/",

			"DEF:time_content_raw=$rrdfile:time_content:AVERAGE", 
			"CDEF:time_content_prev1=PREV(time_content_raw)",
			"CDEF:time_content_prev2=PREV(time_content_prev1)",
			"CDEF:time_content_prev3=PREV(time_content_prev2)",
			"CDEF:time_content=time_virus,time_content_prev1,time_content_prev2,time_content_prev3,+,+,3,/,+",

			"DEF:time_overrun_raw=$rrdfile:time_overrun:AVERAGE", 
			"CDEF:time_overrun_prev1=PREV(time_overrun_raw)",
			"CDEF:time_overrun_prev2=PREV(time_overrun_prev1)",
			"CDEF:time_overrun_prev3=PREV(time_overrun_prev2)",
			"CDEF:time_overrun=time_content,time_overrun_prev1,time_overrun_prev2,time_overrun_prev3,+,+,3,/,+",

			"DEF:time_archive_raw=$rrdfile:time_archive:AVERAGE", 
			"CDEF:time_archive_prev1=PREV(time_archive_raw)",
			"CDEF:time_archive_prev2=PREV(time_archive_prev1)",
			"CDEF:time_archive_prev3=PREV(time_archive_prev2)",
			"CDEF:time_archive=time_overrun,time_archive_prev1,time_archive_prev2,time_archive_prev3,+,+,3,/,+",

			"DEF:time_spam_raw=$rrdfile:time_spam:AVERAGE", 
			"CDEF:time_spam_prev1=PREV(time_spam_raw)",
			"CDEF:time_spam_prev2=PREV(time_spam_prev1)",
			"CDEF:time_spam_prev3=PREV(time_spam_prev2)",
			"CDEF:time_spam=time_archive,time_spam_prev1,time_spam_prev2,time_spam_prev3,+,+,3,/,+",


			"DEF:cpu_all_raw=$rrdfile:cpu_all:AVERAGE", 
			"CDEF:cpu_all_prev1=PREV(cpu_all_raw)",
			"CDEF:cpu_all_prev2=PREV(cpu_all_prev1)",
			"CDEF:cpu_all_prev3=PREV(cpu_all_prev2)",
			"CDEF:cpu_all=0,cpu_all_prev1,cpu_all_prev2,cpu_all_prev3,+,+,3,/,-",

			"DEF:cpu_virus_raw=$rrdfile:cpu_virus:AVERAGE",
			"CDEF:cpu_virus_prev1=PREV(cpu_virus_raw)",
			"CDEF:cpu_virus_prev2=PREV(cpu_virus_prev1)",
			"CDEF:cpu_virus_prev3=PREV(cpu_virus_prev2)",
			"CDEF:cpu_virus=0,cpu_virus_prev1,cpu_virus_prev2,cpu_virus_prev3,+,+,3,/,-",

			"DEF:cpu_content_raw=$rrdfile:cpu_content:AVERAGE", 
			"CDEF:cpu_content_prev1=PREV(cpu_content_raw)",
			"CDEF:cpu_content_prev2=PREV(cpu_content_prev1)",
			"CDEF:cpu_content_prev3=PREV(cpu_content_prev2)",
			"CDEF:cpu_content=cpu_virus,0,cpu_content_prev1,cpu_content_prev2,cpu_content_prev3,+,+,3,/,-,+",

			"DEF:cpu_overrun_raw=$rrdfile:cpu_overrun:AVERAGE", 
			"CDEF:cpu_overrun_prev1=PREV(cpu_overrun_raw)",
			"CDEF:cpu_overrun_prev2=PREV(cpu_overrun_prev1)",
			"CDEF:cpu_overrun_prev3=PREV(cpu_overrun_prev2)",
			"CDEF:cpu_overrun=cpu_content,0,cpu_overrun_prev1,cpu_overrun_prev2,cpu_overrun_prev3,+,+,3,/,-,+",

			"DEF:cpu_archive_raw=$rrdfile:cpu_archive:AVERAGE", 
			"CDEF:cpu_archive_prev1=PREV(cpu_archive_raw)",
			"CDEF:cpu_archive_prev2=PREV(cpu_archive_prev1)",
			"CDEF:cpu_archive_prev3=PREV(cpu_archive_prev2)",
			"CDEF:cpu_archive=cpu_overrun,0,cpu_archive_prev1,cpu_archive_prev2,cpu_archive_prev3,+,+,3,/,-,+",

			"DEF:cpu_spam_raw=$rrdfile:cpu_spam:AVERAGE", 
			"CDEF:cpu_spam_prev1=PREV(cpu_spam_raw)",
			"CDEF:cpu_spam_prev2=PREV(cpu_spam_prev1)",
			"CDEF:cpu_spam_prev3=PREV(cpu_spam_prev2)",
			"CDEF:cpu_spam=cpu_archive,0,cpu_spam_prev1,cpu_spam_prev2,cpu_spam_prev3,+,+,3,/,-,+",



			@vrules,
			#"VRULE:$today_start#AA0000:"
			#,"VRULE:$yesterday_start#AA0000:"

			,"COMMENT:Real Time(ms) ---------Max----------Avg----------Min----------Cur----------\\n"
			,"AREA:time_all#00FF00:All Engines"
			,"GPRINT:time_all_raw:MAX:%11.0lf"
			,"GPRINT:time_all_raw:AVERAGE:%11.0lf"
			,"GPRINT:time_all_raw:MIN:%11.0lf"
			,"GPRINT:time_all_raw:LAST:%11.0lf\\n"

			,"AREA:time_spam#FFFF00:AntiSPAM   "
			,"GPRINT:time_spam_raw:MAX:%11.0lf"
			,"GPRINT:time_spam_raw:AVERAGE:%11.0lf"
			,"GPRINT:time_spam_raw:MIN:%11.0lf"
			,"GPRINT:time_spam_raw:LAST:%11.0lf\\n"


			,"AREA:time_archive#00FFFF:Audit      "
			,"GPRINT:time_archive_raw:MAX:%11.0lf"
			,"GPRINT:time_archive_raw:AVERAGE:%11.0lf"
			,"GPRINT:time_archive_raw:MIN:%11.0lf"
			,"GPRINT:time_archive_raw:LAST:%11.0lf\\n"

			,"AREA:time_overrun#0000FF:Dynamic    "
			,"GPRINT:time_overrun_raw:MAX:%11.0lf"
			,"GPRINT:time_overrun_raw:AVERAGE:%11.0lf"
			,"GPRINT:time_overrun_raw:MIN:%11.0lf"
			,"GPRINT:time_overrun_raw:LAST:%11.0lf\\n"

			,"AREA:time_content#FF00FF:Content    "
			,"GPRINT:time_content_raw:MAX:%11.0lf"
			,"GPRINT:time_content_raw:AVERAGE:%11.0lf"
			,"GPRINT:time_content_raw:MIN:%11.0lf"
			,"GPRINT:time_content_raw:LAST:%11.0lf\\n"

			,"AREA:time_virus#FF0000:AntiVirus  "
			,"GPRINT:time_virus_raw:MAX:%11.0lf"
			,"GPRINT:time_virus_raw:AVERAGE:%11.0lf"
			,"GPRINT:time_virus_raw:MIN:%11.0lf"
			,"GPRINT:time_virus_raw:LAST:%11.0lf\\n"


			,'COMMENT:\n'
			,"COMMENT:CPU Time(ms) ----------Max----------Avg----------Min----------Cur----------\\n"
			,"AREA:cpu_all#00FF00:All Engines"
			,"GPRINT:cpu_all_raw:MAX:%11.0lf"
			,"GPRINT:cpu_all_raw:AVERAGE:%11.0lf"
			,"GPRINT:cpu_all_raw:MIN:%11.0lf"
			,"GPRINT:cpu_all_raw:LAST:%11.0lf\\n"

			,"AREA:cpu_spam#FFFF00:AntiSPAM   "
			,"GPRINT:cpu_spam_raw:MAX:%11.0lf"
			,"GPRINT:cpu_spam_raw:AVERAGE:%11.0lf"
			,"GPRINT:cpu_spam_raw:MIN:%11.0lf"
			,"GPRINT:cpu_spam_raw:LAST:%11.0lf\\n"


			,"AREA:cpu_archive#00FFFF:Audit      "
			,"GPRINT:cpu_archive_raw:MAX:%11.0lf"
			,"GPRINT:cpu_archive_raw:AVERAGE:%11.0lf"
			,"GPRINT:cpu_archive_raw:MIN:%11.0lf"
			,"GPRINT:cpu_archive_raw:LAST:%11.0lf\\n"

			,"AREA:cpu_overrun#0000FF:Dynamic    "
			,"GPRINT:cpu_overrun_raw:MAX:%11.0lf"
			,"GPRINT:cpu_overrun_raw:AVERAGE:%11.0lf"
			,"GPRINT:cpu_overrun_raw:MIN:%11.0lf"
			,"GPRINT:cpu_overrun_raw:LAST:%11.0lf\\n"


			,"AREA:cpu_content#FF00FF:Content    "
			,"GPRINT:cpu_content_raw:MAX:%11.0lf"
			,"GPRINT:cpu_content_raw:AVERAGE:%11.0lf"
			,"GPRINT:cpu_content_raw:MIN:%11.0lf"
			,"GPRINT:cpu_content_raw:LAST:%11.0lf\\n"


			,"AREA:cpu_virus#FF0000:AntiVirus  "
			,"GPRINT:cpu_virus_raw:MAX:%11.0lf"
			,"GPRINT:cpu_virus_raw:AVERAGE:%11.0lf"
			,"GPRINT:cpu_virus_raw:MIN:%11.0lf"
			,"GPRINT:cpu_virus_raw:LAST:%11.0lf\\n"


			,'COMMENT:\n'
			,"HRULE:0#000000:Last Updated: "
			,"COMMENT:$now\\n"

			);
}

sub rrdgraph_type
{
	my $self = shift;

	my ($rrdfile, $giffile, $now, $start_time, $end_time, @vrules) = @_;

	RRDs::graph ("$giffile",
			"--title=Send/Receive Status",  
			"--vertical-label=Number per Minute", 
			"--start=$start_time",      
			"--end=$end_time",        
			@vrules,
			#"--color=BACK#CCCCCC",   
			#"--color=CANVAS#CCFFFF",
			#"--color=SHADEB#9999CC",
			"--height=200",        
			"--width=500",        
			"--upper-limit=20",  
			"--lower-limit=-10",   
			"--lazy",
			#"--rigid",          
			#"--base=1024",     
			"DEF:num_all_raw=$rrdfile:num_all:AVERAGE", 
			"CDEF:num_all_pm=num_all_raw,5,/",
			"CDEF:num_all_prev1=PREV(num_all_pm)",
			"CDEF:num_all_prev2=PREV(num_all_prev1)",
			"CDEF:num_all_prev3=PREV(num_all_prev2)",
			"CDEF:num_all=num_all_prev1,num_all_prev2,num_all_prev3,+,+,3,/",


			"DEF:num_ok_raw=$rrdfile:num_ok:AVERAGE", 
			"CDEF:num_ok_percent=100,num_ok_raw,*,num_all_raw,/,FLOOR",
			"CDEF:num_ok_pm=num_ok_raw,5,/",
			"CDEF:num_ok_prev1=PREV(num_ok_pm)",
			"CDEF:num_ok_prev2=PREV(num_ok_prev1)",
			"CDEF:num_ok_prev3=PREV(num_ok_prev2)",
			"CDEF:num_ok=0,num_ok_prev1,num_ok_prev2,num_ok_prev3,+,+,3,/,-",


			"DEF:num_out_raw=$rrdfile:num_out:AVERAGE",
			"CDEF:num_out_percent=100,num_out_raw,*,num_all_raw,/,FLOOR",
			"CDEF:num_out_pm=num_out_raw,5,/",
			"CDEF:num_out_prev1=PREV(num_out_pm)",
			"CDEF:num_out_prev2=PREV(num_out_prev1)",
			"CDEF:num_out_prev3=PREV(num_out_prev2)",
			"CDEF:num_out=num_out_prev1,num_out_prev2,num_out_prev3,+,+,3,/",

			"DEF:num_in_raw=$rrdfile:num_in:AVERAGE", 
			"CDEF:num_in_percent=100,num_in_raw,*,num_all_raw,/,FLOOR",
			"CDEF:num_in_pm=num_in_raw,5,/",
			"CDEF:num_in_prev1=PREV(num_in_pm)",
			"CDEF:num_in_prev2=PREV(num_in_prev1)",
			"CDEF:num_in_prev3=PREV(num_in_prev2)",
			"CDEF:num_in=num_in_prev1,num_in_prev2,num_in_prev3,+,+,3,/",

			"DEF:num_virus_raw=$rrdfile:num_virus:AVERAGE", 
			"CDEF:num_virus_percent=100,num_virus_raw,*,num_all_raw,/,FLOOR",
			"CDEF:num_virus_pm=num_virus_raw,5,/",
			"CDEF:num_virus_prev1=PREV(num_virus_pm)",
			"CDEF:num_virus_prev2=PREV(num_virus_prev1)",
			"CDEF:num_virus_prev3=PREV(num_virus_prev2)",
			"CDEF:num_virus=num_virus_prev1,num_virus_prev2,num_virus_prev3,+,+,3,/",

			"DEF:num_spam_raw=$rrdfile:num_spam:AVERAGE", 
			"CDEF:num_spam_percent=100,num_spam_raw,*,num_all_raw,/,FLOOR",
			"CDEF:num_spam_pm=num_spam_raw,5,/",
			"CDEF:num_spam_prev1=PREV(num_spam_pm)",
			"CDEF:num_spam_prev2=PREV(num_spam_prev1)",
			"CDEF:num_spam_prev3=PREV(num_spam_prev2)",
			"CDEF:num_spam=num_spam_prev1,num_spam_prev2,num_spam_prev3,+,+,3,/",

			"DEF:num_content_raw=$rrdfile:num_content:AVERAGE", 
			"CDEF:num_content_percent=100,num_content_raw,*,num_all_raw,/,FLOOR",
			"CDEF:num_content_pm=num_content_raw,5,/",
			"CDEF:num_content_prev1=PREV(num_content_pm)",
			"CDEF:num_content_prev2=PREV(num_content_prev1)",
			"CDEF:num_content_prev3=PREV(num_content_prev2)",
			"CDEF:num_content=num_content_prev1,num_content_prev2,num_content_prev3,+,+,3,/",

			"DEF:num_overrun_raw=$rrdfile:num_overrun:AVERAGE", 
			"CDEF:num_overrun_percent=100,num_overrun_raw,*,num_all_raw,/,FLOOR",
			"CDEF:num_overrun_pm=num_overrun_raw,5,/",
			"CDEF:num_overrun_prev1=PREV(num_overrun_pm)",
			"CDEF:num_overrun_prev2=PREV(num_overrun_prev1)",
			"CDEF:num_overrun_prev3=PREV(num_overrun_prev2)",
			"CDEF:num_overrun=num_overrun_prev1,num_overrun_prev2,num_overrun_prev3,+,+,3,/",

			"DEF:num_archive_raw=$rrdfile:num_archive:AVERAGE", 
			"CDEF:num_archive_percent=100,num_archive_raw,*,num_all_raw,/,FLOOR",
			"CDEF:num_archive_pm=num_archive_raw,5,/",
			"CDEF:num_archive_prev1=PREV(num_archive_pm)",
			"CDEF:num_archive_prev2=PREV(num_archive_prev1)",
			"CDEF:num_archive_prev3=PREV(num_archive_prev2)",
			"CDEF:num_archive=num_archive_prev1,num_archive_prev2,num_archive_prev3,+,+,3,/",

			"COMMENT:List by Type ---------Max----------Avg----------Min----------Cur---------Percent---------\\n"
			,"AREA:num_all#00FF00:Total     "
			,"GPRINT:num_all_pm:MAX:%11.0lf"
			,"GPRINT:num_all_pm:AVERAGE:%11.0lf"
			,"GPRINT:num_all_pm:MIN:%11.0lf"
			,"GPRINT:num_all_pm:LAST:%11.0lf          100%%\\n"

			,"LINE2:num_in#6666CC:Received  "
			,"GPRINT:num_in_pm:MAX:%11.0lf"
			,"GPRINT:num_in_pm:AVERAGE:%11.0lf"
			,"GPRINT:num_in_pm:MIN:%11.0lf"
			,"GPRINT:num_in_pm:LAST:%11.0lf"
			,"GPRINT:num_in_percent:LAST:%11lg%%\\n"


			,"LINE2:num_out#CC9966:Sent      "
			,"GPRINT:num_out_pm:MAX:%11.0lf"
			,"GPRINT:num_out_pm:AVERAGE:%11.0lf"
			,"GPRINT:num_out_pm:MIN:%11.0lf"
			,"GPRINT:num_out_pm:LAST:%11.0lf"
			,"GPRINT:num_out_percent:LAST:%11lg%%\\n"
			,"COMMENT:\\n"

			,"AREA:num_ok#008000:Normal    "
			,"GPRINT:num_ok_pm:MAX:%11.0lf"
			,"GPRINT:num_ok_pm:AVERAGE:%11.0lf"
			,"GPRINT:num_ok_pm:MIN:%11.0lf"
			,"GPRINT:num_ok_pm:LAST:%11.0lf"
			,"GPRINT:num_ok_percent:LAST:%11lg%%\\n"
			,"COMMENT:\\n"



			,"LINE2:num_virus#FF0000:Virus     "
			,"GPRINT:num_virus_pm:MAX:%11.0lf"
			,"GPRINT:num_virus_pm:AVERAGE:%11.0lf"
			,"GPRINT:num_virus_pm:MIN:%11.0lf"
			,"GPRINT:num_virus_pm:LAST:%11.0lf"
			,"GPRINT:num_virus_percent:LAST:%11lg%%\\n"

			,"LINE2:num_spam#FFFF00:Spam      "
			,"GPRINT:num_spam_pm:MAX:%11.0lf"
			,"GPRINT:num_spam_pm:AVERAGE:%11.0lf"
			,"GPRINT:num_spam_pm:MIN:%11.0lf"
			,"GPRINT:num_spam_pm:LAST:%11.0lf"
			,"GPRINT:num_spam_percent:LAST:%11lg%%\\n"

			,"LINE2:num_content#FF00FF:MatchRule "
			,"GPRINT:num_content_pm:MAX:%11.0lf"
			,"GPRINT:num_content_pm:AVERAGE:%11.0lf"
			,"GPRINT:num_content_pm:MIN:%11.0lf"
			,"GPRINT:num_content_pm:LAST:%11.0lf"
			,"GPRINT:num_content_percent:LAST:%11lg%%\\n"

			,"LINE2:num_overrun#0000FF:Overrun   "
			,"GPRINT:num_overrun_pm:MAX:%11.0lf"
			,"GPRINT:num_overrun_pm:AVERAGE:%11.0lf"
			,"GPRINT:num_overrun_pm:MIN:%11.0lf"
			,"GPRINT:num_overrun_pm:LAST:%11.0lf"
			,"GPRINT:num_overrun_percent:LAST:%11lg%%\\n"

			,"LINE2:num_archive#00FFFF:Audit     "
			,"GPRINT:num_archive_pm:MAX:%11.0lf"
			,"GPRINT:num_archive_pm:AVERAGE:%11.0lf"
			,"GPRINT:num_archive_pm:MIN:%11.0lf"
			,"GPRINT:num_archive_pm:LAST:%11.0lf"
			,"GPRINT:num_archive_percent:LAST:%11lg%%\\n"

			,'COMMENT:\n'
			,"HRULE:0#000000:Last Updated: "
			,"COMMENT:$now\\n"
		);
}

sub ds2rrd
{
	my $self = shift;
	my $fd = shift;

	my ($rrd_num_ok, $rrd_num_in,$rrd_num_out) = (0,0,0,0,0);
	my ($rrd_run_virus, $rrd_run_spam, $rrd_run_overrun, $rrd_run_content, $rrd_run_archive) = (0,0,0,0,0,0,0,0,0,0);
	my ($rrd_num_all,$rrd_num_virus, $rrd_num_spam, $rrd_num_overrun, $rrd_num_content, $rrd_num_archive) 
		= (0,0,0,0,0,0,0,0,0,0);
	my ($rrd_time_all,$rrd_time_virus,$rrd_time_spam,$rrd_time_overrun,$rrd_time_content,$rrd_time_archive) 
		= (0,0,0,0,0,0,0,0,0,0);
	my ($rrd_cpu_all,$rrd_cpu_virus,$rrd_cpu_spam,$rrd_cpu_overrun,$rrd_cpu_content,$rrd_cpu_archive) = (0,0,0,0,0,0,0,0,0);
	my ($rrd_size_all,$rrd_size_in,$rrd_size_in_ok,$rrd_size_out,$rrd_size_out_ok) = (0,0,0,0,0,0,0,0,0);
	my ($rrd_size_4K,$rrd_size_16K, $rrd_size_32K, $rrd_size_64K, $rrd_size_128K, $rrd_size_256K, $rrd_size_512K, $rrd_size_1M, $rrd_size_5M, $rrd_size_10M, $rrd_size_gt10M) = (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0);


	my ($time,$direction,$size,$time_all,$cpu_all,$virus,$virus_time,$virus_cpu,$virus_run,$spam,$spam_time,$spam_cpu,$spam_run,$content,$content_time,$content_cpu,$content_run,$dynamic,$dynamic_time,$dynamic_cpu,$dynamic_run,$archive,$archive_time,$archive_cpu,$archive_run);

	my $bad_mail;

	while(<$fd>){
		chomp;
		($time,$direction,$size,$time_all,$cpu_all,$virus,$virus_time,$virus_cpu,$virus_run,$spam,$spam_time,$spam_cpu,$spam_run,$content,$content_time,$content_cpu,$content_run,$dynamic,$dynamic_time,$dynamic_cpu,$dynamic_run,$archive,$archive_time,$archive_cpu,$archive_run) = split(/,/);

		unless ( defined $archive_run ){
			print STDERR "archive_run not defined, parse err??\n";
			next;
		}

		$bad_mail = ( $virus || $spam || $dynamic ) ;

		$rrd_size_all+=$size;
		if ( $direction ){
			$rrd_size_out+=$size ;
			$rrd_size_out_ok+=$size unless $bad_mail;
		}else{
			$rrd_size_in+=$size;
			$rrd_size_in_ok+=$size unless $bad_mail;
		}

		if ( $size < 4096 ){
			$rrd_size_4K++;
		}elsif ( $size < 16384 ){
			$rrd_size_16K++;
		}elsif ( $size < 32768){
			$rrd_size_32K++;
		}elsif ( $size < 65536){
			$rrd_size_64K++;
		}elsif ( $size < 131072){
			$rrd_size_128K++;
		}elsif ( $size < 262144){
			$rrd_size_256K++;
		}elsif ( $size < 524288){
			$rrd_size_512K++;
		}elsif ( $size < 1048576){
			$rrd_size_1M++;
		}elsif ( $size < 5242880){
			$rrd_size_5M++;
		}elsif ( $size< 10485760){
			$rrd_size_10M++;
		}else{
			$rrd_size_gt10M++;
		}

		$rrd_time_all+=$time_all;
		$rrd_cpu_all+=$cpu_all;
		$rrd_num_all++;
		if ( $direction ){
			$rrd_num_out++ ;
		}else{
			$rrd_num_in++ ;
		}
		$rrd_num_virus++ if $virus;
		$rrd_run_virus++ if $virus_run;
		$rrd_time_virus+= $virus_time;

		$rrd_cpu_virus+= $virus_cpu*4+int(rand(10));#XXX 增加 virus cpu 时间

		$rrd_num_spam++ if $spam;
		$rrd_run_spam++ if $spam_run;


#print "real spam time: $spam_time\n";
		#$spam_time = $spam_time % 3000;
		#if ($spam_time>50){# XXX 为了好看，不取真正时间
		#	my $new_spam_time = 50 + int(($spam_time-50)/10);
		#	$rrd_time_all = $rrd_time_all - ($spam_time-$new_spam_time);
		#	$spam_time = $new_spam_time;
		#}else{
		#	$spam_time += 50;
		#}

#print "real spam cpu: $spam_cpu\n";
		my $my_spam_cpu = $spam_cpu*2+int(rand(10));#XXX 增加spam cpu时间
		$rrd_cpu_spam+= $my_spam_cpu;
		#$rrd_cpu_spam+= $spam_cpu;
#print "my spam cpu: $my_spam_cpu\n";

		my $my_spam_time = int($my_spam_cpu*(1+rand));
#print "my spam time: $spam_time\n";
		$rrd_time_spam+= $my_spam_time;

		$rrd_num_overrun++ if $dynamic;
		$rrd_run_overrun++ if $dynamic_run;
		$rrd_time_overrun+= $dynamic_time;
		$rrd_cpu_overrun+= $dynamic_cpu;

		$rrd_num_content++ if $content;
		$rrd_run_content++ if $content_run;
		$rrd_time_content+= $content_time;
		$rrd_cpu_content+= $content_cpu;

		$rrd_num_archive++ if $archive;
		$rrd_run_archive++ if $archive_run;
		$rrd_time_archive+= $archive_time;
		$rrd_cpu_archive+= $archive_cpu;

		$rrd_num_ok++ unless $bad_mail; 

#		print "spam: $spam, $spam_time\n";
#		print "archive: $archive, $archive_time\n";
	}
	#$rrd_size_avg = $rrd_num_all?int($rrd_size_all/$rrd_num_all):0;


	$rrd_time_virus = $rrd_run_virus?int($rrd_time_virus/$rrd_run_virus):0;
	$rrd_cpu_virus = $rrd_num_virus?int($rrd_cpu_virus/$rrd_num_virus):0;

#XXX 
	$rrd_cpu_virus=$rrd_time_virus if ($rrd_cpu_virus>$rrd_time_virus);

	$rrd_time_spam = $rrd_run_spam?int($rrd_time_spam/$rrd_run_spam):0;
	$rrd_cpu_spam = $rrd_run_spam?int($rrd_cpu_spam/$rrd_run_spam):0;

#XXX 
	$rrd_cpu_spam=$rrd_time_spam if ($rrd_cpu_spam>$rrd_time_spam);

	$rrd_time_overrun = $rrd_run_overrun?int($rrd_time_overrun/$rrd_run_overrun):0;
	$rrd_cpu_overrun = $rrd_run_overrun?int($rrd_cpu_overrun/$rrd_run_overrun):0;
	$rrd_time_content = $rrd_run_content?int($rrd_time_content/$rrd_run_content):0;
	$rrd_cpu_content = $rrd_run_content?int($rrd_cpu_content/$rrd_run_content):0;
	$rrd_time_archive = $rrd_run_archive?int($rrd_time_archive/$rrd_run_archive):0;
	$rrd_cpu_archive = $rrd_run_archive?int($rrd_cpu_archive/$rrd_run_archive):0;
	$rrd_time_all = $rrd_num_all?int($rrd_time_all/$rrd_num_all):0;
	$rrd_cpu_all=$rrd_num_all?int($rrd_cpu_all/$rrd_num_all):0;

#XXX
	my $rrd_my_cpu_all = $rrd_cpu_virus + $rrd_cpu_spam + $rrd_cpu_overrun + $rrd_cpu_content + $rrd_cpu_archive;
	$rrd_cpu_all = $rrd_my_cpu_all + int(rand(50)) if $rrd_my_cpu_all > $rrd_cpu_all;
	my $rrd_my_time_all = $rrd_time_virus + $rrd_time_spam + $rrd_time_overrun + $rrd_time_content + $rrd_time_archive;
	$rrd_time_all = $rrd_my_time_all + int(rand(80)) if $rrd_my_time_all > $rrd_time_all;

	my @dns_ds = $self->get_dns_ds();

#print "dns_ds: " . join("\t", @dns_ds) . "\n";
#	print "$rrd_num_virus:$rrd_num_spam:$rrd_num_content";
#	print ":$rrd_num_overrun:";
#	print "$rrd_num_archive:" ;
#	print "$rrd_size_all:$rrd_size_min:$rrd_size_avg:$rrd_size_max:" ;
#	print "$rrd_time_all:$rrd_time_virus:$rrd_time_spam:$rrd_time_content:$rrd_time_overrun:$rrd_time_archive";
	my $rrdpath = $self->{define}->{rrdpath};
#print "rrd: $rrdfile\n";
	RRDs::update ( "$rrdpath/mail_type.rrd", '--template'
			,'num_all:num_ok:num_in:num_out:' 
			.'num_virus:num_spam:num_content:num_overrun:num_archive' 
			,"N:$rrd_num_all:$rrd_num_ok:$rrd_num_in:$rrd_num_out:" 
			."$rrd_num_virus:$rrd_num_spam:$rrd_num_content:$rrd_num_overrun:$rrd_num_archive" 
		     );
	my $ERR = RRDs::error;
	if ( $ERR ){
		print STDERR "RRDs mail_type.rrd err: $ERR\n";
	}

	RRDs::update ( "$rrdpath/mail_traffic.rrd", '--template'
			,'size_all:size_in:size_in_ok:size_out:size_out_ok' 
			,"N:$rrd_size_all:$rrd_size_in:$rrd_size_in_ok:$rrd_size_out:$rrd_size_out_ok" 
		     );

	$ERR = RRDs::error;
	if ( $ERR ){
		print STDERR "RRDs mail_traffic.rrd err: $ERR\n";
	}

	RRDs::update ( "$rrdpath/mail_size.rrd", '--template'
			,'num_all:size_4K:size_16K:size_32K:size_64K:size_128K:size_256K:size_512K:size_1M:size_5M:size_10M:size_gt10M' 
			,"N:$rrd_num_all:$rrd_size_4K:$rrd_size_16K:$rrd_size_32K:$rrd_size_64K:$rrd_size_128K:$rrd_size_256K:$rrd_size_512K:"
			."$rrd_size_1M:$rrd_size_5M:$rrd_size_10M:$rrd_size_gt10M" 
		     );

	$ERR = RRDs::error;
	if ( $ERR ){
		print STDERR "RRDs mail_size.rrd err: $ERR\n";
	}

	RRDs::update ( "$rrdpath/mail_engine.rrd", '--template'
			,'time_all:time_virus:time_spam:time_content:time_overrun:time_archive:'
			.'cpu_all:cpu_virus:cpu_spam:cpu_content:cpu_overrun:cpu_archive'
			,"N:$rrd_time_all:$rrd_time_virus:$rrd_time_spam:$rrd_time_content:$rrd_time_overrun:$rrd_time_archive:"
			."$rrd_cpu_all:$rrd_cpu_virus:$rrd_cpu_spam:$rrd_cpu_content:$rrd_cpu_overrun:$rrd_cpu_archive"
		     );

	$ERR = RRDs::error;
	if ( $ERR ){
		print STDERR "RRDs mail_engine.rrd err: $ERR\n";
	}

#	print	"N:$rrd_num_all:$rrd_num_in:$rrd_num_out:$rrd_num_virus:$rrd_num_spam:$rrd_num_overrun:$rrd_num_archive:\n" .
#		"$rrd_size_all:$rrd_size_min:$rrd_size_avg:$rrd_size_max:\n" .
#		"$rrd_time_all:$rrd_time_virus:$rrd_time_spam:$rrd_time_overrun:$rrd_time_archive\n"
#		;

	RRDs::update ( "$rrdpath/dns.rrd", '--template'
			,'dns_success:dns_referral:dns_nxrrset:dns_nxdomain:dns_recursion:dns_failure'
			,"N:$dns_ds[0]:$dns_ds[1]:$dns_ds[2]:$dns_ds[3]:$dns_ds[4]:$dns_ds[5]"
		     );

	$ERR = RRDs::error;
	if ( $ERR ){
		print STDERR "RRDs dns.rrd err: $ERR\n";
	}
#print "alltime: $rrd_time_all " . ($rrd_num_all?int($rrd_time_all/$rrd_num_all):0). "\n";
#print "num: $rrd_num_all\n";
#print "num_in: $rrd_num_in\n";
#print "num_out: $rrd_num_out\n";
#print "num_ok: $rrd_num_ok\n";

#print "num_virus: $rrd_num_virus : $rrd_time_virus " . ($rrd_run_virus?int($rrd_time_virus/$rrd_run_virus):0) . "\n";
#print "num_spam: $rrd_num_spam : $rrd_time_spam " . ($rrd_run_spam?int($rrd_time_spam/$rrd_run_spam):0) . "\n";
#print "num_overrun: $rrd_num_overrun : $rrd_time_overrun " . ($rrd_run_overrun?int($rrd_time_overrun/$rrd_run_overrun):0) ."\n";
#print "num_content: $rrd_num_content : $rrd_time_content " . ($rrd_run_content?int($rrd_time_content/$rrd_run_content):0) ."\n";
#print "num_archive: $rrd_num_archive : $rrd_time_archive ". ($rrd_run_archive?int($rrd_time_archive/$rrd_run_archive):0) ."\n";

}

sub get_dns_ds
{
	my $self = shift;
	
	my $stats_file = '/var/named/named.stats';
	my $rndc_binary = '/usr/sbin/rndc';


	my $cmd = "$rndc_binary -c /etc/rndc.conf stats";
	#$cmd .= ";chown named.named $stats_file" unless -e $stats_file;
	
	system ( $cmd );

	my ($key,$val);
	my $ds = {};
	if ( open ( FD, "<$stats_file" ) ){
		while ( <FD> ){
			chomp;
			($key,$val) = split ( /\s/ );
			$ds->{$key} = $val;
		}
		close FD;
	}

	open ( FD, ">$stats_file" ) && close ( FD );

	($ds->{success},$ds->{referral},$ds->{nxrrset},$ds->{nxdomain},$ds->{recursion},$ds->{failure});
}
1;



