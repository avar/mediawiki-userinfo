use 5.10.0;
use autodie;
use strict;
use warnings;
use Test::More 'no_plan';
use MediaWiki::USERINFO;
use Email::Valid;
use File::Spec::Functions qw(catfile);
use List::MoreUtils qw(uniq);
use File::Slurp;
use Test::utf8;

my $ui = MediaWiki::USERINFO->new(
    ($ENV{USER} eq 'avar'
     ? (userinfo => '/home/avar/src/mw/USERINFO')
     : ()),
);

my @all_users = uniq($ui->users, git_users());
my $num_users = @all_users;
my $ok_users  = $num_users;

pass("Going to test $num_users users: @all_users");

for my $u (@all_users) {
  SKIP: {
    my $v = $ui->find_user($u);

    unless ($v) {
        $ok_users--;
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
        fail("User $user has no realname in USERINFO");
        $tests_ok = 0;
    }

    if (defined $email) {
        my $email_ok = Email::Valid->address($email);
        my $email_printable = $email;
        $email_printable =~  s/\@/ <at> /g;
        $email_printable =~ s/\./ <dot> /g;
        ok($email_ok, "$user: E-Mail address '$email_printable' is valid");
    } else {
        fail("$user: Has no E-Mail address");
        $tests_ok = 0;
    }

    $ok_users-- unless $tests_ok;
  }
}

fail("Only $ok_users / $num_users users have valid USERINFO") if $ok_users != $num_users;


# Produced with `git log --pretty=format:%an | sort | uniq > git-users.txt'
sub git_users {
    my $file = catfile(qw(t data git-users.txt));

    chomp(my @users = read_file($file));

    return @users;
}

