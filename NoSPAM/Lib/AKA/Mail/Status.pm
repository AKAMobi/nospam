#
# RRD ¼à¿ØÍ¼Éú³É
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

	return $self;
}

sub rrdgraph_size
{
	my $self = shift;
	RRDs::graph ("/home/NoSPAM/admin/status/size.gif", 
			"--title=Size Status",  
			"--vertical-label=Number per Minute", 
			"--start=$start_time",      
			"--end=$end_time",        
#"--color=BACK#CCCCCC",   
#"--color=CANVAS#CCFFFF",
#"--color=SHADEB#9999CC",
			"--height=200",        
			"--width=500",        
			"--upper-limit=40",  
#"--lower-limit=-10",   
#"--rigid",          
#"--base=1024",     
			"DEF:num_all_raw=nospam.rrd:num_all:AVERAGE", 
			"CDEF:num_all_prev1=PREV(num_all_raw)",
			"CDEF:num_all_prev2=PREV(num_all_prev1)",
			"CDEF:num_all_prev3=PREV(num_all_prev2)",
#"CDEF:num_all=num_all_prev1,num_all_prev2,num_all_prev3,+,+,3,/,5,/",
			"CDEF:num_all=num_all_prev1,num_all_prev2,num_all_prev3,+,+,3,/",

			"DEF:size_4K_raw=nospam.rrd:size_4K:AVERAGE", 
			"CDEF:size_4K_percent=100,size_4K_raw,*,num_all_raw,/,FLOOR",
			"CDEF:size_4K_prev1=PREV(size_4K_raw)",
			"CDEF:size_4K_prev2=PREV(size_4K_prev1)",
			"CDEF:size_4K_prev3=PREV(size_4K_prev2)",
			"CDEF:size_4K=size_4K_prev1,size_4K_prev2,size_4K_prev3,+,+,3,/",

			"DEF:size_16K_raw=nospam.rrd:size_16K:AVERAGE", 
			"CDEF:size_16K_percent=100,size_16K_raw,*,num_all_raw,/,FLOOR",
			"CDEF:size_16K_prev1=PREV(size_16K_raw)",
			"CDEF:size_16K_prev2=PREV(size_16K_prev1)",
			"CDEF:size_16K_prev3=PREV(size_16K_prev2)",
			"CDEF:size_16K=size_4K,size_16K_prev1,size_16K_prev2,size_16K_prev3,+,+,3,/,+",

			"DEF:size_32K_raw=nospam.rrd:size_32K:AVERAGE", 
			"CDEF:size_32K_percent=100,size_32K_raw,*,num_all_raw,/,FLOOR",
			"CDEF:size_32K_prev1=PREV(size_32K_raw)",
			"CDEF:size_32K_prev2=PREV(size_32K_prev1)",
			"CDEF:size_32K_prev3=PREV(size_32K_prev2)",
#"CDEF:size_32K=size_32K_prev1,size_32K_prev2,size_32K_prev3,+,+,3,/,5,/",
			"CDEF:size_32K=size_16K,size_32K_prev1,size_32K_prev2,size_32K_prev3,+,+,3,/,+",


			"DEF:size_64K_raw=nospam.rrd:size_64K:AVERAGE", 
			"CDEF:size_64K_percent=100,size_64K_raw,*,num_all_raw,/,FLOOR",
			"CDEF:size_64K_prev1=PREV(size_64K_raw)",
			"CDEF:size_64K_prev2=PREV(size_64K_prev1)",
			"CDEF:size_64K_prev3=PREV(size_64K_prev2)",
#"CDEF:size_64K=size_64K_prev1,size_64K_prev2,size_64K_prev3,+,+,3,/,5,/",
			"CDEF:size_64K=size_32K,size_64K_prev1,size_64K_prev2,size_64K_prev3,+,+,3,/,+",

			"DEF:size_128K_raw=nospam.rrd:size_128K:AVERAGE",
			"CDEF:size_128K_percent=100,size_128K_raw,*,num_all_raw,/,FLOOR",
			"CDEF:size_128K_prev1=PREV(size_128K_raw)",
			"CDEF:size_128K_prev2=PREV(size_128K_prev1)",
			"CDEF:size_128K_prev3=PREV(size_128K_prev2)",
#"CDEF:size_128K=size_128K_prev1,size_128K_prev2,size_128K_prev3,+,+,3,/,5,/",
			"CDEF:size_128K=size_16K,size_128K_prev1,size_128K_prev2,size_128K_prev3,+,+,3,/,+",

			"DEF:size_256K_raw=nospam.rrd:size_256K:AVERAGE",
			"CDEF:size_256K_percent=100,size_256K_raw,*,num_all_raw,/,FLOOR",
			"CDEF:size_256K_prev1=PREV(size_256K_raw)",
			"CDEF:size_256K_prev2=PREV(size_256K_prev1)",
			"CDEF:size_256K_prev3=PREV(size_256K_prev2)",
#"CDEF:size_256K=size_256K_prev1,size_256K_prev2,size_256K_prev3,+,+,3,/,5,/",
			"CDEF:size_256K=size_128K,size_256K_prev1,size_256K_prev2,size_256K_prev3,+,+,3,/,+",

			"DEF:size_512K_raw=nospam.rrd:size_512K:AVERAGE", 
			"CDEF:size_512K_percent=100,size_512K_raw,*,num_all_raw,/,FLOOR",
			"CDEF:size_512K_prev1=PREV(size_512K_raw)",
			"CDEF:size_512K_prev2=PREV(size_512K_prev1)",
			"CDEF:size_512K_prev3=PREV(size_512K_prev2)",
#"CDEF:size_512K=size_512K_prev1,size_512K_prev2,size_512K_prev3,+,+,3,/,5,/",
			"CDEF:size_512K=size_256K,size_512K_prev1,size_512K_prev2,size_512K_prev3,+,+,3,/,+",

			"DEF:size_1M_raw=nospam.rrd:size_1M:AVERAGE", 
			"CDEF:size_1M_percent=100,size_1M_raw,*,num_all_raw,/,FLOOR",
			"CDEF:size_1M_prev1=PREV(size_1M_raw)",
			"CDEF:size_1M_prev2=PREV(size_1M_prev1)",
			"CDEF:size_1M_prev3=PREV(size_1M_prev2)",
#"CDEF:size_1M=size_1M_prev1,size_1M_prev2,size_1M_prev3,+,+,3,/,5,/",
			"CDEF:size_1M=size_512K,size_1M_prev1,size_1M_prev2,size_1M_prev3,+,+,3,/,+",

			"DEF:size_5M_raw=nospam.rrd:size_5M:AVERAGE", 
			"CDEF:size_5M_percent=100,size_5M_raw,*,num_all_raw,/,FLOOR",
			"CDEF:size_5M_prev1=PREV(size_5M_raw)",
			"CDEF:size_5M_prev2=PREV(size_5M_prev1)",
			"CDEF:size_5M_prev3=PREV(size_5M_prev2)",
#"CDEF:size_5M=size_5M_prev1,size_5M_prev2,size_5M_prev3,+,+,3,/,5,/",
			"CDEF:size_5M=size_1M,size_5M_prev1,size_5M_prev2,size_5M_prev3,+,+,3,/,+",

			"DEF:size_10M_raw=nospam.rrd:size_10M:AVERAGE", 
			"CDEF:size_10M_percent=100,size_10M_raw,*,num_all_raw,/,FLOOR",
			"CDEF:size_10M_prev1=PREV(size_10M_raw)",
			"CDEF:size_10M_prev2=PREV(size_10M_prev1)",
			"CDEF:size_10M_prev3=PREV(size_10M_prev2)",
#"CDEF:size_10M=size_10M_prev1,size_10M_prev2,size_10M_prev3,+,+,3,/,5,/",
			"CDEF:size_10M=size_5M,size_10M_prev1,size_10M_prev2,size_10M_prev3,+,+,3,/,+",

			"DEF:size_gt10M_raw=nospam.rrd:size_gt10M:AVERAGE", 
			"CDEF:size_gt10M_percent=100,size_gt10M_raw,*,num_all_raw,/,FLOOR",
			"CDEF:size_gt10M_prev1=PREV(size_gt10M_raw)",
			"CDEF:size_gt10M_prev2=PREV(size_gt10M_prev1)",
			"CDEF:size_gt10M_prev3=PREV(size_gt10M_prev2)",
#"CDEF:size_gt10M=size_gt10M_prev1,size_gt10M_prev2,size_gt10M_prev3,+,+,3,/,5,/",
			"CDEF:size_gt10M=size_10M,size_gt10M_prev1,size_gt10M_prev2,size_gt10M_prev3,+,+,3,/,+",


#"HRULE:656#000000:Maximum Available Memory - 656 MB",
			'COMMENT:Sort by Size --------Max----------Avg----------Min----------Cur---------Percent---------\n'

#,"AREA:num_all#00FF00:All     "
#,"GPRINT:num_all_raw:MAX:%11.0lf"
#,"GPRINT:num_all_raw:AVERAGE:%11.0lf"
#,"GPRINT:num_all_raw:MIN:%11.0lf"
#,"GPRINT:num_all_raw:LAST:%11.0lf\\n"


			,"AREA:size_gt10M#FF0000:>10MB    "
			,"GPRINT:size_gt10M_raw:MAX:%11.0lf"
			,"GPRINT:size_gt10M_raw:AVERAGE:%11.0lf"
			,"GPRINT:size_gt10M_raw:MIN:%11.0lf"
			,"GPRINT:size_gt10M_raw:LAST:%11.0lf"
			,'GPRINT:size_gt10M_percent:LAST:%11lg%%\\n'

			,"AREA:size_10M#F40B03:5MB-10MB "
			,"GPRINT:size_10M_raw:MAX:%11.0lf"
			,"GPRINT:size_10M_raw:AVERAGE:%11.0lf"
			,"GPRINT:size_10M_raw:MIN:%11.0lf"
			,"GPRINT:size_10M_raw:LAST:%11.0lf"
			,'GPRINT:size_10M_percent:LAST:%11lg%%\\n'

			,"AREA:size_5M#D22D0A:1MB-5MB  "
			,"GPRINT:size_5M_raw:MAX:%11.0lf"
			,"GPRINT:size_5M_raw:AVERAGE:%11.0lf"
			,"GPRINT:size_5M_raw:MIN:%11.0lf"
			,"GPRINT:size_5M_raw:LAST:%11.0lf"
			,'GPRINT:size_5M_percent:LAST:%11lg%%\\n'


			,"AREA:size_1M#C03F0F:512KB-1MB"
			,"GPRINT:size_1M_raw:MAX:%11.0lf"
			,"GPRINT:size_1M_raw:AVERAGE:%11.0lf"
			,"GPRINT:size_1M_raw:MIN:%11.0lf"
			,"GPRINT:size_1M_raw:LAST:%11.0lf"
			,'GPRINT:size_1M_percent:LAST:%11lg%%\\n'

			,"AREA:size_512K#FFFC00:256-512KB"
			,"GPRINT:size_512K_raw:MAX:%11.0lf"
			,"GPRINT:size_512K_raw:AVERAGE:%11.0lf"
			,"GPRINT:size_512K_raw:MIN:%11.0lf"
			,"GPRINT:size_512K_raw:LAST:%11.0lf"
			,'GPRINT:size_512K_percent:LAST:%11lg%%\\n'

			,"AREA:size_256K#B8F706:128-256KB"
			,"GPRINT:size_256K_raw:MAX:%11.0lf"
			,"GPRINT:size_256K_raw:AVERAGE:%11.0lf"
			,"GPRINT:size_256K_raw:MIN:%11.0lf"
			,"GPRINT:size_256K_raw:LAST:%11.0lf"
			,'GPRINT:size_256K_percent:LAST:%11lg%%\\n'

			,"AREA:size_128K#92F408:64-128KB "
			,"GPRINT:size_128K_raw:MAX:%11.0lf"
			,"GPRINT:size_128K_raw:AVERAGE:%11.0lf"
			,"GPRINT:size_128K_raw:MIN:%11.0lf"
			,"GPRINT:size_128K_raw:LAST:%11.0lf"
			,'GPRINT:size_128K_percent:LAST:%11lg%%\\n'

			,"AREA:size_64K#49B72B:32-64KB  "
			,"GPRINT:size_64K_raw:MAX:%11.0lf"
			,"GPRINT:size_64K_raw:AVERAGE:%11.0lf"
			,"GPRINT:size_64K_raw:MIN:%11.0lf"
			,"GPRINT:size_64K_raw:LAST:%11.0lf"
			,'GPRINT:size_64K_percent:LAST:%11lg%%\\n'

			,"AREA:size_32K#46B92B:16-32KB  "
			,"GPRINT:size_32K_raw:MAX:%11.0lf"
			,"GPRINT:size_32K_raw:AVERAGE:%11.0lf"
			,"GPRINT:size_32K_raw:MIN:%11.0lf"
			,"GPRINT:size_32K_raw:LAST:%11.0lf"
			,'GPRINT:size_32K_percent:LAST:%11lg%%\\n'

			,"AREA:size_16K#2BD432:4-16KB   "
			,"GPRINT:size_16K_raw:MAX:%11.0lf"
			,"GPRINT:size_16K_raw:AVERAGE:%11.0lf"
			,"GPRINT:size_16K_raw:MIN:%11.0lf"
			,"GPRINT:size_16K_raw:LAST:%11.0lf"
			,'GPRINT:size_16K_percent:LAST:%11lg%%\\n'

			,"AREA:size_4K#00FF00:<4KB     "
			,"GPRINT:size_4K_raw:MAX:%11.0lf"
			,"GPRINT:size_4K_raw:AVERAGE:%11.0lf"
			,"GPRINT:size_4K_raw:MIN:%11.0lf"
			,"GPRINT:size_4K_raw:LAST:%11.0lf"
			,'GPRINT:size_4K_percent:LAST:%11lg%%\\n'

			,'COMMENT:\n'
#,"HRULE:1#000000:"
#,"HRULE:-1#000000:"
			,"HRULE:0#000000:Last Updated\: "
			,"COMMENT:$now\\n"


		);

#"CDEF:correct_tot_mem=tot_mem,0,671744,LIMIT,UN,0,tot_mem,IF,1024,/",\
#"CDEF:machine_mem=tot_mem,656,+,tot_mem,-",\
			my $err=RRDs::error;
			if ($err) {print "problem generating the graph: $err\n";}
}

