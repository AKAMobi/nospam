#
# SpamAssassin反垃圾判断引擎
# Company: AKA Information & Technology Co., Ltd.
# Author: Ed Li
# EMail: zixia@zixia.net
# Date: 2004-06-06


package AKA::Mail::SA;
use strict;

use AKA::Mail::Conf;
use AKA::Mail::Log;
use Mail::SpamAssassin;

use lib '/usr/lib/perl5/site_perl/5.8.0';                   # substituted at 'make' time

#BEGIN {    # added by jm for use inside the distro
#  if ( -e '../blib/lib/Mail/SpamAssassin.pm' ) {
#    unshift ( @INC, '../blib/lib' );
#  }
#  else {
#    unshift ( @INC, '../lib' );
#  }
#}

sub new
{
	my $class = shift;

	my $self = {};
	bless $self, $class;

	my $parent = shift;
	my $need_init = shift;

	$self->{parent} = $parent;
	$self->{conf} = $parent->{conf} || new AKA::Mail::Conf;#die "Mail::Conf can't get parent conf!"; 
	$self->{zlog} = $parent->{zlog} || new AKA::Mail::Log;#die "Mail::Conf can't get parent zlog!"; 

	$self->{define}->{spamassassin_cf_dir} = "/usr/share/spamassassin";
	$self->{define}->{spamassassin_cf_file} = "/etc/mail/spamassassin/local.cf";

	$self->init() if ( $need_init );

	return $self;
}


sub init
{
	my $self = shift;

	$self->{spamtest} ||= Mail::SpamAssassin->new(
  		{
    			dont_copy_prefs      => 1,
    			rules_filename       => 0,
    			site_rules_filename  => 0,
    			local_tests_only     => 0,
    			debug                => 6,
    			paranoid             => 0,
    			home_dir_for_helpers => '/home/NoSPAM/sa',
    			PREFIX          => '/usr/',
    			DEF_RULES_DIR   => '/usr/share/spamassassin',
    			LOCAL_RULES_DIR => '/etc/mail/spamassassin'
  		}
	);

	$self->{spamtest}->compile_now(0,0);  # ensure all modules etc. are loaded
	$/ = "\n";                    # argh, Razor resets this!  Bad Razor!

	# bayes DBs will be tied() at this point, so untie them and such.
	$self->{spamtest}->finish_learner();
}

sub get_result {
	my $self = shift;
	my $emlfile = shift;

	my $sa_result = eval { $self->check($emlfile); };

	if (!defined ($sa_result)) {
		$self->{zlog}->fatal("SA error: $@ $!");
	}

	return $sa_result;
}

