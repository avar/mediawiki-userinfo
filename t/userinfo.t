use 5.10.0;
use autodie;
use strict;
use warnings;
use Test::More;
use MediaWiki::USERINFO;
use Email::Valid;
use File::Spec::Functions qw(catfile);
use List::MoreUtils qw(uniq);
use File::Slurp;
use Test::utf8;

my $ui;
my @all_users;
eval {
    $ui = MediaWiki::USERINFO->new(
        #    (($ENV{USER} eq 'avar' and -d '/home/avar/src/mw/USERINFO')
        #     ? (userinfo_dir => '/home/avar/src/mw/USERINFO')
        #     : ()),
        all_commiters => catfile(qw(t data git-users.txt)),
    );
    @all_users = $ui->all_users;
};
plan(skip_all => "Couldn't find svn(1)") if $@;

my $num_users = @all_users;
my $ok_users  = $num_users;
my %no;

pass("Going to test $num_users users: @all_users");

for my $u (@all_users) {
  SKIP: {
    my $v = $ui->find_user($u);

    unless ($v) {
        $ok_users--;
        push @{ $no{anything} } => $u;
        skip "Can't find data for user $u, skipping tests", 2;
        next;
    }

    my $user  = $v->user;
    my $name  = $v->name;
    my $email = $v->email;

    pass "Testing user $u (canonical name: $user)";

    my $tests_ok = 1;

    if ($name) {
        is_sane_utf8($name, "User $user has a sane UTF-8 name ($name)");
    } else {
      TODO: {
        local $TODO = q[Need to add real names];
        push @{ $no{name} } => $user;
        fail("User $user has no realname in USERINFO");
        $tests_ok = 0;
      }
    }

    if (defined $email) {
        my $email_ok = Email::Valid->address($email);
        my $email_printable = $email;
        $email_printable =~  s/\@/ <at> /g;
        $email_printable =~ s/\./ <dot> /g;
        ok($email_ok, "$user: E-Mail address '$email_printable' is valid");
    } else {
      TODO: {
        local $TODO = q[Need to fix E-Mail addresses];
        push @{ $no{email} } => $user;
        fail("$user: Has no E-Mail address");
        $tests_ok = 0;
      }
    }

    $ok_users-- unless $tests_ok;
  }
}

TODO: {
    local $TODO = q[Need to fix USERINFO];
    fail("These existing users had no name=: @{$no{name}}") if @{$no{name} || [] };
    fail("These existing users had no email=: @{$no{email}}") if @{$no{email} || [] };
    fail("These existing users had no info of any kind: @{$no{anything}}") if @{$no{anything} || []};
    fail("Only $ok_users / $num_users users have valid USERINFO") if $ok_users != $num_users;
}
done_testing();
