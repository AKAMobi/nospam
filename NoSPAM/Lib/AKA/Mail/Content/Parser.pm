#
# 北京互联网接警中心邮件过滤器
# Company: AKA Information & Technology Co., Ltd.
# Author: Ed Lee
# EMail: zixia@zixia.net
# Date: 2004-02-10

package AKA::Mail::Content::Parser;

use MIME::Parser;
use AKA::Mail::Log;
use AKA::Mail::Content::Conf;
# for parse received line date
use Date::Parse;

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

	my ($parent) = @_;

	$self->{parent} = $parent;

	$self->{zlog} = $parent->{zlog} || new AKA::Mail::Log($self) ;
	$self->{content_conf} = $parent->{content_conf} || new AKA::Mail::Content::Conf($self) ;
	$self->{mime_parser} ||= new MIME::Parser;

	# FIXME: $a = $b || $c not work??
	my $tmpdir = $self->{content_conf}->{define}->{tmpdir} || "/home/NoSPAM/spool/tmp/";
	#$self->{zlog}->debug ( "setting outputdir to $tmpdir" );

	$self->{mime_parser}->output_dir($tmpdir);
	$self->{mime_parser}->output_prefix("AMCF");

	$self->{prefix} = "AMCF";


	# 文件类型
	$self->{filetype}->{compress} = [ 'zip','rar',
					  'tgz', 'gz','bz2' ];
	$self->{filetype_num}->{compress} = 1;

	$self->{filetype}->{sound} = [ 'mp3', 'wav', 'wmv' ];
	$self->{filetype_num}->{sound} = 2;

	$self->{filetype}->{picture} = [ 'jpg', 'jpeg', 'gif', 'pcx' ];
	$self->{filetype_num}->{picture} = 3;

	$self->{filetype}->{text} = [ 'txt' ];
	$self->{filetype_num}->{text} = 4;

	$self->{filetype}->{exe} = [ 'exe', 'com', 'bat', 'pif', 'scr', 'vbs' ];
	$self->{filetype_num}->{exe} = 5;

	$self->load_user_filetype;

	return $self;
}

sub load_user_filetype
{
	my $self = shift;
	
	my $type_file = $self->{content_conf}->{define}->{user_filetype}; 

	if ( ! open ( FD, "<$type_file" ) ){
		$self->{zlog}->fatal( "Parser: open user_filetype [ $type_file ] failure!" );
		return;
	}


	# 第一行是已用的最大号码
	<FD>;

	my ( $num, $type, $exts, @exts );
	while ( <FD> ){
		chomp;
		next if ( /^$/ );
		( $num, $type, $exts ) = split ( /\t/ );
		unless ( $num && $type && $exts ){
			$self->{zlog}->fatal ( "Parser: can't parse filetype line: [$_]" );
			next;
		}
		@exts = split( /,/, $exts );
		$self->{filetype}->{$type} = \@exts;
		$self->{filetype_num}->{$type} = $num;
	}
	close ( FD );

	return;
}

sub get_mail_info
{
	my ($self, $fh) = @_;

	if ( defined $self->{mail_info} ){ return $self->{mail_info}; }

	my ( $type, $subtype, $body_content );

	my $entity = $self->{mime_parser}->parse($fh);
	$self->{entity} = $entity;

	&get_head_info( $self,$entity->head );

       
	my @Parts = $entity->parts;
        
	$partnum = @Parts;
        
	if ( $partnum > 0 ){
		foreach my $blob (@Parts) {
			&get_body_info( $self,$blob );
		}
	}else{
		&get_body_info( $self, $entity );	
	}
     	   
	foreach my $filename ( keys %{$self->{mail_info}->{body}} ){
		if ( ( ! defined $self->{mail_info}->{body}->{$filename}->{nofilename} ) ||
			( 0 == $self->{mail_info}->{body}->{$filename}->{nofilename}  ) ){
			$self->{mail_info}->{attachment} = 1;
			last;
		}
	}

	return $self->{mail_info};
}

sub print
{
	my ($self, $fh) = @_;

	if ( ! defined $self->{mime_parser} ) { return; }

	$self->{entity}->print($fh);

	# 只能 print 一次
	$self->clean;
	undef $self->{mail_info};
	undef $self->{entity};
}

sub clean
{
	my $self = shift;

	undef $self->{mail_info};
	undef $self->{entity};

	if ( $self->{mime_parser} ){
		$self->{mime_parser}->filer->purge;
	}

#	if ( $self->{entity} ){
#		$self->{entity}->purge;
#	}

}

sub get_head_info
{
	my ($self, $head) = @_;

	if ( ! defined $head ){
		$slef->{zlog}->fatal( "error: get_head_info no head found?" );;
		return;
	}

	#FIXME: here make a copy of head instead of make change of original entity;
	#my $head_decoded = $head;
	#$head = $head_decoded;
	#undef $head_decoded;

	$head->decode;
	$head->unfold;

	# now we get decoded content
	my $content = $head->stringify || "";
	$self->{mail_info}->{head}->{content} = $content;
	$self->{mail_info}->{head_size} = length( $content );


	# TO/CC/BCC 总共接收的人数
	my ($to,$from,$cc,$bcc);
	my $num_receivers = 0;

	$from = $head->get('From') || '';
	$from =~ s/\n$//;
	$self->{mail_info}->{head}->{from} = $from;

	$to = $head->get('To') || '';
	$to =~ s/\n$//;
	$self->{mail_info}->{head}->{to} = $to; 
	$num_receivers += scalar (@_=
					split(/,/,$to)
				);

	$cc = $head->get('CC') || '';
	$self->{mail_info}->{head}->{cc} = $cc;
	$num_receivers += scalar (@_=
					split(/,/,$cc)
				);

	$bcc = $head->get('BCC') || '';
	$self->{mail_info}->{head}->{bcc} = $bcc;
	$num_receivers += scalar (@_=
					split(/,/,$bcc)
				);

	# get all to+cc+bcc
	$self->{mail_info}->{head}->{to_cc_bcc_num} = $num_receivers;

	# get addtional receivers, such as Apparently-To,  For forwarded messages, Resent-To, Resent-Cc, Resent-Bcc.
	$self->{mail_info}->{head}->{to_cc_bcc_num} += $self->get_additional_receiver_num( $head );


	$self->{mail_info}->{head}->{subject} = $head->get('Subject');
	chomp $self->{mail_info}->{head}->{subject};

	# FIXME 正确取得 sender_ip & server_ip
	my @receiveds = $head->get("Received");
	my $server_ip = 1;
	my $relay;
	for ( @receiveds ){
		if ( /(\d+\.\d+\.\d+\.\d+)/ ){
			if ( $server_ip ){
				$self->{mail_info}->{head}->{server_ip} = $1;
				$self->{mail_info}->{head}->{sender_ip} = $1;
				$server_ip = 0;
			}else{
				$self->{mail_info}->{head}->{sender_ip} = $1;
			}
		}
		$relay = $self->parse_received_line($_);

		push (@{$self->{mail_info}->{relays}}, $relay) if ( $relay );
	}
}

