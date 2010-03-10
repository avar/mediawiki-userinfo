package MediaWiki::USERINFO;
use 5.10.0;
use autodie ':all';
use Moose;
use MooseX::StrictConstructor;
use MooseX::Types::Moose qw<Bool Str ArrayRef HashRef>;
use File::Slurp;
use YAML::Syck qw(Load Dump);
BEGIN { $YAML::Syck::ImplicitUnicode = 1 }
use File::Temp qw(tempdir);
use File::Spec::Functions qw(catfile catdir);
use MediaWiki::USERINFO::User;
use List::MoreUtils qw(firstval uniq);
use namespace::clean -except => 'meta';

with 'MooseX::Getopt::Dashes';

has userinfo_dir => (
    isa => Str,
    is => 'ro',
    lazy_build => 1,
    documentation => 'Path to MediaWiki USERINFO directory. Default: Check it out from svn to temporary directory ',
);

sub _build_userinfo_dir {
    my ($self) = @_;

    my $tmpdir = tempdir( CLEANUP => 1 );
    system "svn co --quiet http://svn.wikimedia.org/svnroot/mediawiki/USERINFO $tmpdir";

    return $tmpdir;
}

has all_commiters => (
    isa => Str,
    is => 'ro',
    documentation => "Path to a file produced with `git log --pretty=format:%an | sort | uniq'",
);

has all_commiters_data => (
    traits => [ qw(NoGetopt) ],
    isa => ArrayRef,
    is => 'ro',
    auto_deref => 1,
    lazy_build => 1,
);

sub _build_all_commiters_data {
    my ($self) = @_;
    my $file = $self->all_commiters;

    chomp(my @users = read_file($file));

    return \@users;
}

has users => (
    traits => [ qw(NoGetopt) ],
    isa => ArrayRef,
    is => 'ro',
    auto_deref => 1,
    lazy_build => 1,
);

sub _build_users {
    my ($self) = @_;

    opendir my $dir, $self->userinfo_dir;
    my @users = sort { $a cmp $b } grep { -f catfile($self->userinfo_dir, $_) } readdir $dir;
    closedir $dir;

    return \@users;
}

has all_users => (
    traits => [ qw(NoGetopt) ],
    isa => ArrayRef,
    is => 'ro',
    auto_deref => 1,
    lazy_build => 1,
);

sub _build_all_users {
    my ($self) = @_;

    return [ uniq($self->users, $self->all_commiters_data) ];
}

has users_data => (
    traits => [ qw(NoGetopt) ],
    isa => HashRef,
    is => 'ro',
    auto_deref => 1,
    lazy_build => 1,
);

sub _build_users_data {
    my ($self) = @_;

    my @users = $self->users;
    my %users;

    for my $user (@users) {
        my $file = catfile($self->userinfo_dir, $user);
        my $data = $self->_parse_userinfo($file);

        $users{$user} = MediaWiki::USERINFO::User->new(
            user => $user,
            data => $data,
        );
    }

    return \%users;
}

sub find_user {
    my ($self, $needle) = @_;

    my %users = $self->users_data;
    return firstval { $_->user eq $needle or $_->is_alias_of($needle) } values %users;
}

# Getopt stuff
has help => (
    isa           => Bool,
    is            => 'ro',
    default       => 0,
    documentation => 'This help message',
);

has print_users => (
    traits        => [qw(Getopt)],
    cmd_flag      => 'users',
    documentation => 'Print a list of known users',
    isa           => Bool,
    is            => 'ro',
);

has print_user_info => (
    traits        => [qw(Getopt)],
    cmd_flag      => 'user-info',
    documentation => 'Dump known info for a given user',
    isa           => Str,
    is            => 'ro',
);

has print_spew_env_filter => (
    traits        => [qw(Getopt)],
    cmd_flag      => 'spew-env-filter',
    documentation => "Dump a program for use with git filter-branch's --env-filter command",
    isa           => Bool,
    is            => 'ro',
);

sub run {
    my ($self) = @_;

    if ($self->print_users) {
        say for $self->users;
        return;
    }

    if (my $name = $self->print_user_info) {
        if (my $user = $self->find_user($name)) {
            my %info = (
                user => $user->user,
                name => $user->name,
                email => $user->email,
                aliases => [ $user->aliases ],
            );
            
            print Dump(\%info); 
            return;
        } else {
            say STDERR "Can't find user $name";
        }
    }

    if ($self->print_spew_env_filter) {
        say $self->get_filter_program;
    }
}

sub get_filter_program {
    my ($self) = @_;

    my @all_users = $self->all_users;
    my $str;

    $str .= <<"PROGRAM";
#!/usr/bin/env perl
use 5.10.0;
use utf8;
use strict;


my \$an = \$ENV{GIT_COMMITER_NAME\};
my \$am;

given (\$an) {
PROGRAM

    for my $u (@all_users) {
        my $v = $self->find_user($u);

        next unless $v;

        my $user  = $v->user;
        my $name  = $v->name  // $user;
        my $email = $v->email // '';

        $str .= <<"PROGRAM"
    when (q[$u]) {
        \$an = q[$name];
        \$am = q[$email]
    }
PROGRAM
    }

    $str .= <<"PROGRAM";
}

\$ENV{GIT_COMMITER_NAME}  = \$an if \$an;
\$ENV{GIT_COMMITER_EMAIL} = \$am if \$am;
PROGRAM

    return $str;
    
}

sub _read_file {
    my ($self, $file) = @_;
    open my $fh, '<:encoding(utf8)', $file;
    my $cont = join '', <$fh>;
    close $fh;
    return $cont;
}

sub _parse_userinfo {
    my ($self, $file) = @_;
    my $cont = $self->_read_file($file);
    my $ret = Load($cont);
    return $ret;
}

__PACKAGE__->meta->make_immutable;

=head1 NAME

MediaWiki::USERINFO - Parse the F<USERINFO/> files in MediaWiki's Subversion repository

=head1 DESCRIPTION

MediaWiki's subversion repository contains a
L<USERINFO|http://svn.wikimedia.org/svnroot/mediawiki/USERINFO/>
directory. This module knows how to parse files therein, look up
usernames (or aliases), de-obfuscate the C<email:> field in the
USERINFO files and more.

See the F<t/userinfo.t> test file in the distribution for what it can
do. This module was mainly written to find out what users were missing
USERINFO files (or essential fields) for the proposed MediaWiki -> Git
conversion.

This module can generate a program to be used with C<git filter-branch
--env-filter> to rename svn users in a C<git svn> generated MediaWiki
repository to real names/email pairs.

=head1 AUTHOR

E<AElig>var ArnfjE<ouml>rE<eth> Bjarmason <avar@cpan.org>

=head1 LICENSE AND COPYRIGHT

Copyright 2010 E<AElig>var ArnfjE<ouml>rE<eth> Bjarmason <avar@cpan.org>

This program is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
