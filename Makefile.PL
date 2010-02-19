use inc::Module::Install;

name           ('MediaWiki-USERINFO');
perl_version   ('5.010');
author         ('Ævar Arnfjörð Bjarmason <avar@cpan.org>');
all_from       ('lib/MediaWiki/USERINFO.pm');
license        ('perl');
homepage       ('http://search.cpan.org/dist/MediaWiki-USERINFO');
githubmeta     ();
bugtracker     ('http://github.com/avar/mediawiki-userinfo/issues');
resources      (Ratings => 'http://cpanratings.perl.org/d/MediaWiki-USERINFO');


requires       ('Moose'                         => '0.94');
requires       ('MooseX::Getopt'                => '0.26');
requires       ('MooseX::Getopt::Dashes'        => '0');
requires       ('MooseX::StrictConstructor'     => '0.08');
requires       ('MooseX::Types::Path::Class'    => '0.05');
requires       ('MooseX::Types'                 => '0.21');
requires       ('MooseX::Types::Moose'          => '0.21');
requires       ('YAML::XS'                      => '0');
requires       ('autodie'                       => '0');
test_requires  ('List::MoreUtils'               => '0');
test_requires  ('namespace::clean'              => '0');
test_requires  ('Data::Dump'                    => '0');


test_requires  ('Test::More'                    => '0.88');
test_requires  ('Email::Valid'                  => '0');
test_requires  ('Test::utf8'                    => '0');
test_requires  ('List::MoreUtils'               => '0');

install_script glob('script/*.pl');

auto_install;
WriteAll;
