#!/usr/bin/perl
use strict;
use warnings;
use JSON::PP;

# ─────────────────────────────────────────────
# Configuration — must match bbs_server.pl
# ─────────────────────────────────────────────
my $USER_DB = './users.json';

# ─────────────────────────────────────────────
# Usage
# ─────────────────────────────────────────────
sub usage {
    print <<EOF;
Usage: $0 <command> [username]

Commands:
  list              Show all users and their admin status
  set <username>    Grant admin flag to a user
  remove <username> Remove admin flag from a user
  show <username>   Show details for a specific user

EOF
    exit 1;
}

# ─────────────────────────────────────────────
# DB Helpers
# ─────────────────────────────────────────────
sub load_users {
    die "ERROR: User database '$USER_DB' not found.\n" unless -f $USER_DB;
    open(my $fh, '<', $USER_DB) or die "ERROR: Cannot read '$USER_DB': $!\n";
    local $/;
    my $json = <$fh>;
    close $fh;
    return eval { decode_json($json) } // die "ERROR: Failed to parse '$USER_DB': $@\n";
}

sub save_users {
    my ($db) = @_;
    open(my $fh, '>', $USER_DB) or die "ERROR: Cannot write '$USER_DB': $!\n";
    print $fh encode_json($db);
    close $fh;
}

# ─────────────────────────────────────────────
# Commands
# ─────────────────────────────────────────────
sub cmd_list {
    my $db = load_users();
    my @users = sort keys %$db;

    if (!@users) {
        print "No users found.\n";
        return;
    }

    printf "%-20s %-8s %-6s %s\n", "USERNAME", "ADMIN", "LOGINS", "LAST LOGIN";
    print "-" x 60 . "\n";
    for my $u (@users) {
        my $rec   = $db->{$u};
        my $admin = $rec->{admin} ? "YES" : "-";
        my $logins = $rec->{login_count} // 0;
        my $last   = $rec->{last_login}  || 'never';
        printf "%-20s %-8s %-6s %s\n", $u, $admin, $logins, $last;
    }
    print "-" x 60 . "\n";

    my $admin_count = scalar grep { $db->{$_}{admin} } @users;
    printf "%d user(s), %d admin(s)\n", scalar @users, $admin_count;
}

sub cmd_set {
    my ($username) = @_;
    $username = lc $username;
    my $db = load_users();

    die "ERROR: User '$username' not found.\n" unless exists $db->{$username};

    if ($db->{$username}{admin}) {
        print "User '$username' is already an admin. No change made.\n";
        return;
    }

    $db->{$username}{admin} = 1;
    save_users($db);
    print "OK: '$username' has been granted admin.\n";
}

sub cmd_remove {
    my ($username) = @_;
    $username = lc $username;
    my $db = load_users();

    die "ERROR: User '$username' not found.\n" unless exists $db->{$username};

    unless ($db->{$username}{admin}) {
        print "User '$username' is not an admin. No change made.\n";
        return;
    }

    $db->{$username}{admin} = 0;
    save_users($db);
    print "OK: Admin flag removed from '$username'.\n";
}

sub cmd_show {
    my ($username) = @_;
    $username = lc $username;
    my $db = load_users();

    die "ERROR: User '$username' not found.\n" unless exists $db->{$username};

    my $rec = $db->{$username};
    print "-" x 40 . "\n";
    printf "Username   : %s\n",  $username;
    printf "Admin      : %s\n",  $rec->{admin}       ? 'YES' : 'no';
    printf "Created    : %s\n",  $rec->{created}     || 'unknown';
    printf "Last login : %s\n",  $rec->{last_login}  || 'never';
    printf "Login count: %s\n",  $rec->{login_count} // 0;
    if ($rec->{kicked}) {
        my $until = ($rec->{kicked}{until} == 0)
            ? 'PERMANENTLY'
            : scalar localtime($rec->{kicked}{until});
        printf "Kicked     : YES (until: %s, reason: %s)\n",
            $until, $rec->{kicked}{reason} // 'none';
    } else {
        printf "Kicked     : no\n";
    }
    print "-" x 40 . "\n";
}

# ─────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────
usage() unless @ARGV;

my $cmd = lc shift @ARGV;

if    ($cmd eq 'list')                  { cmd_list(); }
elsif ($cmd eq 'set'    && @ARGV == 1)  { cmd_set($ARGV[0]); }
elsif ($cmd eq 'remove' && @ARGV == 1)  { cmd_remove($ARGV[0]); }
elsif ($cmd eq 'show'   && @ARGV == 1)  { cmd_show($ARGV[0]); }
else                                    { usage(); }
