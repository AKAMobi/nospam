# AKA Information & Technology Co., Ltd.
# Ed Li 2004-03-28
# Common functions for parsing qmail config files

package AKA::Mail::MailControler;

#use strict;

use AKA::Mail::Log;

sub new
{
	my $class = shift;

	my $self = {};

	bless $self, $class;

	my $parent = shift;

	$self->{parent} = $parent;
#	$self->{zlog} = $parent->{zlog} || new AKA::Mail::Log; #die "AKA::IPUtil can't get parent zlog";

	$self->{define}->{qmail_dir} = '/var/qmail/';

	$self->{define}->{qmail_alias_dir} = $self->{define}->{'qmail_dir'} . '/alias';
	$self->{define}->{qmail_bin_dir} = $self->{define}->{'qmail_dir'} . "/bin";
	$self->{define}->{qmail_control_dir} = $self->{define}->{'qmail_dir'} . "/control";
	$self->{define}->{qmail_routes_file} = $self->{define}->{'qmail_control_dir'} . "/smtproutes";
	$self->{define}->{qmail_virts_file} = $self->{define}->{'qmail_control_dir'} . "/virtualdomains";
	$self->{define}->{qmail_start_cmd} = $self->{define}->{'qmail_dir'} . "/rc";
	$self->{define}->{qmail_mess_dir} = $self->{define}->{'qmail_dir'} . "/queue/mess";
	$self->{define}->{qmail_info_dir} = $self->{define}->{'qmail_dir'} . "/queue/info";
	$self->{define}->{qmail_local_dir} = $self->{define}->{'qmail_dir'} . "/queue/local";
	$self->{define}->{qmail_remote_dir} = $self->{define}->{'qmail_dir'} . "/queue/remote";
	$self->{define}->{qmail_assigns_file} = $self->{define}->{'qmail_dir'} . "/users/assign";

	return $self;
}

# list_aliases()
# Returns a list of qmail alias file names
sub list_aliases
{
	my $self = shift;

	my @rv;
	opendir(DIR, $self->{define}->{qmail_alias_dir});
	foreach my $f (readdir(DIR)) {
		next if ($f !~ /^\.qmail-(\S+)$/);
		push(@rv, $1);
	}
	closedir(DIR);
	return @rv;
}

# get_alias(name)
sub get_alias
{
	my $self = shift;

	my $alias = { 'name' => $_[0],
		'file' => $self->{define}->{qmail_alias_dir} . "/.qmail-$_[0]",
		'values' => [ ] };
		open(ALIAS, $alias->{'file'});
		while(<ALIAS>) {
			s/\r|\n//g;
			s/#.*$//g;
			if (/\S/) {
				push(@{$alias->{'values'}}, $_);
			}
		}
		close(ALIAS);
		return $alias;
}

# alias_type(string)
# Return the type and destination of some alias string
sub alias_type
{
	my $self = shift;
#TODO: module it. by zixia
	return 0;

=pod
		my @rv;
	if ($_[0] =~ /^\&(.*)/) {
		@rv = (1, $1);
	}
	elsif ($_[0] =~ /^\|$module_config_directory\/autoreply.pl\s+(\S+)/) {
		@rv = (5, $1);
	}
	elsif ($_[0] =~ /^\|$module_config_directory\/filter.pl\s+(\S+)/) {
		@rv = (6, $1);
	}
	elsif ($_[0] =~ /^\|(.*)$/) {
		@rv = (4, $1);
	}
	elsif ($_[0] =~ /^(\/.*)\/$/) {
		@rv = (2, $1);
	}
	elsif ($_[0] =~ /^(\/.*)$/) {
		@rv = (3, $1);
	}
	else {
		@rv = (1, $_[0]);
	}
	return wantarray ? @rv : $rv[0];
=cut
}

