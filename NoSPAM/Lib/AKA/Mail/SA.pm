#
# SpamAssassin·´À¬»øÅÐ¶ÏÒýÇæ
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

	$self->{parent} = $parent;
	$self->{conf} = $parent->{conf} || new AKA::Mail::Conf;#die "Mail::Conf can't get parent conf!"; 
	$self->{zlog} = $parent->{zlog} || new AKA::Mail::Log;#die "Mail::Conf can't get parent zlog!"; 

	$self->init();

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
	my $sa_result = $self->sa_result( $status );

	$status->finish();    # added by jm to allow GC'ing
	$mail->finish();

	return $sa_result;
}

sub sa_result
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

	$result->{TESTS} = $status->_get_tag('TESTS','£¬');
	$result->{TESTSSCORES} = $status->_get_tag('TESTSSCORES','£¬');
	
	return $result;
}

1;
