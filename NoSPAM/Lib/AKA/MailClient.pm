#!/usr/bin/perl -w

package AKA::MailClient;


use IO::Socket();

sub new
{
	my $class = shift;

	my $self = {};

	bless $self, $class;

	my $parent = shift;

	return $self;
}

sub net_process
{
	my $self = shift;
	my $mail_info = shift;

        my $socket = IO::Socket::INET->new(Proto =>"tcp",
                                Timeout => 10,
                                PeerAddr =>'127.0.0.1',
                                PeerPort =>40307
                                 ) ;

        unless ( $socket && $socket->connected ){
                return undef;
        }

	print $socket ($mail_info->{aka}->{RELAYCLIENT}?1:0) . "\n";
	print $socket $mail_info->{aka}->{TCPREMOTEIP} . "\n";
	print $socket $mail_info->{aka}->{TCPREMOTEINFO} . "\n";
	print $socket $mail_info->{aka}->{emlfilename} . "\n";
	print $socket $mail_info->{aka}->{fd1}  . "\n";

	$mail_info->{aka}->{resp}->{smtp_code} = <$socket>;
	chomp $mail_info->{aka}->{resp}->{smtp_code};

	$mail_info->{aka}->{resp}->{smtp_info} = <$socket>;
	chomp $mail_info->{aka}->{resp}->{smtp_info};

	$mail_info->{aka}->{resp}->{exit_code} = <$socket>;
	chomp $mail_info->{aka}->{resp}->{exit_code};
	
	close $socket;

	$mail_info;
}

1;