sub lock_file
{
	my $self = shift;

	my $filename = shift;

#$filename = $1 if ( $filename=~m#([^/]+)$# );

	if ( !open( LOCKFD, ">$filename.lock" ) ){
		$self->{zlog} && $self->{zlog}->debug("QmailContoler::lock_file can't get lock of $filename.lock");
		return 0;
	}

	use Fcntl ':flock'; # import LOCK_* constants

		if ( !flock(LOCKFD,LOCK_EX) ){
			return 0;
		}

	$self->{lock_tab}->{$filename} =  \*LOCKFD;

	return 1;
}

sub release_lock
{
	my $self = shift;

	my $filename = shift;

	return 0 unless ( defined $self->{lock_tab}->{$filename} );

	flock($self->{lock_tab}->{$filename}, LOCK_UN);
	undef $self->{lock_tab}->{$filename};

	return 1;
}

# create_alias(&alias)
# Creates a new qmail alias file
sub create_alias
{
	my $self = shift;

	my $f = $self->{define}->{qmail_alias_dir} . "/.qmail-$_[0]->{'name'}";
	$self->lock_file($f);
	open(FILE, ">$f");
	foreach my $v (@{$_[0]->{'values'}}) {
		print FILE $v,"\n";
	}
	close(FILE);
	$self->unlock_file($f);
}

# modify_alias(&old, &alias)
# Modifies an existing qmail alias
sub modify_alias
{
	my $self = shift;

	$self->lock_file($_[0]->{'file'});
	if ($_[0]->{'name'} ne $_[1]->{'name'}) {
		unlink($_[0]->{'file'});
		$self->unlock_file($_[0]->{'file'});
	}
	$self->create_alias($_[1]);
}

# delete_alias(&alias)
# Deletes an existing qmail alias file
sub delete_alias
{
	my $self = shift;

	$self->lock_file($_[0]->{'file'});
	unlink("$_[0]->{'file'}");
	$self->unlock_file($_[0]->{'file'});
}

# get_control_file(file)
# Returns the value from a qmail single-line control file
sub get_control_file
{
	my $self = shift;

	open(FILE, $self->{define}->{qmail_control_dir} . "/$_[0]") || return undef;
	my $line = <FILE>;
	close(FILE);
	$line =~ s/\r|\n//g;
	return $line;
}

# set_control_file(file, value)
# Sets the value in a qmail single-line control file
sub set_control_file
{
	my $self = shift;

	$self->lock_file($self->{define}->{qmail_control_dir} . "/$_[0]");
	if (defined($_[1])) {
		open(FILE, ">" . $self->{define}->{qmail_control_dir} . "/$_[0]");
		print FILE $_[1],"\n";
		close(FILE);
	}
	else {
		unlink($self->{define}->{qmail_control_dir} . "/$_[0]");
	}
	$self->unlock_file($self->{define}->{qmail_control_dir} . "/$_[0]");
}

# list_control_file()
# Returns the contents of a multi-line control file
sub list_control_file
{
	my $self = shift;

	my @lines;
	open(FILE, $self->{define}->{qmail_control_dir} . "/$_[0]") || return undef;
	while(<FILE>) {
		s/\r|\n//g;
		s/#.*$//g;
		push(@lines, $_) if (/\S/);
	}
	close(FILE);
	return \@lines;

}

# save_control_file(file, &lines)
# Saves the contents of a multi-line control file
sub save_control_file
{
	my $self = shift;

	$self->lock_file($self->{define}->{qmail_control_dir} . "/$_[0]");
	if (defined($_[1])) {
		open(FILE, ">" . $self->{define}->{qmail_control_dir} . "/$_[0]");
		foreach my $l (@{$_[1]}) {
			print FILE $l,"\n";
		}
		close(FILE);
	}
	else {
		unlink($self->{define}->{qmail_control_dir} . "/$_[0]");
	}
	$self->unlock_file($self->{define}->{qmail_control_dir} . "/$_[0]");
}