# get addtional receivers, such as Apparently-To,  For forwarded messages, Resent-To, Resent-Cc, Resent-Bcc.
sub get_additional_receiver_num
{
	my $self = shift;
	my $head = shift;

	my $receivers;
	my $num = 0;

	my @headers = ( 'Apparently-To', 'Resent-To', 'Resent-Cc', 'Resent-Bcc' );

	foreach my $header ( @headers ){
		$receivers = $head->get($header) || '';
		$num += scalar (@_=
					split(/,/,$receivers)
				);
	}

	return $num;
}

sub get_body_info
{
        my ($self, $blob, $load_binary) = @_;

	$load_binary ||= 0;

	my ($path,$filename,$size,$type,$subtype);


        ($type, $subtype) = split('/', $blob->head->mime_type);

        my $disposition = $blob->head->mime_attr("Content-Disposition");

        my $head = $blob->head;

	# FIXME: here make a copy of head instead of make change of original entity;
	#my $head_decoded = $head;
	#$head = $head_decoded;
	#undef $head_decoded;

        $head->decode;

        my $body = $blob->bodyhandle;

	my $prefix;

        if ($body = $blob->bodyhandle) {
                if (defined $disposition && $disposition =~ /attachment/) {
                        #$self->{zlog}->debug ("    Atachment: " . $body->path );
                }
                $path = $body->path;

                $filename = $head->recommended_filename ;
                $size = ($path ? (-s $path) : 0);

                if ( !defined $filename ){
                        $filename = $path;
			$prefix = $self->{prefix} || "AMCF";

                        $filename =~ s/^.*\/$prefix\-//g;
			$self->{mail_info}->{body}->{$filename}->{nofilename} = 1;
                }else{
			$self->{mail_info}->{attachment_size} += $size;
			$self->{mail_info}->{attachment_num}++;
			$self->{mail_info}->{body}->{$filename}->{nofilename} = 0;
		}

		$type ||= "text";
		$subtype ||= "plain";

		$self->{mail_info}->{body}->{$filename}->{path} = $path;
		$self->{mail_info}->{body}->{$filename}->{type} = $type;
		$self->{mail_info}->{body}->{$filename}->{subtype} = $subtype;
		
		if ( $type eq "text" || $filename=~/\.txt$/ ) { #&& $subtype eq "plain") {
			$_ = load_file ( $self, $path, $size );
			$self->{mail_info}->{body}->{$filename}->{content} = $_;
			$self->{mail_info}->{body_text} .= $_;
		} elsif ( 1 == $load_binary ){
			$self->{mail_info}->{body}->{$filename}->{content} = load_file ( $self,$path, $size );
		}


		$self->{mail_info}->{body}->{$filename}->{size} = $size;

		#FIXME: 获取编码的body size
		$self->{mail_info}->{body_size} += $size;
			
		# 获取文件类型
		$self->{mail_info}->{body}->{$filename}->{typeclass} = get_attachment_type( $self,$filename );

        } else {  
                foreach my $part ($blob->parts) {
                        &get_body_info( $self,$part );
                }
        }

}

sub get_attachment_type
{
	my $self = shift;
	
	my $filename = shift;

	my $i;
	my $filetype_num;

	foreach my $filetype ( keys %{$self->{filetype_num}} ){
		$filetype_num = $self->{filetype_num}->{$filetype};
		foreach ( @{$self->{filetype}->{$filetype}} ){
			if ( $filename =~ /$_$/ ){
				return $filetype_num;
			}
		}
	}
			
	# 其他类型文件
	return 6;
}

sub load_file
{
	my ($self,$path,$size) = @_;
	
	my $data;
	$data = ' ' x $size;

	open ( FD, "<$path" ) or return "";
	binmode FD;
	read ( FD, $data, $size );
	close ( FD );

	return $data;
}