sub rrdgraph_engine
{
	my $self = shift;
	RRDs::graph ("/home/NoSPAM/admin/status/time.gif", 
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
#"--lazy",
#'--imginfo "<IMG SRC="%s" WIDTH="%lu" HEIGHT="%lu" ALT="Demo">"',
			"--upper-limit=200",  
			"--lower-limit=-100",   
#"--rigid",          
#"--base=1024",     
			"DEF:time_all_raw=nospam.rrd:time_all:AVERAGE", 
			"CDEF:time_all_prev1=PREV(time_all_raw)",
			"CDEF:time_all_prev2=PREV(time_all_prev1)",
			"CDEF:time_all_prev3=PREV(time_all_prev2)",
			"CDEF:time_all=time_all_prev1,time_all_prev2,time_all_prev3,+,+,3,/",

			"DEF:time_virus_raw=nospam.rrd:time_virus:AVERAGE",
			"CDEF:time_virus_prev1=PREV(time_virus_raw)",
			"CDEF:time_virus_prev2=PREV(time_virus_prev1)",
			"CDEF:time_virus_prev3=PREV(time_virus_prev2)",
			"CDEF:time_virus=time_virus_prev1,time_virus_prev2,time_virus_prev3,+,+,3,/",

			"DEF:time_spam_raw=nospam.rrd:time_spam:AVERAGE", 
			"CDEF:time_spam_prev1=PREV(time_spam_raw)",
			"CDEF:time_spam_prev2=PREV(time_spam_prev1)",
			"CDEF:time_spam_prev3=PREV(time_spam_prev2)",
			"CDEF:time_spam=time_virus,time_spam_prev1,time_spam_prev2,time_spam_prev3,+,+,3,/,+",

			"DEF:time_content_raw=nospam.rrd:time_content:AVERAGE", 
			"CDEF:time_content_prev1=PREV(time_content_raw)",
			"CDEF:time_content_prev2=PREV(time_content_prev1)",
			"CDEF:time_content_prev3=PREV(time_content_prev2)",
			"CDEF:time_content=time_spam,time_content_prev1,time_content_prev2,time_content_prev3,+,+,3,/,+",

			"DEF:time_overrun_raw=nospam.rrd:time_overrun:AVERAGE", 
			"CDEF:time_overrun_prev1=PREV(time_overrun_raw)",
			"CDEF:time_overrun_prev2=PREV(time_overrun_prev1)",
			"CDEF:time_overrun_prev3=PREV(time_overrun_prev2)",
			"CDEF:time_overrun=time_content,time_overrun_prev1,time_overrun_prev2,time_overrun_prev3,+,+,3,/,+",

			"DEF:time_archive_raw=nospam.rrd:time_archive:AVERAGE", 
			"CDEF:time_archive_prev1=PREV(time_archive_raw)",
			"CDEF:time_archive_prev2=PREV(time_archive_prev1)",
			"CDEF:time_archive_prev3=PREV(time_archive_prev2)",
			"CDEF:time_archive=time_overrun,time_archive_prev1,time_archive_prev2,time_archive_prev3,+,+,3,/,+",


			"DEF:cpu_all_raw=nospam.rrd:cpu_all:AVERAGE", 
			"CDEF:cpu_all_prev1=PREV(cpu_all_raw)",
			"CDEF:cpu_all_prev2=PREV(cpu_all_prev1)",
			"CDEF:cpu_all_prev3=PREV(cpu_all_prev2)",
			"CDEF:cpu_all=0,cpu_all_prev1,cpu_all_prev2,cpu_all_prev3,+,+,3,/,-",

			"DEF:cpu_virus_raw=nospam.rrd:cpu_virus:AVERAGE",
			"CDEF:cpu_virus_prev1=PREV(cpu_virus_raw)",
			"CDEF:cpu_virus_prev2=PREV(cpu_virus_prev1)",
			"CDEF:cpu_virus_prev3=PREV(cpu_virus_prev2)",
			"CDEF:cpu_virus=0,cpu_virus_prev1,cpu_virus_prev2,cpu_virus_prev3,+,+,3,/,-",

			"DEF:cpu_spam_raw=nospam.rrd:cpu_spam:AVERAGE", 
			"CDEF:cpu_spam_prev1=PREV(cpu_spam_raw)",
			"CDEF:cpu_spam_prev2=PREV(cpu_spam_prev1)",
			"CDEF:cpu_spam_prev3=PREV(cpu_spam_prev2)",
			"CDEF:cpu_spam=cpu_virus,0,cpu_spam_prev1,cpu_spam_prev2,cpu_spam_prev3,+,+,3,/,-,+",

			"DEF:cpu_content_raw=nospam.rrd:cpu_content:AVERAGE", 
			"CDEF:cpu_content_prev1=PREV(cpu_content_raw)",
			"CDEF:cpu_content_prev2=PREV(cpu_content_prev1)",
			"CDEF:cpu_content_prev3=PREV(cpu_content_prev2)",
			"CDEF:cpu_content=cpu_spam,0,cpu_content_prev1,cpu_content_prev2,cpu_content_prev3,+,+,3,/,-,+",

			"DEF:cpu_overrun_raw=nospam.rrd:cpu_overrun:AVERAGE", 
			"CDEF:cpu_overrun_prev1=PREV(cpu_overrun_raw)",
			"CDEF:cpu_overrun_prev2=PREV(cpu_overrun_prev1)",
			"CDEF:cpu_overrun_prev3=PREV(cpu_overrun_prev2)",
			"CDEF:cpu_overrun=cpu_content,0,cpu_overrun_prev1,cpu_overrun_prev2,cpu_overrun_prev3,+,+,3,/,-,+",

			"DEF:cpu_archive_raw=nospam.rrd:cpu_archive:AVERAGE", 
			"CDEF:cpu_archive_prev1=PREV(cpu_archive_raw)",
			"CDEF:cpu_archive_prev2=PREV(cpu_archive_prev1)",
			"CDEF:cpu_archive_prev3=PREV(cpu_archive_prev2)",
			"CDEF:cpu_archive=cpu_overrun,0,cpu_archive_prev1,cpu_archive_prev2,cpu_archive_prev3,+,+,3,/,-,+",


			"VRULE:$today_start#AA0000:"
			,"VRULE:$yesterday_start#AA0000:"

			,"COMMENT:Real Time (ms) --------Max----------Avg----------Min----------Cur----------\\n"
			,"AREA:time_all#00FF00:All Engines"
			,"GPRINT:time_all_raw:MAX:%11.0lf"
			,"GPRINT:time_all_raw:AVERAGE:%11.0lf"
			,"GPRINT:time_all_raw:MIN:%11.0lf"
			,"GPRINT:time_all_raw:LAST:%11.0lf\\n"


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

			,"AREA:time_spam#FFFF00:AntiSPAM   "
			,"GPRINT:time_spam_raw:MAX:%11.0lf"
			,"GPRINT:time_spam_raw:AVERAGE:%11.0lf"
			,"GPRINT:time_spam_raw:MIN:%11.0lf"
			,"GPRINT:time_spam_raw:LAST:%11.0lf\\n"

			,"AREA:time_virus#FF0000:AntiVirus  "
			,"GPRINT:time_virus_raw:MAX:%11.0lf"
			,"GPRINT:time_virus_raw:AVERAGE:%11.0lf"
			,"GPRINT:time_virus_raw:MIN:%11.0lf"
			,"GPRINT:time_virus_raw:LAST:%11.0lf\\n"


			,'COMMENT:\n'
			,"COMMENT:CPU Time (ms)----------Max----------Avg----------Min----------Cur----------\\n"
			,"AREA:cpu_all#00FF00:All Engines"
			,"GPRINT:cpu_all_raw:MAX:%11.0lf"
			,"GPRINT:cpu_all_raw:AVERAGE:%11.0lf"
			,"GPRINT:cpu_all_raw:MIN:%11.0lf"
			,"GPRINT:cpu_all_raw:LAST:%11.0lf\\n"


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

			,"AREA:cpu_spam#FFFF00:AntiSPAM   "
			,"GPRINT:cpu_spam_raw:MAX:%11.0lf"
			,"GPRINT:cpu_spam_raw:AVERAGE:%11.0lf"
			,"GPRINT:cpu_spam_raw:MIN:%11.0lf"
			,"GPRINT:cpu_spam_raw:LAST:%11.0lf\\n"


			,"AREA:cpu_virus#FF0000:AntiVirus  "
			,"GPRINT:cpu_virus_raw:MAX:%11.0lf"
			,"GPRINT:cpu_virus_raw:AVERAGE:%11.0lf"
			,"GPRINT:cpu_virus_raw:MIN:%11.0lf"
			,"GPRINT:cpu_virus_raw:LAST:%11.0lf\\n"


			,'COMMENT:\n'
			,"HRULE:0#000000:Last Updated: "
			,"COMMENT:$now\\n"

			);

			my $err=RRDs::error;
			if ($err) {print "problem generating the graph: $err\n";}
}