# list_routes()
# Returns a list of all SMTP routes
sub list_routes
{
	my $self = shift;

	my $lnum = 0;
	my @rv;
	open(ROUTES, $self->{define}->{qmail_routes_file});
	while(<ROUTES>) {
		s/\r|\n//g;
		s/#.*$//;
		if (/^(\S*):(\S*):(\d+)/) {
			push(@rv, { 'from' => $1,
					'to' => $2,
					'port' => $3,
					'idx' => scalar(@rv),
					'line' => $lnum });
		}
		elsif (/^(\S*):(\S*)/) {
			push(@rv, { 'from' => $1,
					'to' => $2,
					'idx' => scalar(@rv),
					'line' => $lnum });
		}
		$lnum++;
	}
	close(ROUTES);
	return @rv;
}

sub read_file_lines
{
	my $self = shift;

	if (!$self->{file_cache}->{$_[0]}) {
		my @lines;
		local $_;
		open(READFILE, $_[0]);
		while(<READFILE>) {
			s/\r|\n//g;
			push(@lines, $_);
		}
		close(READFILE);
		$self->{file_cache}->{$_[0]} = \@lines;
	}
	return $self->{file_cache}->{$_[0]};
}

# flush_file_lines()
sub flush_file_lines
{
	my $self = shift;

	foreach my $f (keys %{$self->{file_cache}}) {
		open(FLUSHFILE, "> $f");
		foreach my $line (@{$self->{file_cache}->{$f}}) {
			print FLUSHFILE $line,"\n";
		}
		close(FLUSHFILE);               
	}
	undef($self->{file_cache});
}                                       


# create_route(&route)
sub create_route
{
	my $self = shift;

	$self->lock_file($self->{define}->{qmail_routes_file});
	my $lref = $self->read_file_lines($self->{define}->{qmail_routes_file});
	push(@$lref, $_[0]->{'from'}.':'.$_[0]->{'to'}.
			($_[0]->{'port'} ? ':'.$_[0]->{'port'} : ''));
	$self->flush_file_lines();
	$self->unlock_file($self->{define}->{qmail_routes_file});
}

# modify_route(&old, &route)
sub modify_route
{
	my $self = shift;

	$self->lock_file($self->{define}->{qmail_routes_file});
	my $lref = $self->read_file_lines($self->{define}->{qmail_routes_file});
	splice(@$lref, $_[0]->{'line'}, 1,
			$_[1]->{'from'}.':'.$_[1]->{'to'}.
			($_[1]->{'port'} ? ':'.$_[1]->{'port'} : ''));
	$self->flush_file_lines();
	$self->unlock_file($self->{define}->{qmail_routes_file});
}

# delete_route(&route)
sub delete_route
{
	my $self = shift;

	$self->lock_file($self->{define}->{qmail_routes_file});
	my $lref = $self->read_file_lines($self->{define}->{qmail_routes_file});
	splice(@$lref, $_[0]->{'line'}, 1);
	$self->flush_file_lines();
	$self->unlock_file($self->{define}->{qmail_routes_file});
}

# list_virts()
# Returns a list of all virtualdomains file entries
sub list_virts
{
	my $self = shift;

	my $lnum = 0;
	my @rv;
	open(VIRTS, $self->{define}->{qmail_virts_file});
	while(<VIRTS>) {
		s/\r|\n//g;
		s/#.*$//;
		if (/^(\S+)\@(\S+):(\S*)/) {
			push(@rv, { 'user' => $1,
					'domain' => $2,
					'from' => "$1\@$2",
					'prepend' => $3,
					'line' => $lnum,
					'idx' => scalar(@rv) } );
		}
		elsif (/^(\S*):(\S*)/) {
			push(@rv, { 'domain' => $1,
					'from' => $1,
					'prepend' => $2,
					'line' => $lnum,
					'idx' => scalar(@rv) } );
		}
		$lnum++;
	}
	close(VIRTS);
	return @rv;
}

# create_virt(&virt)
sub create_virt
{
	my $self = shift;

	$self->lock_file($self->{define}->{qmail_virts_file});
	my $lref = $self->read_file_lines($self->{define}->{qmail_virts_file});
	push(@$lref, join(":", $_[0]->{'user'} ? "$_[0]->{'user'}\@$_[0]->{'domain'}"
				: $_[0]->{'domain'},
				$_[0]->{'prepend'}));
	$self->flush_file_lines();
	$self->unlock_file($self->{define}->{qmail_virts_file});
}

