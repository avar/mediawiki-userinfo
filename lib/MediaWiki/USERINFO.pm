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
use List::MoreUtils qw(firstval);
use namespace::clean -except => 'meta';

our $VERSION = '0.01';

with 'MooseX::Getopt::Dashes';

has userinfo => (
    isa => Str,
    is => 'ro',
    lazy_build => 1,
    documentation => 'Path to MediaWiki USERINFO directory. Default: Check it out from svn to temporary directory ',
);

sub _build_userinfo {
    my ($self) = @_;

    my $tmpdir = tempdir( CLEANUP => 1 );
    system "svn co --quiet http://svn.wikimedia.org/svnroot/mediawiki/USERINFO $tmpdir";

    return $tmpdir;
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

    opendir my $dir, $self->userinfo;
    my @users = sort { $a cmp $b } grep { -f catfile($self->userinfo, $_) } readdir $dir;
    closedir $dir;

    return \@users;
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
        my $file = catfile($self->userinfo, $user);
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