sub rrdgraph_type
{
	my $self = shift;
	RRDs::graph ("/home/NoSPAM/admin/status/rrd.gif", 
			"--title=Send/Receive Status",  
			"--vertical-label=Number per Minute", 
			"--start=$start_time",      
			"--end=$end_time",        
#"--color=BACK#CCCCCC",   
#"--color=CANVAS#CCFFFF",
#"--color=SHADEB#9999CC",
			"--height=200",        
			"--width=500",        
			"--upper-limit=100",  
			"--lower-limit=-20",   
#"--rigid",          
#"--base=1024",     
			"DEF:num_all_raw=nospam.rrd:num_all:AVERAGE", 
			"CDEF:num_all_prev1=PREV(num_all_raw)",
			"CDEF:num_all_prev2=PREV(num_all_prev1)",
			"CDEF:num_all_prev3=PREV(num_all_prev2)",
#"CDEF:num_all=num_all_prev1,num_all_prev2,num_all_prev3,+,+,3,/,5,/",
			"CDEF:num_all=num_all_prev1,num_all_prev2,num_all_prev3,+,+,3,/",


			"DEF:num_ok_raw=nospam.rrd:num_ok:AVERAGE", 
			"CDEF:num_ok_percent=100,num_ok_raw,*,num_all_raw,/,FLOOR",
			"CDEF:num_ok_prev1=PREV(num_ok_raw)",
			"CDEF:num_ok_prev2=PREV(num_ok_prev1)",
			"CDEF:num_ok_prev3=PREV(num_ok_prev2)",
#"CDEF:num_ok=-10,num_ok_prev1,num_ok_prev2,num_ok_prev3,+,+,3,/,5,/,-",
			"CDEF:num_ok=0,num_ok_prev1,num_ok_prev2,num_ok_prev3,+,+,3,/,-",


			"DEF:num_out_raw=nospam.rrd:num_out:AVERAGE",
			"CDEF:num_out_percent=100,num_out_raw,*,num_all_raw,/,FLOOR",
			"CDEF:num_out_prev1=PREV(num_out_raw)",
			"CDEF:num_out_prev2=PREV(num_out_prev1)",
			"CDEF:num_out_prev3=PREV(num_out_prev2)",
#"CDEF:num_out=num_out_prev1,num_out_prev2,num_out_prev3,+,+,3,/,5,/",
			"CDEF:num_out=num_out_prev1,num_out_prev2,num_out_prev3,+,+,3,/",

			"DEF:num_in_raw=nospam.rrd:num_in:AVERAGE", 
			"CDEF:num_in_percent=100,num_in_raw,*,num_all_raw,/,FLOOR",
			"CDEF:num_in_prev1=PREV(num_in_raw)",
			"CDEF:num_in_prev2=PREV(num_in_prev1)",
			"CDEF:num_in_prev3=PREV(num_in_prev2)",
#"CDEF:num_in=num_in_prev1,num_in_prev2,num_in_prev3,+,+,3,/,5,/",
			"CDEF:num_in=num_in_prev1,num_in_prev2,num_in_prev3,+,+,3,/",

			"DEF:num_virus_raw=nospam.rrd:num_virus:AVERAGE", 
			"CDEF:num_virus_percent=100,num_virus_raw,*,num_all_raw,/,FLOOR",
			"CDEF:num_virus_prev1=PREV(num_virus_raw)",
			"CDEF:num_virus_prev2=PREV(num_virus_prev1)",
			"CDEF:num_virus_prev3=PREV(num_virus_prev2)",
#"CDEF:num_virus=num_virus_prev1,num_virus_prev2,num_virus_prev3,+,+,3,/,5,/",
			"CDEF:num_virus=num_virus_prev1,num_virus_prev2,num_virus_prev3,+,+,3,/",

			"DEF:num_spam_raw=nospam.rrd:num_spam:AVERAGE", 
			"CDEF:num_spam_percent=100,num_spam_raw,*,num_all_raw,/,FLOOR",
			"CDEF:num_spam_prev1=PREV(num_spam_raw)",
			"CDEF:num_spam_prev2=PREV(num_spam_prev1)",
			"CDEF:num_spam_prev3=PREV(num_spam_prev2)",
#"CDEF:num_spam=num_spam_prev1,num_spam_prev2,num_spam_prev3,+,+,3,/,5,/",
			"CDEF:num_spam=num_spam_prev1,num_spam_prev2,num_spam_prev3,+,+,3,/",

			"DEF:num_content_raw=nospam.rrd:num_content:AVERAGE", 
			"CDEF:num_content_percent=100,num_content_raw,*,num_all_raw,/,FLOOR",
			"CDEF:num_content_prev1=PREV(num_content_raw)",
			"CDEF:num_content_prev2=PREV(num_content_prev1)",
			"CDEF:num_content_prev3=PREV(num_content_prev2)",
#"CDEF:num_content=num_content_prev1,num_content_prev2,num_content_prev3,+,+,3,/,5,/",
			"CDEF:num_content=num_content_prev1,num_content_prev2,num_content_prev3,+,+,3,/",

			"DEF:num_overrun_raw=nospam.rrd:num_overrun:AVERAGE", 
			"CDEF:num_overrun_percent=100,num_overrun_raw,*,num_all_raw,/,FLOOR",
			"CDEF:num_overrun_prev1=PREV(num_overrun_raw)",
			"CDEF:num_overrun_prev2=PREV(num_overrun_prev1)",
			"CDEF:num_overrun_prev3=PREV(num_overrun_prev2)",
#"CDEF:num_overrun=num_overrun_prev1,num_overrun_prev2,num_overrun_prev3,+,+,3,/,5,/",
			"CDEF:num_overrun=num_overrun_prev1,num_overrun_prev2,num_overrun_prev3,+,+,3,/",

			"DEF:num_archive_raw=nospam.rrd:num_archive:AVERAGE", 
			"CDEF:num_archive_percent=100,num_archive_raw,*,num_all_raw,/,FLOOR",
			"CDEF:num_archive_prev1=PREV(num_archive_raw)",
			"CDEF:num_archive_prev2=PREV(num_archive_prev1)",
			"CDEF:num_archive_prev3=PREV(num_archive_prev2)",
#"CDEF:num_archive=num_archive_prev1,num_archive_prev2,num_archive_prev3,+,+,3,/,5,/",
			"CDEF:num_archive=num_archive_prev1,num_archive_prev2,num_archive_prev3,+,+,3,/",


#"HRULE:656#000000:Maximum Available Memory - 656 MB",
			"COMMENT:Sort by Type ---------Max----------Avg----------Min----------Cur---------Percent---------\\n"
			,"AREA:num_all#00FF00:Total     "
			,"GPRINT:num_all_raw:MAX:%11.0lf"
			,"GPRINT:num_all_raw:AVERAGE:%11.0lf"
			,"GPRINT:num_all_raw:MIN:%11.0lf"
			,"GPRINT:num_all_raw:LAST:%11.0lf          100%%\\n"

#                ,"AREA:num_ok#008000:Normal"
#                ,"LINE2:num_in#6666CC:Received"
#                ,"LINE2:num_out#CC9966:Sent"
#                ,"LINE2:num_virus#FF0000:Virus"
#                ,"LINE2:num_spam#FFFF00:Spam"
#                ,"LINE2:num_content#FF00FF:MatchRule"
#                ,"LINE2:num_overrun#0000FF:Overrun"
#                ,"LINE2:num_archive#00FFFF:Archive"

			,"LINE2:num_in#6666CC:Received  "
			,"GPRINT:num_in_raw:MAX:%11.0lf"
			,"GPRINT:num_in_raw:AVERAGE:%11.0lf"
			,"GPRINT:num_in_raw:MIN:%11.0lf"
			,"GPRINT:num_in_raw:LAST:%11.0lf"
			,"GPRINT:num_in_percent:LAST:%11lg%%\\n"


			,"LINE2:num_out#CC9966:Sent      "
			,"GPRINT:num_out_raw:MAX:%11.0lf"
			,"GPRINT:num_out_raw:AVERAGE:%11.0lf"
			,"GPRINT:num_out_raw:MIN:%11.0lf"
			,"GPRINT:num_out_raw:LAST:%11.0lf"
			,"GPRINT:num_out_percent:LAST:%11lg%%\\n"
			,"COMMENT:\\n"

			,"AREA:num_ok#008000:Normal    "
			,"GPRINT:num_ok_raw:MAX:%11.0lf"
			,"GPRINT:num_ok_raw:AVERAGE:%11.0lf"
			,"GPRINT:num_ok_raw:MIN:%11.0lf"
			,"GPRINT:num_ok_raw:LAST:%11.0lf"
			,"GPRINT:num_ok_percent:LAST:%11lg%%\\n"
			,"COMMENT:\\n"



			,"LINE2:num_virus#FF0000:Virus     "
			,"GPRINT:num_virus_raw:MAX:%11.0lf"
			,"GPRINT:num_virus_raw:AVERAGE:%11.0lf"
			,"GPRINT:num_virus_raw:MIN:%11.0lf"
			,"GPRINT:num_virus_raw:LAST:%11.0lf"
			,"GPRINT:num_virus_percent:LAST:%11lg%%\\n"

			,"LINE2:num_spam#FFFF00:Spam      "
			,"GPRINT:num_spam_raw:MAX:%11.0lf"
			,"GPRINT:num_spam_raw:AVERAGE:%11.0lf"
			,"GPRINT:num_spam_raw:MIN:%11.0lf"
			,"GPRINT:num_spam_raw:LAST:%11.0lf"
			,"GPRINT:num_spam_percent:LAST:%11lg%%\\n"

			,"LINE2:num_content#FF00FF:MatchRule "
			,"GPRINT:num_content_raw:MAX:%11.0lf"
			,"GPRINT:num_content_raw:AVERAGE:%11.0lf"
			,"GPRINT:num_content_raw:MIN:%11.0lf"
			,"GPRINT:num_content_raw:LAST:%11.0lf"
			,"GPRINT:num_content_percent:LAST:%11lg%%\\n"

			,"LINE2:num_overrun#0000FF:Overrun   "
			,"GPRINT:num_overrun_raw:MAX:%11.0lf"
			,"GPRINT:num_overrun_raw:AVERAGE:%11.0lf"
			,"GPRINT:num_overrun_raw:MIN:%11.0lf"
			,"GPRINT:num_overrun_raw:LAST:%11.0lf"
			,"GPRINT:num_overrun_percent:LAST:%11lg%%\\n"

			,"LINE2:num_archive#00FFFF:Audit     "
			,"GPRINT:num_archive_raw:MAX:%11.0lf"
			,"GPRINT:num_archive_raw:AVERAGE:%11.0lf"
			,"GPRINT:num_archive_raw:MIN:%11.0lf"
			,"GPRINT:num_archive_raw:LAST:%11.0lf"
			,"GPRINT:num_archive_percent:LAST:%11lg%%\\n"

			,'COMMENT:\n'
			,"HRULE:0#000000:Last Updated: "
			,"COMMENT:$now\\n"
		);

#"CDEF:correct_tot_mem=tot_mem,0,671744,LIMIT,UN,0,tot_mem,IF,1024,/",\
#"CDEF:machine_mem=tot_mem,656,+,tot_mem,-",\
	my $err=RRDs::error;
	if ($err) {print "problem generating the graph: $err\n";}
}

1;