# delete_virt(&virt)
sub delete_virt
{
	my $self = shift;

	$self->lock_file($self->{define}->{qmail_virts_file});
	my $lref = $self->read_file_lines($self->{define}->{qmail_virts_file});
	splice(@$lref, $_[0]->{'line'}, 1);
	$self->flush_file_lines();
	$self->unlock_file($self->{define}->{qmail_virts_file});
}

# modify_virt(&old, &virt)
sub modify_virt
{
	my $self = shift;

	$self->lock_file($self->{define}->{qmail_virts_file});
	my $lref = $self->read_file_lines($self->{define}->{qmail_virts_file});
	splice(@$lref, $_[0]->{'line'}, 1,
			join(":", $_[1]->{'user'} ? "$_[1]->{'user'}\@$_[1]->{'domain'}"
				: $_[1]->{'domain'},
				$_[1]->{'prepend'}));
	$self->flush_file_lines();
	$self->unlock_file($self->{define}->{qmail_virts_file});
}

# list_queue()
# Returns an array of structures for entries in the mail queue
sub list_queue
{
	my $self = shift;

	my (@rv, %qmap);
	@rv = ( );
	opendir(DIR, $self->{define}->{qmail_mess_dir});
	foreach my $m (readdir(DIR)) {
		next if ($m !~ /^\d+$/);
		opendir(DIR2, $self->{define}->{qmail_mess_dir} . "/$m");
		foreach my $m2 (readdir(DIR2)) {
			$qmap{$m2} = $self->{define}->{qmail_mess_dir} . "/$m/$m2"
				if ($m2 =~ /^\d+$/);
		}
		closedir(DIR2);
	}
	closedir(DIR);
	open(QUEUE, $self->{define}->{qmail_bin_dir} . "/qmail-qread |");
	while(<QUEUE>) {
		if (/^(\d+)\s+(\S+)\s+(\d+)\s+(\d+):(\d+):(\d+)\s+(\S+)\s+#(\d+)\s+(\d+)\s+(.*)/) {
			my $q = { 'from' => $10,
				'id' => $8,
				'file' => $qmap{$8},
				'date' => "$1 $2 $3 $4:$5:$6" };
				$_ = <QUEUE>;
				if (/^\s*(\S+)\s+(.*)/) {
					$q->{'source'} = $1;
					$q->{'to'} = $2;
					push(@rv, $q);
				}
		}
	}
	close(QUEUE);
	return @rv;
}

# wrap_lines(text, width)
# Given a multi-line string, return an array of lines wrapped to
# the given width
sub wrap_lines
{
	my $self = shift;

	my @rv;
	my $w = $_[1];
	foreach my $rest (split(/\n/, $_[0])) {
		if ($rest =~ /\S/) {
			while($rest =~ /^(.{1,$w}\S*)\s*([\0-\377]*)$/) {
				push(@rv, $1);
				$rest = $2;
			}
		}
		else {
# Empty line .. keep as it is
			push(@rv, $rest);
		}
	}
	return @rv;
}