sub check {
	my $self = shift;
	my $emlfile = shift;

	#TODO

	unless (open(EML,"<$emlfile")){
		$self->{zlog}->fatal ("SA::check open file[$emlfile] failed!");
		return undef;
	}

	# Now parse *only* the message headers; the MIME tree won't be generated 
	# yet, check() will do this on demand later on.
	my $mail = $self->{spamtest}->parse(\*EML, 0);

	close (EML);

	# Extract the Message-Id(s) for logging purposes.
	my $msgid  = $mail->get_pristine_header("Message-Id");
	my $rmsgid = $mail->get_pristine_header("Resent-Message-Id");
	foreach my $id ((\$msgid, \$rmsgid)) {
		if ( $$id ) {
			while ( $$id =~ s/\([^\(\)]*\)// )
			{ }                            # remove comments and
			$$id =~ s/^\s+|\s+$//g;          # leading and trailing spaces
				$$id =~ s/\s+/ /g;               # collapse whitespaces
				$$id =~ s/^.*?<(.*?)>.*$/$1/;    # keep only the id itself
				$$id =~ s/[^\x21-\x7e]/?/g;      # replace all weird chars
				$$id =~ s/[<>]/?/g;              # plus all dangling angle brackets
				$$id =~ s/^(.+)$/<$1>/;          # re-bracket the id (if not empty)
		}
	}

	$msgid        ||= "(unknown)";

	# Go ahead and check the message
	my $status = $self->{spamtest}->check($mail);
	my $sa_result = $self->get_sa_result( $status );

	$status->finish();    # added by jm to allow GC'ing
	$mail->finish();

	return $sa_result;
}

sub get_sa_result
{
	my $self = shift;
	my $status = shift;

	my @tags = qw /SCORE REQD VERSION SUBVERSION BAYES 
			TOKENSUMMARY BAYESTC BAYESTCLEARNED 
			BAYESTCSPAMMY BAYESTCHAMMY AWL DATE 
			AUTOLEARN DCCB DCCR PYZOR RBL 
			LANGUAGES REPORT SUMMARY /;

	my $result = {};
	foreach ( @tags ){
		$result->{$_} = $status->_get_tag($_,'');
	}

	$result->{TESTS} = $status->_get_tag('TESTS',' ');
	$result->{TESTSSCORES} = $status->_get_tag('TESTSSCORES',' ');
	
	return $result;
}


sub get_disabled_rules
{
	my $self = shift;

	my $disabled_rules = {};

	my $rules = $self->_SA_get_all_rulename();
	foreach my $rule ( keys %{$rules} ){
		foreach ( @{$self->{conf}->{config}->{SpamEngine}->{DisabledTests}} ){
			if ( $rule=~/^$_/ ){
				$disabled_rules->{$rule} = 1;
				last;
			}
		}
	}
	return keys %{$disabled_rules};
}

sub _SA_get_all_rulename
{
	my $self = shift;

	my $rules = {};

	my $spamassassin_cf_dir = $self->{define}->{spamassassin_cf_dir};

	opendir (DIR,$spamassassin_cf_dir) or die "opendir";
	foreach my $cf ( readdir(DIR) ){
		next if ( $cf!~/^\d+_.+\.cf$/ );
		my $cf_rules = $self->_SA_load_rule_from_cf("$spamassassin_cf_dir/$cf");
		foreach ( keys %{$cf_rules} ){
			$rules->{$_} = 1;
		}
	}
	closedir (DIR);

	return $rules;
}

sub _SA_load_rule_from_cf
{
	my $self = shift;

	my $file = shift;

	my $rules = {};
	open ( CF, "<$file" ) or return undef;
	while ( <CF> ){
		chomp;
		if ( /\S+\s+([A-Z]\S+[A-Z])\s+/ ){
			$rules->{$1} = 1;
		}
	}
	close CF;
	return $rules;
}

sub get_local_cf_content
{
	my $self = shift;

	my $spamconf = $self->{conf}->{config}->{SpamEngine};
	my $saconf = $self->{conf}->{intsaconf};

	my @disabled_rules = $self->get_disabled_rules();


	my $conf_map = {
		BayesEnabled	=> 'use_bayes'
			,BayesMinSpamKnowledge	=> 'bayes_min_ham_num'
			,BayesMinNonSpamKnowledge 	=> 'bayes_min_spam_num'

			,BayesAutoLearn	=> 'bayes_auto_learn'
			,BayesAutoLearnNonSpamScore	=> 'bayes_auto_learn_threshold_nonspam'
			,BayesAutoLearnSpamScore	=> 'bayes_auto_learn_threshold_spam'

			,RBLDisabled	=> 'skip_rbl_checks'
			,RBLTimeout	=> 'rbl_timeout'

			,DCCEnabled	=> 'use_dcc'
			,DCCTimeout	=> 'dcc_timeout'
			,DCCBodyMax	=> 'dcc_body_max'
			,DCCFuz1Max	=> 'dcc_fuz1_max'
			,DCCFuz2Max	=> 'dcc_fuz2_max'

			,PyzorEnabled	=> 'use_pyzor'
			,PyzorTimeout	=> 'pyzor_timeout'
			,PyzorMax	=> 'pyzor_max'

			,RazorEnabled	=> 'use_razor2'
			,RazorTimeout	=> 'razor_timeout'

			,AWLEnabled	=> 'use_auto_whitelist'
			,AWLFactor	=> 'auto_whitelist_factor'
	};


	my $local_cf_hash = {};
	my $local_cf_content;

	# 出厂设置的 SA SCORE 值
	my $factory_score;

	my ($key,$val);

	# 提取所有出厂设置的 SA SCORE
	while ( ($key,$val)=each %{$saconf} ){
		if ( $key eq 'FactoryScore' ){
			$factory_score = $val;
			next;
		}
		$local_cf_hash->{$key} = $val;
	}

	# 对NoSPAM.conf中的和SpamAssassin相关的配置进行转换
	while ( ($key,$val)=each %{$spamconf} ){
		if ( defined $conf_map->{$key} ){
			$local_cf_hash->{$conf_map->{$key}} = _get_conf_bool($val);
		}

	}

	$local_cf_content = "";
	while ( ($key,$val)=each %{$local_cf_hash} ){
		$local_cf_content .= "$key $val\n";
	}

	foreach ( split(/,/,$factory_score) ){
		$local_cf_content .= "score $1 $2\n"
			if ( /(\S+)#(\d+)/ );
	}

	foreach ( @disabled_rules ){
		$local_cf_content .= "score $_ 0\n"
	}

	return $local_cf_content;

# TODO
#,RBLUserList=rbl.nospam.cn#demo,rbl.nospam
#	,BayesIgnoreHeader
#	,BayesIgnoreFrom=
#	,BayesIgnoreTo=

	sub _get_conf_bool
	{
		my $val = shift;
		return 1 if ( uc $val eq 'Y' );
		return 0 if ( uc $val eq 'N' );
		return $val;
	}
}
1;