sub parse_received_line {
  my ($self) = shift;
  local ($_) = shift;

  s/\s+/ /gs;
  my $ip = '';
  my $helo = '';
  my $rdns = '';
  my $by = '';
  my $receive_time = '';
  my $ident = '';
  my $mta_looked_up_dns = 0;

  # Received: (qmail 27981 invoked by uid 225); 14 Mar 2003 07:24:34 -0000
  # Received: (qmail 84907 invoked from network); 13 Feb 2003 20:59:28 -0000
  # Received: (ofmipd 208.31.42.38); 17 Mar 2003 04:09:01 -0000
  # we don't care about this kind of gateway noise
  if (/^\(/) { return; }

my $RECEIVE_TIME = qr{(?:
                  [^;]*;\s+(.+)
                )}ixo;

  if ( /$RECEIVE_TIME$/ ){
  	$receive_time = str2time($1);
  }#else{
  #	$receive_time = localtime(time);
  #}

  # OK -- given knowledge of most Received header formats,
  # break them down.  We have to do something like this, because
  # some MTAs will swap position of rdns and helo -- so we can't
  # simply use simplistic regexps.

my $IP_ADDRESS = qr/\b (?:IPv6:|) (?: (?:0*:0*:ffff:(?:0*:|)|) # IPv4-mapped-in-IPv6
                    (?:1\d\d|2[0-4]\d|25[0-5]|\d\d|\d)\.
                    (?:1\d\d|2[0-4]\d|25[0-5]|\d\d|\d)\.
                    (?:1\d\d|2[0-4]\d|25[0-5]|\d\d|\d)\.
                    (?:1\d\d|2[0-4]\d|25[0-5]|\d\d|\d)
                  | # an IPv6 address, seems to always be at least 6 words
                    [a-f0-9]{0,4} \:[a-f0-9]{0,4}
                    \:[a-f0-9]{0,4} \:[a-f0-9]{0,4}
                    \:[a-f0-9]{0,4} \:[a-f0-9]{0,4} (?:\:[a-f0-9]{0,4})*
                  )\b/ix;

my $LOCALHOST = qr{(?:
                  localhost(?:\.localdomain|)|
                  127\.0\.0\.1|
                  ::ffff:127\.0\.0\.1
                )}ixo;


my $IP_IN_RESERVED_RANGE = qr{^(?:
  10|                              # 10.0.0.0/8:          Private-Use Networks (see RFC3330) 
  127|                             # 127/8:               Loopback (see RFC3330) 
  128\.0|                          # 128.0/16:            Reserved (subject to allocation) (see RFC3330) 
  169\.254|                        # 169.254/16:          Link Local (APIPA) (see RFC3330) 
  172\.(?:1[6-9]|2[0-9]|3[01])|    # 172.16-172.31/16:    Private-Use Networks (see RFC3330) 
  191\.255|                        # 191.255/16:          Reserved (subject to allocation) (see RFC3330) 
  192\.0\.0|                       # 192.0.0/24:          Reserved (subject to allocation) (see RFC3330) 
  192\.0\.2|                       # 192.0.2/24:          Test-Net (see RFC3330) 
  192\.88\.99|                     # 192.88.99/24:        6to4 Relay Anycast (see RFC3330) 
  192\.168|                        # 192.168.0.0/16:      Private-Use Networks (see RFC3330) 
  198\.1[89]|                      # 198.18.0.0/15:       Device Benchmark Testing (see RFC3330) 
  223\.255\.255|                   # 223.255.255.0/24:    Reserved (subject to allocation) (see RFC3330) 
  [01257]|                         # 0/8:                 "This" Network (see RFC3330) 
                                   # 1-2/8, 5/8, 7/8:     IANA Reserved 

  2[37]|                           # 23/8, 27/8:          IANA Reserved 
  3[1679]|                         # 31/8, 36/8, 37/8:    IANA Reserved 
                                   # 39/8:                Reserved (subject to allocation) (see RFC3330) 
  4[12]|                           # 41/8, 42/8:          IANA Reserved   
  5[89]|                           # 58/8, 59/8:          IANA Reserved   
  7[0-9]|                          # 70-79/8:             IANA Reserved    
  8[3-9]|                          # 83-89/8:             IANA Reserved   
  9[0-9]|                          # 90-99/8:             IANA Reserved   
  1[01][0-9]|                      # 100-119/8:           IANA Reserved   
  12[0-6]|                         # 120-126/8:           IANA Reserved   
  17[3-9]|                         # 173-179/8:           IANA Reserved   
  18[0-7]|                         # 180-187/8:           IANA Reserved   
  189|                             # 189/8:               IANA Reserved   
  19[07]|                          # 190/8, 197/8:        IANA Reserved   
  223|                             # 223/8:               IANA Reserved   
  22[4-9]|                         # 224-229/8:           Multicast (see RFC3330)  
  23[0-9]|                         # 230-239/8:           Multicast (see RFC3330)  
  24[0-9]|                         # 240-249/8:           Reserved for Future Use (see RFC3330) 
  25[0-5]                          # 250-255/8:           Reserved for Future Use (see RFC3330) 

)\.}x;


  if (/^from /) {
    if (/Exim/) {
      # one of the HUGE number of Exim formats :(
      # This must be scriptable.

      # Received: from [61.174.163.26] (helo=host) by sc8-sf-list1.sourceforge.net with smtp (Exim 3.31-VA-mm2 #1 (Debian)) id 18t2z0-0001NX-00 for <razor-users@lists.sourceforge.net>; Wed, 12 Mar 2003 01:57:10 -0800
      # Received: from [218.19.142.229] (helo=hotmail.com ident=yiuhyotp) by yzordderrex with smtp (Exim 3.35 #1 (Debian)) id 194BE5-0005Zh-00; Sat, 12 Apr 2003 03:58:53 +0100
      if (/^from \[(${IP_ADDRESS})\] \((.*?)\) by (\S+) /) {
	$ip = $1; my $sub = $2; $by = $3;
	$sub =~ s/helo=(\S+)// and $helo = $1;
	$sub =~ s/ident=(\S+)// and $ident = $1;
	goto enough;
      }

      # Received: from sc8-sf-list1-b.sourceforge.net ([10.3.1.13] helo=sc8-sf-list1.sourceforge.net) by sc8-sf-list2.sourceforge.net with esmtp (Exim 3.31-VA-mm2 #1 (Debian)) id 18t301-0007Bh-00; Wed, 12 Mar 2003 01:58:13 -0800
      # Received: from dsl092-072-213.bos1.dsl.speakeasy.net ([66.92.72.213] helo=blazing.arsecandle.org) by sc8-sf-list1.sourceforge.net with esmtp (Cipher TLSv1:DES-CBC3-SHA:168) (Exim 3.31-VA-mm2 #1 (Debian)) id 18lyuU-0007TI-00 for <SpamAssassin-talk@lists.sourceforge.net>; Thu, 20 Feb 2003 14:11:18 -0800
      # Received: from eclectic.kluge.net ([66.92.69.221] ident=[W9VcNxE2vKxgWHD05PJbLzIHSxcmZQ/O]) by sc8-sf-list1.sourceforge.net with esmtp (Cipher TLSv1:DES-CBC3-SHA:168) (Exim 3.31-VA-mm2 #1 (Debian)) id 18m0hT-00031I-00 for <spamassassin-talk@lists.sourceforge.net>; Thu, 20 Feb 2003 16:06:00 -0800
      if (/^from (\S+) \(\[(${IP_ADDRESS})\] helo=(\S+) ident=(\S+)\) by (\S+) /) {
	$rdns=$1; $ip = $2; $helo = $3; $ident = $4; $by = $5; goto enough;
      }
      # (and without ident)
      if (/^from (\S+) \(\[(${IP_ADDRESS})\] helo=(\S+)\) by (\S+) /) {
	$rdns=$1; $ip = $2; $helo = $3; $by = $4; goto enough;
      }

      # Received: from mail.ssccbelen.edu.pe ([216.244.149.154]) by yzordderrex
      # with esmtp (Exim 3.35 #1 (Debian)) id 18tqiz-000702-00 for
      # <jm@example.com>; Fri, 14 Mar 2003 15:03:57 +0000
      if (/^from (\S+) \(\[(${IP_ADDRESS})\]\) by (\S+) /) {
	# speculation: Exim uses this format when rdns==helo. TODO: verify fully
	$rdns= $1; $ip = $2; $helo = $1; $by = $3; goto enough;
      }
      if (/^from (\S+) \(\[(${IP_ADDRESS})\] ident=(\S+)\) by (\S+) /) {
	$rdns= $1; $ip = $2; $helo = $1; $ident = $3; $by = $4; goto enough;
      }

      # Received: from boggle.ihug.co.nz [203.109.252.209] by grunt6.ihug.co.nz
      # with esmtp (Exim 3.35 #1 (Debian)) id 18SWRe-0006X6-00; Sun, 29 Dec 
      # 2002 18:57:06 +1300
      if (/^from (\S+) \[(${IP_ADDRESS})\] by (\S+) /) {
	$rdns= $1; $ip = $2; $helo = $1; $by = $3; goto enough;
      }

      # else it's probably forged. fall through
    }

    # Received: from ns.elcanto.co.kr (66.161.246.58 [66.161.246.58]) by
    # mail.ssccbelen.edu.pe with SMTP (Microsoft Exchange Internet Mail Service
    # Version 5.5.1960.3) id G69TW478; Thu, 13 Mar 2003 14:01:10 -0500
    if (/^from (\S+) \((\S+) \[(${IP_ADDRESS})\]\) by (\S+) with \S+ \(/) {
      $mta_looked_up_dns = 1;
      $rdns= $2; $ip = $3; $helo = $1; $by = $4; goto enough;
    }

    # from mail2.detr.gsi.gov.uk ([51.64.35.18] helo=ahvfw.dtlr.gsi.gov.uk) by mail4.gsi.gov.uk with smtp id 190K1R-0000me-00 for spamassassin-talk-admin@lists.sourceforge.net; Tue, 01 Apr 2003 12:33:46 +0100
    if (/^from (\S+) \(\[(${IP_ADDRESS})\](.*)\) by (\S+) with /) {
      $rdns = $1; $ip = $2; $by = $4;
      my $sub = ' '.$3.' ';
      if ($sub =~ / helo=(\S+) /) { $helo = $1; }
      goto enough;
    }

    # from 12-211-5-69.client.attbi.com (<unknown.domain>[12.211.5.69]) by rwcrmhc53.attbi.com (rwcrmhc53) with SMTP id <2002112823351305300akl1ue>; Thu, 28 Nov 2002 23:35:13 +0000
    if (/^from (\S+) \(<unknown\S*>\[(${IP_ADDRESS})\]\) by (\S+) /) {
      $helo = $1; $ip = $2; $by = $3;
      goto enough;
    }

    # from attbi.com (h000502e08144.ne.client2.attbi.com[24.128.27.103]) by rwcrmhc53.attbi.com (rwcrmhc53) with SMTP id <20030222193438053008f7tee>; Sat, 22 Feb 2003 19:34:39 +0000
    if (/^from (\S+) \((\S+\.\S+)\[(${IP_ADDRESS})\]\) by (\S+) /) {
      $mta_looked_up_dns = 1;
      $helo = $1; $rdns = $2; $ip = $3; $by = $4;
      goto enough;
    }

    # sendmail:
    # Received: from mail1.insuranceiq.com (host66.insuranceiq.com [65.217.159.66] (may be forged)) by dogma.slashnull.org (8.11.6/8.11.6) with ESMTP id h2F0c2x31856 for <jm@jmason.org>; Sat, 15 Mar 2003 00:38:03 GMT
    # Received: from BAY0-HMR08.adinternal.hotmail.com (bay0-hmr08.bay0.hotmail.com [65.54.241.207]) by dogma.slashnull.org (8.11.6/8.11.6) with ESMTP id h2DBpvs24047 for <webmaster@efi.ie>; Thu, 13 Mar 2003 11:51:57 GMT
    # Received: from ran-out.mx.develooper.com (IDENT:qmailr@one.develooper.com [64.81.84.115]) by dogma.slashnull.org (8.11.6/8.11.6) with SMTP id h381Vvf19860 for <jm-cpan@jmason.org>; Tue, 8 Apr 2003 02:31:57 +0100
    # from rev.net (natpool62.rev.net [63.148.93.62] (may be forged)) (authenticated) by mail.rev.net (8.11.4/8.11.4) with ESMTP id h0KKa7d32306 for <spamassassin-talk@lists.sourceforge.net>
    if (/^from (\S+) \((\S+) \[(${IP_ADDRESS})\].*\) by (\S+) \(/) {
      $mta_looked_up_dns = 1;
      $helo = $1; $rdns = $2; $ip = $3; $by = $4;
      $rdns =~ s/^IDENT:([^\@]+)\@// and $ident = $1; # remove IDENT lookups
      $rdns =~ s/^([^\@]+)\@// and $ident = $1;	# remove IDENT lookups
      goto enough;
    }

    if (/ \(Postfix\) with/) {
      # Received: from localhost (unknown [127.0.0.1])
      # by cabbage.jmason.org (Postfix) with ESMTP id A96E18BD97
      # for <jm@localhost>; Thu, 13 Mar 2003 15:23:15 -0500 (EST)
      if ( /^from (\S+) \((\S+) \[(${IP_ADDRESS})\]\) by (\S+) / ) {
	$mta_looked_up_dns = 1;
	$helo = $1; $rdns = $2; $ip = $3; $by = $4;
	if ($rdns eq 'unknown') { $rdns = ''; }
	goto enough;
      }

      # Received: from 207.8.214.3 (unknown[211.94.164.65])
      # by puzzle.pobox.com (Postfix) with SMTP id 9029AFB732;
      # Sat,  8 Nov 2003 17:57:46 -0500 (EST)
      # (Pobox.com version: reported in bug 2745)
      if ( /^from (\S+) \((\S+)\[(${IP_ADDRESS})\]\) by (\S+) / ) {
	$mta_looked_up_dns = 1;
	$helo = $1; $rdns = $2; $ip = $3; $by = $4;
	if ($rdns eq 'unknown') { $rdns = ''; }
	goto enough;
      }
    }

    # Received: from 213.123.174.21 by lw11fd.law11.hotmail.msn.com with HTTP;
    # Wed, 24 Jul 2002 16:36:44 GMT
    if (/by (\S+\.hotmail\.msn\.com) /) {
      $by = $1;
      /^from (\S+) / and $ip = $1;
      goto enough;
    }

    # MiB (Michel Bouissou, 2003/11/16)
    # Moved some tests up because they might match on qmail tests, where this
    # is not qmail
    #
    # Received: from imo-m01.mx.aol.com ([64.12.136.4]) by eagle.glenraven.com
    # via smtpd (for [198.85.87.98]) with SMTP; Wed, 08 Oct 2003 16:25:37 -0400
    if (/^from (\S+) \(\[(${IP_ADDRESS})\]\) by (\S+) via smtpd \(for \S+\) with SMTP\(/) {
      $helo = $1; $ip = $2; $by = $3; goto enough;
    }

    # Try to match most of various qmail possibilities
    #
    # General format:
    # Received: from postfix3-2.free.fr (HELO machine.domain.com) (foobar@213.228.0.169) by totor.bouissou.net with SMTP; 14 Nov 2003 08:05:50 -0000
    #
    # "from (remote.rDNS|unknown)" is always there
    # "(HELO machine.domain.com)" is there only if HELO differs from remote rDNS
    # "foobar@" is remote IDENT info, specified only if ident given by remote
    # Remote IP always appears between (parentheses), with or without IDENT@
    # "by local.system.domain.com" always appears
    #
    # Protocol can be different from "SMTP", i.e. "RC4-SHA encrypted SMTP" or "QMQP"
    # qmail's reported protocol shouldn't be "ESMTP", so by allowing only "with (.* )(SMTP|QMQP)"
    # we should avoid matching on some sendmailish Received: lines that reports remote IP
    # between ([218.0.185.24]) like qmail-ldap does, but use "with ESMTP".
    #
    # Normally, qmail-smtpd remote IP isn't between square brackets [], but some versions of
    # qmail-ldap seem to add square brackets around remote IP. These versions of qmail-ldap
    # use a longer format that also states the (envelope-sender <sender@domain>) and the
    # qmail-ldap version. Example:
    # Received: from unknown (HELO terpsichore.farfalle.com) (jdavid@[216.254.40.70]) (envelope-sender <jdavid@farfalle.com>) by mail13.speakeasy.net (qmail-ldap-1.03) with SMTP for <jm@jmason.org>; 12 Feb 2003 18:23:19 -0000
    #
    # Some others of the numerous qmail patches out there can also add variants of their own
    #
    if (/^from \S+( \(HELO \S+\))? \((\S+\@)?\[?${IP_ADDRESS}\]?\)( \(envelope-sender <\S+>\))? by \S+( \(.+\))* with (.* )?(SMTP|QMQP)/) {

       if (/^from (\S+) \(HELO (\S+)\) \((\S+)\@\[?(${IP_ADDRESS})\]?\)( \(envelope-sender <\S+>\))? by (\S+)/) {
          $rdns = $1; $helo = $2; $ident = $3; $ip = $4; $by = $6;
       }
       elsif (/^from (\S+) \(HELO (\S+)\) \(\[?(${IP_ADDRESS})\]?\)( \(envelope-sender <\S+>\))? by (\S+)/) {
          $rdns = $1; $helo = $2; $ip = $3; $by = $5;
       }
       elsif (/^from (\S+) \((\S+)\@\[?(${IP_ADDRESS})\]?\)( \(envelope-sender <\S+>\))? by (\S+)/) {
          $rdns = $1; $ident = $2; $ip = $3; $by = $5;
       }
       elsif (/^from (\S+) \(\[?(${IP_ADDRESS})\]?\)( \(envelope-sender <\S+>\))? by (\S+)/) {
          $rdns = $1; $ip = $2; $by = $4;
       }
       # qmail doesn't perform rDNS requests by itself, but is usually called
       # by tcpserver or a similar daemon that passes rDNS information to qmail-smtpd.
       # If qmail puts something else than "unknown" in the rDNS field, it means that
       # it received this information from the daemon that called it. If qmail-smtpd
       # writes "Received: from unknown", it means that either the remote has no
       # rDNS, or qmail was called by a daemon that didn't gave the rDNS information.
       if ($rdns ne "unknown") {
          $mta_looked_up_dns = 1;
       }
       goto enough;

    }
    # /MiB
    
    # Received: from [193.220.176.134] by web40310.mail.yahoo.com via HTTP;
    # Wed, 12 Feb 2003 14:22:21 PST
    if (/^from \[(${IP_ADDRESS})\] by (\S+) via HTTP\;/) {
      $ip = $1; $by = $2; goto enough;
    }

    # Received: from 192.168.5.158 ( [192.168.5.158]) as user jason@localhost by mail.reusch.net with HTTP; Mon, 8 Jul 2002 23:24:56 -0400
    if (/^from (\S+) \( \[(${IP_ADDRESS})\]\).*? by (\S+) /) {
      # TODO: is $1 helo?
      $ip = $2; $by = $3; goto enough;
    }

    # Received: from (64.52.135.194 [64.52.135.194]) by mail.unearthed.com with ESMTP id BQB0hUH2 Thu, 20 Feb 2003 16:13:20 -0700 (PST)
    if (/^from \((\S+) \[(${IP_ADDRESS})\]\) by (\S+) /) {
      $helo = $1; $ip = $2; $by = $3; goto enough;
    }

    # Received: from [65.167.180.251] by relent.cedata.com (MessageWall 1.1.0) with SMTP; 20 Feb 2003 23:57:15 -0000
    if (/^from \[(${IP_ADDRESS})\] by (\S+) /) {
      $ip = $1; $by = $2; goto enough;
    }

    # Received: from acecomms [202.83.84.95] by mailscan.acenet.net.au [202.83.84.27] with SMTP (MDaemon.PRO.v5.0.6.R) for <spamassassin-talk@lists.sourceforge.net>; Fri, 21 Feb 2003 09:32:27 +1000
    if (/^from (\S+) \[(${IP_ADDRESS})\] by (\S+) \[(\S+)\] with /) {
      $mta_looked_up_dns = 1;
      $helo = $1; $ip = $2;
      $by = $4; # use the IP addr for "by", more useful?
      goto enough;
    }

    # Received: from mail.sxptt.zj.cn ([218.0.185.24]) by dogma.slashnull.org
    # (8.11.6/8.11.6) with ESMTP id h2FH0Zx11330 for <webmaster@efi.ie>;
    # Sat, 15 Mar 2003 17:00:41 GMT
    if (/^from (\S+) \(\[(${IP_ADDRESS})\]\) by (\S+) \(/) { # sendmail
      $mta_looked_up_dns = 1;
      $helo = $1; $ip = $2; $by = $3; goto enough;
    }

    # Received: from umr-mail7.umr.edu (umr-mail7.umr.edu [131.151.1.64]) via ESMTP by mrelay1.cc.umr.edu (8.12.1/) id h06GHYLZ022481; Mon, 6 Jan 2003 10:17:34 -0600
    # Received: from Agni (localhost [::ffff:127.0.0.1]) (TLS: TLSv1/SSLv3, 168bits,DES-CBC3-SHA) by agni.forevermore.net with esmtp; Mon, 28 Oct 2002 14:48:52 -0800
    # Received: from gandalf ([4.37.75.131]) (authenticated bits=0) by herald.cc.purdue.edu (8.12.5/8.12.5/herald) with ESMTP id g9JLefrm028228 for <spamassassin-talk@lists.sourceforge.net>; Sat, 19 Oct 2002 16:40:41 -0500 (EST)
    if (/^from (\S+) \((\S+) \[(${IP_ADDRESS})\]\).*? by (\S+) /) { # sendmail
      $mta_looked_up_dns = 1;
      $helo = $1; $rdns = $2; $ip = $3; $by = $4; goto enough;
    }
    if (/^from (\S+) \(\[(${IP_ADDRESS})\]\).*? by (\S+) /) {
      $mta_looked_up_dns = 1;
      $helo = $1; $ip = $2; $by = $3; goto enough;
    }

    # Received: from roissy (p573.as1.exs.dublin.eircom.net [159.134.226.61])
    # (authenticated bits=0) by slate.dublin.wbtsystems.com (8.12.6/8.12.6)
    # with ESMTP id g9MFWcvb068860 for <jm@jmason.org>;
    # Tue, 22 Oct 2002 16:32:39 +0100 (IST)
    if (/^from (\S+) \((\S+) \[(${IP_ADDRESS})\]\)(?: \(authenticated bits=\d+\)|) by (\S+) \(/) { # sendmail
      $mta_looked_up_dns = 1;
      $helo = $1; $rdns = $2; $ip = $3; $by = $4; goto enough;
    }

    # Received: from cabbage.jmason.org [127.0.0.1]
    # by localhost with IMAP (fetchmail-5.9.0)
    # for jm@localhost (single-drop); Thu, 13 Mar 2003 20:39:56 -0800 (PST)
    if (/^from (\S+) \[(${IP_ADDRESS})\] by (\S+) with IMAP \(fetchmail/) {
      $rdns = $1; $ip = $2; $by = $3; goto enough; 
    }

    # Received: from [129.24.215.125] by ws1-7.us4.outblaze.com with http for
    # _bushisevil_@mail.com; Thu, 13 Feb 2003 15:59:28 -0500
    if (/^from \[(${IP_ADDRESS})\] by (\S+) with http for /) {
      $ip = $1; $by = $2; goto enough;
    }

    # Received: from po11.mit.edu [18.7.21.73]
    # by stark.dyndns.tv with POP3 (fetchmail-5.9.7)
    # for stark@localhost (single-drop); Tue, 18 Feb 2003 10:43:09 -0500 (EST)
    # by po11.mit.edu (Cyrus v2.1.5) with LMTP; Tue, 18 Feb 2003 09:49:46 -0500
    if (/^from (\S+) \[(${IP_ADDRESS})\] by (\S+) with POP3 /) {
      $rdns = $1; $ip = $2; $by = $3; goto enough;
    }

    # Received: from snake.corp.yahoo.com(216.145.52.229) by x.x.org via smap (V1.3)
    # id xma093673; Wed, 26 Mar 03 20:43:24 -0600
    if (/^from (\S+)\((${IP_ADDRESS})\) by (\S+) via smap /) {
      $mta_looked_up_dns = 1;
      $rdns = $1; $ip = $2; $by = $3; goto enough;
    }

    # Received: from [192.168.0.71] by web01-nyc.clicvu.com (Post.Office MTA
    # v3.5.3 release 223 ID# 0-64039U1000L100S0V35) with SMTP id com for
    # <x@x.org>; Tue, 25 Mar 2003 11:42:04 -0500
    if (/^from \[(${IP_ADDRESS})\] by (\S+) \(Post/) {
      $ip = $1; $by = $2; goto enough;
    }

    # Received: from [127.0.0.1] by euphoria (ArGoSoft Mail Server 
    # Freeware, Version 1.8 (1.8.2.5)); Sat, 8 Feb 2003 09:45:32 +0200
    if (/^from \[(${IP_ADDRESS})\] by (\S+) \(ArGoSoft/) {
      $ip = $1; $by = $2; goto enough;
    }

    # Received: from inet-vrs-05.redmond.corp.microsoft.com ([157.54.6.157]) by
    # INET-IMC-05.redmond.corp.microsoft.com with Microsoft SMTPSVC(5.0.2195.6624);
    # Thu, 6 Mar 2003 12:02:35 -0800
    if (/^from (\S+) \(\[(${IP_ADDRESS})\]\) by (\S+) with /) {
      $helo = $1; $ip = $2; $by = $3; goto enough;
    }

    # Received: from tthompson ([217.35.105.172] unverified) by
    # mail.neosinteractive.com with Microsoft SMTPSVC(5.0.2195.5329);
    # Tue, 11 Mar 2003 13:23:01 +0000
    if (/^from (\S+) \(\[(${IP_ADDRESS})\] unverified\) by (\S+) with Microsoft SMTPSVC/) {
      $helo = $1; $ip = $2; $by = $3; goto enough;
    }

    # Received: from 157.54.8.23 by inet-vrs-05.redmond.corp.microsoft.com
    # (InterScan E-Mail VirusWall NT); Thu, 06 Mar 2003 12:02:35 -0800
    if (/^from (${IP_ADDRESS}) by (\S+) \(InterScan/) {
      $ip = $1; $by = $2; goto enough;
    }

    # Received: from faerber.muc.de by slarti.muc.de with BSMTP (rsmtp-qm-ot 0.4)
    # for asrg@ietf.org; 7 Mar 2003 21:10:38 -0000
    if (/^from (\S+) by (\S+) with BSMTP/) {
      return;	# BSMTP != a TCP/IP handover, ignore it
    }

    # Received: from spike (spike.ig.co.uk [193.32.60.32]) by mail.ig.co.uk with
    # SMTP id h27CrCD03362 for <asrg@ietf.org>; Fri, 7 Mar 2003 12:53:12 GMT
    if (/^from (\S+) \((\S+) \[(${IP_ADDRESS})\]\) by (\S+) with /) {
      $mta_looked_up_dns = 1;
      $helo = $1; $rdns = $2; $ip = $3; $by = $4; goto enough;
    }

    # Received: from customer254-217.iplannetworks.net (HELO AGAMENON) 
    # (baldusi@200.69.254.217 with plain) by smtp.mail.vip.sc5.yahoo.com with
    # SMTP; 11 Mar 2003 21:03:28 -0000
    if (/^from (\S+) \(HELO (\S+)\) \((\S+).*?\) by (\S+) with /) {
      $mta_looked_up_dns = 1;
      $rdns = $1; $helo = $2; $ip = $3; $by = $4;
      $ip =~ s/([^\@]*)\@//g and $ident = $1;	# remove IDENT lookups
      goto enough;
    }

    # Received: from raptor.research.att.com (bala@localhost) by
    # raptor.research.att.com (SGI-8.9.3/8.8.7) with ESMTP id KAA14788 
    # for <asrg@example.com>; Fri, 7 Mar 2003 10:37:56 -0500 (EST)
    if (/^from (\S+) \((\S+\@\S+)\) by (\S+) \(/) { 
	$rdns = $1; $helo = $2; $by = $3;
	goto enough;
    }

    # Received: from mmail by argon.connect.org.uk with local (connectmail/exim) id 18tOsg-0008FX-00; Thu, 13 Mar 2003 09:20:06 +0000
    if (/^from (\S+) by (\S+) with local/) { 
	$helo = $1; $by = $2; $ip='127.0.0.1';
	goto enough;
    }

    # Received: from [192.168.1.104] (account nazgul HELO [192.168.1.104])
    # by somewhere.com (CommuniGate Pro SMTP 3.5.7) with ESMTP-TLS id 2088434;
    # Fri, 07 Mar 2003 13:05:06 -0500
    if (/^from \[(${IP_ADDRESS})\] \(account \S+ HELO (\S+)\) by (\S+) \(/) {
      $ip = $1; $helo = $2; $by = $3; goto enough;
    }

    # Received: from ([10.0.0.6]) by mail0.ciphertrust.com with ESMTP ; Thu,
    # 13 Mar 2003 06:26:21 -0500 (EST)
    if (/^from \(\[(${IP_ADDRESS})\]\) by (\S+) with /) {
      $ip = $1; $by = $2;
    }

    # Received: from ironport.com (10.1.1.5) by a50.ironport.com with ESMTP; 01 Apr 2003 12:00:51 -0800
    # Received: from dyn-81-166-39-132.ppp.tiscali.fr (81.166.39.132) by cpmail.dk.tiscali.com (6.7.018)
    # note: must be before 'Content Technologies SMTPRS' rule, cf. bug 2787
    if (/^from (\S+) \((${IP_ADDRESS})\) by (\S+) /) {
      $helo = $1; $ip = $2; $by = $3; goto enough;
    }

    # Received: from scv3.apple.com (scv3.apple.com) by mailgate2.apple.com (Content Technologies SMTPRS 4.2.1) with ESMTP id <T61095998e1118164e13f8@mailgate2.apple.com>; Mon, 17 Mar 2003 17:04:54 -0800
    if (/^from (\S+) \((\S+)\) by (\S+) \(/) {
      #return;		# useless without the $ip anyway!
      $helo = $1; $rdns = $2; $by = $3; goto enough;
    }

    # Received: from 01al10015010057.ad.bls.com ([90.152.5.141] [90.152.5.141])
    # by aismtp3g.bls.com with ESMTP; Mon, 10 Mar 2003 11:10:41 -0500
    if (/^from (\S+) \(\[(\S+)\] \[(\S+)\]\) by (\S+) with /) {
      # not sure what $3 is ;)
      $helo = $1; $ip = $2; $by = $4;
      goto enough;
    }

    # Received: from 206.47.0.153 by dm3cn8.bell.ca with ESMTP (Tumbleweed MMS
    # SMTP Relay (MMS v5.0)); Mon, 24 Mar 2003 19:49:48 -0500
    if (/^from (${IP_ADDRESS}) by (\S+) with /) {
      $ip = $1; $by = $2;
      goto enough;
    }

    # Received: from pobox.com (h005018086b3b.ne.client2.attbi.com[66.31.45.164])
    # by rwcrmhc53.attbi.com (rwcrmhc53) with SMTP id <2003031302165605300suph7e>;
    # Thu, 13 Mar 2003 02:16:56 +0000
    if (/^from (\S+) \((\S+)\[(${IP_ADDRESS})\]\) by (\S+) /) {
      $mta_looked_up_dns = 1;
      $helo = $1; $rdns = $2; $ip = $3; $by = $4; goto enough;
    }

    # Received: from [10.128.128.81]:50999 (HELO dfintra.f-secure.com) by fsav4im2 ([10.128.128.74]:25) (F-Secure Anti-Virus for Internet Mail 6.0.34 Release) with SMTP; Tue, 5 Mar 2002 14:11:53 -0000
    if (/^from \[(${IP_ADDRESS})\]\S+ \(HELO (\S+)\) by (\S+) /) {
      $ip = $1; $helo = $2; $by = $3; goto enough;
    }

    # Received: from 62.180.7.250 (HELO daisy) by smtp.altavista.de (209.228.22.152) with SMTP; 19 Sep 2002 17:03:17 +0000
    if (/^from (${IP_ADDRESS}) \(HELO (\S+)\) by (\S+) /) {
      $ip = $1; $helo = $2; $by = $3; goto enough;
    }

    # Received: from oemcomputer [63.232.189.195] by highstream.net (SMTPD32-7.07) id A4CE7F2A0028; Sat, 01 Feb 2003 21:39:10 -0500
    if (/^from (\S+) \[(${IP_ADDRESS})\] by (\S+) /) {
      $helo = $1; $ip = $2; $by = $3; goto enough;
    }

    # from nodnsquery(192.100.64.12) by herbivore.monmouth.edu via csmap (V4.1) id srcAAAyHaywy
    if (/^from (\S+)\((${IP_ADDRESS})\) by (\S+) /) {
      $rdns = $1; $ip = $2; $by = $3; goto enough;
    }

    # Received: from [192.168.0.13] by <server> (MailGate 3.5.172) with SMTP;
    # Tue, 1 Apr 2003 15:04:55 +0100
    if (/^from \[(${IP_ADDRESS})\] by (\S+) \(MailGate /) {
      $ip = $1; $by = $2; goto enough;
    }

    # Received: from jmason.org (unverified [195.218.107.131]) by ni-mail1.dna.utvinternet.net <B0014212518@ni-mail1.dna.utvinternet.net>; Tue, 11 Feb 2003 12:18:12 +0000
    if (/^from (\S+) \(unverified \[(${IP_ADDRESS})\]\) by (\S+) /) {
      $helo = $1; $ip = $2; $by = $3; goto enough;
    }

    # from 165.228.131.11 (proxying for 139.130.20.189) (SquirrelMail authenticated user jmmail) by jmason.org with HTTP
    if (/^from (\S+) \(proxying for (${IP_ADDRESS})\) \([A-Za-z][^\)]+\) by (\S+) with /) {
      $ip = $2; $by = $3; goto enough;
    }
    if (/^from (${IP_ADDRESS}) \([A-Za-z][^\)]+\) by (\S+) with /) {
      $ip = $1; $by = $2; goto enough;
    }

    # Received: from [212.87.144.30] (account seiz [212.87.144.30] verified) by x.imd.net (CommuniGate Pro SMTP 4.0.3) with ESMTP-TLS id 5026665 for spamassassin-talk@lists.sourceforge.net; Wed, 15 Jan 2003 16:27:05 +0100
    if (/^from \[(${IP_ADDRESS})\] \([^\)]+\) by (\S+) /) {
      $ip = $1; $by = $2; goto enough;
    }

    # Received: from mtsbp606.email-info.net (?dXqpg3b0hiH9faI2OxLT94P/YKDD3rQ1?@64.253.199.166) by kde.informatik.uni-kl.de with SMTP; 30 Apr 2003 15:06:29
    if (/^from (\S+) \((?:\S+\@)?(${IP_ADDRESS})\) by (\S+) with /) {
      $rdns = $1; $ip = $2; $by = $3; goto enough;
    }
  }

  # ------------------------------------------------------------------------
  # IGNORED LINES: generally local-to-local or non-TCP/IP handovers

  # from qmail-scanner-general-admin@lists.sourceforge.net by alpha by uid 7791 with qmail-scanner-1.14 (spamassassin: 2.41. Clear:SA:0(-4.1/5.0):. Processed in 0.209512 secs)
  if (/^from \S+\@\S+ by \S+ by uid \S+ /) { return; }

  # Received: from mail pickup service by mail1.insuranceiq.com with
  # Microsoft SMTPSVC; Thu, 13 Feb 2003 19:05:39 -0500
  if (/^from mail pickup service by (\S+) with Microsoft SMTPSVC;/) {
    return;
  }

  # Received: by x.x.org (bulk_mailer v1.13); Wed, 26 Mar 2003 20:44:41 -0600
  if (/^by (\S+) \(bulk_mailer /) { return; }

  # Received: from DSmith1204@aol.com by imo-m09.mx.aol.com (mail_out_v34.13.) id 7.53.208064a0 (4394); Sat, 11 Jan 2003 23:24:31 -0500 (EST)
  if (/^from \S+\@\S+ by \S+ /) { return; }

  # Received: from Unknown/Local ([?.?.?.?]) by mailcity.com; Fri, 17 Jan 2003 15:23:29 -0000
  if (/^from Unknown\/Local \(/) { return; }

  # Received: by SPIDERMAN with Internet Mail Service (5.5.2653.19) id <19AF8VY2>; Tue, 25 Mar 2003 11:58:27 -0500
  if (/^by \S+ with Internet Mail Service \(/) { return; }

  # Received: by oak.ein.cz (Postfix, from userid 1002) id DABBD1BED3;
  # Thu, 13 Feb 2003 14:02:21 +0100 (CET)
  if (/^by (\S+) \(Postfix, from userid /) { return; }

  # Received: from localhost (mailnull@localhost) by x.org (8.12.6/8.9.3) 
  # with SMTP id h2R2iivG093740; Wed, 26 Mar 2003 20:44:44 -0600 
  # (CST) (envelope-from x@x.org)
  # Received: from localhost (localhost [127.0.0.1]) (uid 500) by mail with local; Tue, 07 Jan 2003 11:40:47 -0600
  if (/^from ${LOCALHOST} \((?:\S+\@|)${LOCALHOST}[\) ]/) { return; }

  # Received: from olgisoft.com (127.0.0.1) by 127.0.0.1 (EzMTS MTSSmtp
  # 1.55d5) ; Thu, 20 Mar 03 10:06:43 +0100 for <asrg@ietf.org>
  if (/^from \S+ \((?:\S+\@|)${LOCALHOST}\) /) { return; }

  # Received: from casper.ghostscript.com (raph@casper [127.0.0.1]) h148aux8016336verify=FAIL); Tue, 4 Feb 2003 00:36:56 -0800
  # TODO: could use IPv6 localhost
  if (/^from (\S+) \(\S+\@\S+ \[127\.0\.0\.1\]\) /) { return; }

  # Received: from (AUTH: e40a9cea) by vqx.net with esmtp (courier-0.40) for <asrg@ietf.org>; Mon, 03 Mar 2003 14:49:28 +0000
  if (/^from \(AUTH: (\S+)\) by (\S+) with /) { return; }

  # Received: by faerber.muc.de (OpenXP/32 v3.9.4 (Win32) alpha @
  # 2003-03-07-1751d); 07 Mar 2003 22:10:29 +0000
  # ignore any lines starting with "by", we want the "from"s!
  if (/^by \S+ /) { return; }

  # Received: FROM ca-ex-bridge1.nai.com BY scwsout1.nai.com ;
  # Fri Feb 07 10:18:12 2003 -0800
  if (/^FROM \S+ BY \S+ \; /) { return; }

  # Received: from andrew by trinity.supernews.net with local (Exim 4.12)
  # id 18xeL6-000Dn1-00; Tue, 25 Mar 2003 02:39:00 +0000
  # Received: from CATHY.IJS.SI by CATHY.IJS.SI (PMDF V4.3-10 #8779) id <01KTSSR50NSW001MXN@CATHY.IJS.SI>; Fri, 21 Mar 2003 20:50:56 +0100
  # Received: from MATT_LINUX by hippo.star.co.uk via smtpd (for mail.webnote.net [193.120.211.219]) with SMTP; 3 Jul 2002 15:43:50 UT
  # Received: from cp-its-ieg01.mail.saic.com by cpmx.mail.saic.com for me@jmason.org; Tue, 23 Jul 2002 14:09:10 -0700
  if (/^from \S+ by \S+ (?:with|via|for|\()/) { return; }

  # Received: from virtual-access.org by bolero.conactive.com ; Thu, 20 Feb 2003 23:32:58 +0100
  if (/^from (\S+) by (\S+) *\;/) {
    return;	# can't trust this
  }

  # Received: Message by Barricade wilhelm.eyp.ee with ESMTP id h1I7hGU06122 for <spamassassin-talk@lists.sourceforge.net>; Tue, 18 Feb 2003 09:43:16 +0200
  if (/^Message by /) {
    return;	# whatever
  }

  # ------------------------------------------------------------------------
  # FALL-THROUGH: OK, let's try some general patterns
  if (/^from (\S+)[^-A-Za-z0-9\.]/) { $helo = $1; }
  if (/^helo=(\S+)[^-A-Za-z0-9\.]/) { $helo = $1; }
  if (/\[(${IP_ADDRESS})\]/) { $ip = $1; }
  if (/ by (\S+)[^-A-Za-z0-9\.]/) { $by = $1; }
  if ($ip && $by) { goto enough; }

  # ------------------------------------------------------------------------
  # OK, if we still haven't figured out at least the basics (IP and by), or
  # returned due to it being a known-crap format, let's warn so the user can
  # file a bug report or something.

  #dbg ("received-header: unknown format: $_");
  # and skip the line entirely!  We can't parse it...
  return;

  # ------------------------------------------------------------------------
  # OK, line parsed (at least partially); now deal with the contents

enough:

  # flag handovers we couldn't get an IP address from at all
  if ($ip eq '') {
    #dbg ("received-header: could not parse IP address from: $_");
  }

  $ip = $self->extract_ipv4_addr_from_string ($ip);
  if (!$ip) {
    #dbg ("received-header: could not parse IPv4 address, assuming IPv6");
    return;	# ignore IPv6 handovers
  }

  if ($ip eq '127.0.0.1') {
    #dbg ("received-header: ignoring localhost handover");
    return;	# ignore localhost handovers
  }

  if ($rdns =~ /^unknown$/i) {
    $rdns = '';		# some MTAs seem to do this
  }

  # ensure invalid chars are stripped.  Replace with '!' to flag their
  # presence, though.
  $ip =~ s/[\s\0\#\[\]\(\)\<\>\|]/!/gs;
  $rdns =~ s/[\s\0\#\[\]\(\)\<\>\|]/!/gs;
  $helo =~ s/[\s\0\#\[\]\(\)\<\>\|]/!/gs;
  $by =~ s/[\s\0\#\[\]\(\)\<\>\|]/!/gs;
  $ident =~ s/[\s\0\#\[\]\(\)\<\>\|]/!/gs;

  my $relay = {
    ip => $ip,
    by => $by,
    helo => $helo,
    ident => $ident,
    receive_time => $receive_time,
    lc_by => (lc $by),
    lc_helo => (lc $helo)
  };

  # as-string rep. use spaces so things like Bayes can tokenize them easily.
  # NOTE: when tokenizing or matching, be sure to note that new
  # entries may be added to this string later.   However, the *order*
  # of entries must be preserved, so that regexps that assume that
  # e.g. "ip" comes before "helo" will still work.
  #
  my $asstr = "[ ip=$ip rdns=$rdns helo=$helo by=$by ident=$ident time=$receive_time ]";
  $relay->{as_string} = $asstr;

  my $isrsvd = ($ip =~ /${IP_IN_RESERVED_RANGE}/o);
  $relay->{ip_is_reserved} = $isrsvd;

  return $relay;
}

sub extract_ipv4_addr_from_string {
  my ($self, $str) = @_;

  return unless defined($str);

  if ($str =~ /\b(
			(?:1\d\d|2[0-4]\d|25[0-5]|\d\d|\d)\.
			(?:1\d\d|2[0-4]\d|25[0-5]|\d\d|\d)\.
			(?:1\d\d|2[0-4]\d|25[0-5]|\d\d|\d)\.
			(?:1\d\d|2[0-4]\d|25[0-5]|\d\d|\d)
		      )\b/ix)
  {
    if (defined $1) { return $1; }
  }

  # ignore native IPv6 addresses; currently we have no way to deal with
  # these if we could extract them, as the DNSBLs don't provide a way
  # to query them!  TODO, eventually, once IPv6 spam starts to appear ;)
  return;
}


#sub DESTROY
#{
#	# 删除临时文件
#}

1;