# link_urls(text)
sub link_urls
{
	my $self = shift;

	my $r = $_[0];
	$r =~ s/((http|ftp|https|mailto):[^><"'\s]+[^><"'\s\.])/<a href="$1">$1<\/a>/g;
	return $r;
}

# list_assigns()
# Returns a list of qmail user assignments
sub list_assigns
{
	my $self = shift;

	my @rv;
	my $lnum = 0;
	open(ASSIGNS, $self->{define}->{qmail_assigns_file});
	while(<ASSIGNS>) {
		s/\r|\n//g;
		last if ($_ eq '.');
		my @line = split(/:/, $_, 8);
		if ($line[0] =~ /^([\+=])(\S*)/) {
			my $asn = { 'address' => $2,
				'mode' => $1,
				'user' => $line[1],
				'uid' => $line[2],
				'gid' => $line[3],
				'home' => $line[4],
				'dash' => $line[5],
				'preext' => $line[6],
				'idx' => scalar(@rv),
				'line' => $lnum };
				push(@rv, $asn);
		}
		$lnum++;
	}
	close(ASSIGNS);
	return @rv;
}

# create_assign(&assign)
sub create_assign
{
	my $self = shift;

	$self->lock_file($self->{define}->{qmail_assigns_file});
	my $lref = $self->read_file_lines($self->{define}->{qmail_assigns_file});
	my $dot;
	for(my $i=0; $i<@$lref; $i++) {
		if ($lref->[$i] eq '.') {
			$dot++;
			last;
		}
	}
	splice(@$lref, my $i, 0, join(":", "$_[0]->{'mode'}$_[0]->{'address'}",
				$_[0]->{'user'}, $_[0]->{'uid'}, $_[0]->{'gid'},
				$_[0]->{'home'}, $_[0]->{'dash'},
				$_[0]->{'preext'}, ''));
	push(@$lref, ".") if (!$dot);
	$self->flush_file_lines();
	$self->unlock_file($self->{define}->{qmail_assigns_file});
}

# modify_assign(&old, &assign)
sub modify_assign
{
	my $self = shift;

	$self->lock_file($self->{define}->{qmail_assigns_file});
	my $lref = $self->read_file_lines($self->{define}->{qmail_assigns_file});
	$lref->[$_[0]->{'line'}] = join(":", "$_[1]->{'mode'}$_[1]->{'address'}",
			$_[1]->{'user'}, $_[1]->{'uid'}, $_[1]->{'gid'},
			$_[1]->{'home'}, $_[1]->{'dash'},
			$_[1]->{'preext'}, '');
	$self->flush_file_lines();
	$self->unlock_file($self->{define}->{qmail_assigns_file});
}

# delete_assign(&assign)
sub delete_assign
{
	my $self = shift;

	$self->lock_file($self->{define}->{qmail_assigns_file});
	my $lref = $self->read_file_lines($self->{define}->{qmail_assigns_file});
	splice(@$lref, $_[0]->{'line'}, 1);
	$self->flush_file_lines();
	$self->unlock_file($self->{define}->{qmail_assigns_file});
}

# user_mail_dir(username, ...)
# Returns the full path to a user's mail file or directory
sub user_mail_dir
{
	my $self = shift;
=pod

		if ($config{'mail_system'} == 1) {
			if (@_ > 1) {
				return "$_[7]/$config{'mail_dir_qmail'}/";
			}
			else {
				my @u = getpwnam($_[0]);
				return "$u[7]/$config{'mail_dir_qmail'}/";
			}
		}
		else {
			return &user_mail_file(@_);
		}
=cut
}

# restart_qmail()
# Tells qmail to reload its configuration files by sending a HUP signal
sub restart_qmail
{
	system('/usr/bin/svc -t /service/qmail');
}

sub delete_queues
{
	my $self = shift;

	$self->qmail_stop;

	#$id = "$1/$2";
	foreach my $id ( @_ ){
		unlink($self->{define}->{qmail_mess_dir} . "/$id");
		unlink($self->{define}->{qmail_info_dir} . "/$id");
		unlink($self->{define}->{qmail_remote_dir} . "/$id");
		unlink($self->{define}->{qmail_local_dir} . "/$id");
	}

	$self->qmail_start;
}

sub qmail_stop
{
	system ('/usr/bin/svc -d /service/qmail');
}

sub qmail_start
{
	system ('/usr/bin/svc -u /service/qmail');
}

sub qmail_restart
{
	system ('/usr/bin/svc -t /service/qmail');
}


sub find_byname
{
	my $self = shift;

	my($cmd, @pids);
	$cmd = "ps auwwwx | grep NAME | grep -v grep | awk '{ print $2 }'";
	$cmd =~ s/NAME/"$_[0]"/g;
	@pids = split(/\n/, `($cmd) </dev/null 2>/dev/null`);
	@pids = grep { $_ != $$ } @pids;
	return @pids;
} 
1;

