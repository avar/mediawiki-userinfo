package MediaWiki::USERINFO::User;
use 5.10.0;
use Moose;
use MooseX::StrictConstructor;
use MooseX::Types::Moose qw<Str HashRef ArrayRef>;
use namespace::clean -except => 'meta';

has user => (
    isa => Str,
    is => 'ro',
    required => 1,
);

has data => (
    isa => HashRef,
    is => 'ro',
    auto_deref => 1,
);

has aliases => (
    isa => ArrayRef,
    is => 'ro',
    auto_deref => 1,
    lazy_build => 1,
);

sub _build_aliases {
    my ($self) = @_;

    return [] unless exists $self->data->{aliases};
    return [  split /,\s*/, $self->data->{aliases} ]
}

sub is_alias_of {
    my ($self, $alias) = @_;

    return scalar grep { $alias eq $_ } $self->aliases;
}

sub name {
    my ($self) = @_;

    my $name = $self->data->{name};
    Encode::_utf8_on($name);
    return $name;
}

sub email {
    my ($self) = @_;

    return unless exists $self->data->{email};
    
    my $email = $self->data->{email};

    # Munge addresses of silly people
    $email =~ s/ [(<]?at?[>)]? /@/g;
    $email =~ s/ Who Is A User At The Host Called /@/;
    $email =~ s/ [(<]?dot[)>]? /./g;
    $email =~ s/ d0t /./g;
    $email =~ s/\@domain /@/;
    $email =~ s/\@the email provider /@/;

    if (($self->user // '') eq 'yurik') {
        my ($first, $last) = split / /, $self->name;
        $email =~ s/first name \+ last name \(all as one word\)/$first$last/;
    } elsif (($self->user // '') eq 'ilabarg1') {
        my ($first, $last) = split / /, $self->name;
        $email =~ s/<Firstname><Lastname>/$first$last/;
    }

    return $email;
}

__PACKAGE__->meta->make_immutable;

=head1 NAME

MediaWiki::USERINFO::User - An object representing a single L<MediaWiki::USERINFO> user

=head1 AUTHOR

E<AElig>var ArnfjE<ouml>rE<eth> Bjarmason <avar@cpan.org>

=head1 LICENSE AND COPYRIGHT

Copyright 2010 E<AElig>var ArnfjE<ouml>rE<eth> Bjarmason <avar@cpan.org>

This program is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
