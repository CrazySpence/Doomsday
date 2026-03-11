#!/usr/bin/perl
use strict;
use warnings;
use IO::Socket::INET;
use IO::Select;
use JSON::PP;
use Digest::MD5 qw(md5_hex);

# ─────────────────────────────────────────────
# Configuration
# ─────────────────────────────────────────────
my $PORT         = 6400;
my $MAX_CLIENTS  = 10;
my $BUFFER_SIZE  = 1024;
my $USER_DB      = './users.json';
my $MSG_DB       = './messages.json';
my $CHAT_LOG     = './chat.log';
my $ART_DIR      = './art';
my $MSG_MAX_AGE  = 7;
my $CHAT_HISTORY = 5;
my $DD_HOST      = '';       # Doomsday game server hostname
my $DD_PORT      = 0;        # Doomsday game server port
my $DD_BBS_TOKEN = '';       # Doomsday BBS auth token

my $NL = "\r";

# ─────────────────────────────────────────────
# Global State (declared here so all subs can access them)
# ─────────────────────────────────────────────
my %clients;
my %dd_socks;
my $select;

# ─────────────────────────────────────────────
# State Constants
# ─────────────────────────────────────────────
use constant {
    STATE_WELCOME      => 'welcome',
    STATE_LOGIN_USER   => 'login_user',
    STATE_LOGIN_PASS   => 'login_pass',
    STATE_REG_USER     => 'reg_user',
    STATE_REG_PASS     => 'reg_pass',
    STATE_REG_CONFIRM  => 'reg_confirm',
    STATE_MAIN_MENU    => 'main_menu',
    STATE_MSG_WRITE    => 'msg_write',
    STATE_MSG_READ     => 'msg_read',
    STATE_GAMES_MENU   => 'games_menu',
    STATE_DICE         => 'dice',
    STATE_DD           => 'doomsday',
    STATE_CHPASS_OLD   => 'chpass_old',
    STATE_CHPASS_NEW   => 'chpass_new',
    STATE_CHPASS_CONF  => 'chpass_conf',
    STATE_CHAT         => 'chat',
    STATE_ART_GALLERY  => 'art_gallery',
    STATE_ART_VIEW     => 'art_view',
    STATE_ADMIN_MENU   => 'admin_menu',
    STATE_ADMIN_RESETPW  => 'admin_resetpw',
    STATE_ADMIN_RESETPW2 => 'admin_resetpw2',
    STATE_ADMIN_KICK     => 'admin_kick',
    STATE_ADMIN_KICK2    => 'admin_kick2',
    STATE_ADMIN_KICK3    => 'admin_kick3',
    STATE_ADMIN_UNKICK   => 'admin_unkick',
    STATE_KICKED         => 'kicked',
};

# ─────────────────────────────────────────────
# PETSCII Translation Tables
# ─────────────────────────────────────────────
my @PETSCII_TO_ASCII = map { ord('?') } 0..255;
for my $c (0x20 .. 0x3F) { $PETSCII_TO_ASCII[$c] = $c; }
for my $c (0x41 .. 0x5A) { $PETSCII_TO_ASCII[$c] = $c + 0x20; }
for my $c (0x61 .. 0x7A) { $PETSCII_TO_ASCII[$c] = $c; }
for my $c (0xC1 .. 0xDA) { $PETSCII_TO_ASCII[$c] = $c - 0xC1 + 0x41; }
$PETSCII_TO_ASCII[0x0D] = 0x0A;
$PETSCII_TO_ASCII[0x0A] = 0x0D;
$PETSCII_TO_ASCII[0x14] = 0x7F;
$PETSCII_TO_ASCII[0x20] = 0x20;

my %PETSCII_STRIP = map { $_ => 1 } (
    0x05, 0x1C, 0x1E, 0x1F, 0x81, 0x90, 0x9B .. 0x9F,
    0x11, 0x91, 0x9D, 0x1D, 0x13, 0x93, 0x01, 0x08,
    0x09, 0x0F, 0x12, 0x92,
    0x94,
);

my @ASCII_TO_PETSCII = map { ord('?') } 0..255;
for my $c (0x20 .. 0x3F) { $ASCII_TO_PETSCII[$c] = $c; }
for my $c (0x41 .. 0x5A) { $ASCII_TO_PETSCII[$c] = $c; }
for my $c (0x61 .. 0x7A) { $ASCII_TO_PETSCII[$c] = $c + 0x80 - 0x20; }
$ASCII_TO_PETSCII[0x0A] = 0x0D;
$ASCII_TO_PETSCII[0x0D] = 0x0D;
$ASCII_TO_PETSCII[0x7F] = 0x14;
$ASCII_TO_PETSCII[0x08] = 0x14;
$ASCII_TO_PETSCII[0x20] = 0x20;

# ─────────────────────────────────────────────
# PETSCII Control Codes
# ─────────────────────────────────────────────
use constant {
    PETSCII_CLR              => "\x93",
    PETSCII_WHITE            => "\x05",
    PETSCII_CYAN             => "\x9F",
    PETSCII_YELLOW           => "\x9E",
    PETSCII_GREEN            => "\x1E",
    PETSCII_RED              => "\x1C",
    PETSCII_RVS_ON           => "\x12",
    PETSCII_RVS_OFF          => "\x92",
    PETSCII_CHARSET_GRAPHICS => "\x8E",
    PETSCII_CHARSET_LOWER    => "\x0E",
    PETSCII_CURSOR_OFF       => "\x9B",
    PETSCII_CURSOR_ON        => "\x9A",
};

# ─────────────────────────────────────────────
# Translation Subs
# ─────────────────────────────────────────────
sub petscii_to_ascii {
    my ($data) = @_;
    my $out = '';
    for my $byte (unpack('C*', $data)) {
        next if $PETSCII_STRIP{$byte};
        my $mapped = $PETSCII_TO_ASCII[$byte];
        $out .= chr($mapped) if $mapped != ord('?') || $byte == ord('?');
    }
    return $out;
}

sub ascii_to_petscii {
    my ($data) = @_;
    my $out = '';
    for my $byte (unpack('C*', $data)) {
        if    ($byte == 0x5B) { $out .= "\x5B"; }
        elsif ($byte == 0x5D) { $out .= "\x5D"; }
        elsif ($byte == 0x7C) { $out .= "\x7D"; }
        else                  { $out .= chr($ASCII_TO_PETSCII[$byte]); }
    }
    return $out;
}

sub flip_case {
    my ($str) = @_;
    $str =~ s/([A-Za-z])/uc($1) eq $1 ? lc($1) : uc($1)/ge;
    return $str;
}

sub send_raw   { my ($fh, $d) = @_; $fh->send($d); }
sub send_ascii { my ($fh, $t) = @_; $fh->send(ascii_to_petscii($t)); }
sub divider    { ascii_to_petscii("-" x 38 . $NL) }
sub thin_div   { ascii_to_petscii("." x 38 . $NL) }

# ─────────────────────────────────────────────
# User Database
# ─────────────────────────────────────────────
sub load_users {
    return {} unless -f $USER_DB;
    open(my $fh, '<', $USER_DB) or return {};
    local $/; my $json = <$fh>; close $fh;
    return eval { decode_json($json) } // {};
}

sub save_users {
    my ($u) = @_;
    open(my $fh, '>', $USER_DB) or die "Cannot write $USER_DB: $!";
    print $fh encode_json($u); close $fh;
}

sub hash_password  { md5_hex($_[0]) }
sub user_exists    { exists load_users()->{lc $_[0]} }
sub check_password { my $db=load_users(); $db->{lc $_[0]} && $db->{lc $_[0]}{password} eq md5_hex($_[1]) }
sub get_user       { load_users()->{lc $_[0]} }
sub is_admin       { my $u=get_user($_[0]); $u && $u->{admin} }

sub create_user {
    my ($u,$p) = @_;
    my $db = load_users();
    $db->{lc $u} = { password=>md5_hex($p), created=>scalar localtime,
                     last_login=>'', login_count=>0, admin=>0 };
    save_users($db);
}

sub update_login {
    my ($u) = @_;
    my $db = load_users();
    return unless $db->{lc $u};
    $db->{lc $u}{last_login} = scalar localtime;
    $db->{lc $u}{login_count}++;
    save_users($db);
}

# ─────────────────────────────────────────────
# Kick Database (stored inside user record)
# kick record: { until => epoch (0=forever), reason => '...' }
# ─────────────────────────────────────────────
sub is_kicked {
    my ($u) = @_;
    my $db  = load_users();
    my $rec = $db->{lc $u} or return 0;
    return 0 unless $rec->{kicked};
    # 0 = forever, otherwise check expiry
    if ($rec->{kicked}{until} != 0 && time() > $rec->{kicked}{until}) {
        # Expired — clear it
        delete $rec->{kicked};
        save_users($db);
        return 0;
    }
    return $rec->{kicked};
}

sub kick_user {
    my ($u, $hours, $reason) = @_;
    my $db  = load_users();
    return unless $db->{lc $u};
    my $until = ($hours == 255) ? 0 : time() + ($hours * 3600);
    $db->{lc $u}{kicked} = { until => $until, reason => $reason };
    save_users($db);
}

sub unkick_user {
    my ($u) = @_;
    my $db = load_users();
    return unless $db->{lc $u};
    delete $db->{lc $u}{kicked};
    save_users($db);
}

# ─────────────────────────────────────────────
# Message Database
# ─────────────────────────────────────────────
sub load_messages {
    return [] unless -f $MSG_DB;
    open(my $fh, '<', $MSG_DB) or return [];
    local $/; my $json = <$fh>; close $fh;
    return eval { decode_json($json) } // [];
}

sub save_message {
    my ($username, $text) = @_;
    my $msgs = load_messages();
    push @$msgs, { from=>$username, date=>scalar localtime, epoch=>time(), text=>$text };
    open(my $fh, '>', $MSG_DB) or return;
    print $fh encode_json($msgs); close $fh;
}

sub purge_old_messages {
    my $msgs   = load_messages();
    my $cutoff = time() - ($MSG_MAX_AGE * 86400);
    my $before = scalar @$msgs;
    my @kept   = grep { ($_->{epoch}//0) >= $cutoff || ($_->{epoch}//0)==0 } @$msgs;
    my $removed = $before - scalar @kept;
    if ($removed > 0) {
        open(my $fh, '>', $MSG_DB) or return;
        print $fh encode_json(\@kept); close $fh;
        print "[MSG] Purged $removed message(s)\n";
    }
}

# ─────────────────────────────────────────────
# Screen Builders
# ─────────────────────────────────────────────
sub send_welcome_screen {
    my ($fh) = @_;
    send_raw($fh,
        PETSCII_CLR .
        PETSCII_CYAN   . ascii_to_petscii("**************************************$NL") .
        PETSCII_YELLOW . ascii_to_petscii("*   COMMODORE 64 TERMINAL SERVER     *$NL") .
                         ascii_to_petscii("*         PETSCII BBS v1.0           *$NL") .
        PETSCII_CYAN   . ascii_to_petscii("**************************************$NL") .
        PETSCII_WHITE  . ascii_to_petscii("${NL}WELCOME! PLEASE IDENTIFY YOURSELF.$NL$NL") .
        PETSCII_GREEN  . ascii_to_petscii("  [1] LOGIN AS EXISTING USER$NL") .
                         ascii_to_petscii("  [2] REGISTER AS NEW USER$NL") .
                         ascii_to_petscii("  [R] REFRESH SCREEN$NL") .
                         ascii_to_petscii("  [Q] QUIT$NL") .
        PETSCII_WHITE  . ascii_to_petscii("${NL}ENTER CHOICE: ")
    );
}

sub send_main_menu {
    my ($fh, $username, $user) = @_;
    my $logins = $user->{login_count} // 0;
    my $last   = flip_case($user->{last_login}  || 'FIRST TIME!');
    my $msgs   = scalar @{ load_messages() };
    my $online = scalar grep { $clients{$_}{username} } keys %clients;

    my $menu =
        PETSCII_CLR .
        PETSCII_CYAN   . divider() .
        PETSCII_YELLOW . ascii_to_petscii("  WELCOME BACK, " . uc($username) . "!$NL") .
        PETSCII_CYAN   . divider() .
        PETSCII_WHITE  . ascii_to_petscii("  LOGINS  : $logins$NL") .
                         ascii_to_petscii("  LAST ON : $last$NL") .
                         ascii_to_petscii("  ONLINE  : $online$NL") .
        PETSCII_CYAN   . divider() .
        PETSCII_YELLOW . ascii_to_petscii("  -- SOCIAL --$NL") .
        PETSCII_GREEN  . ascii_to_petscii("  [1] CHAT ROOM$NL") .
                         ascii_to_petscii("  [2] ART GALLERY$NL") .
                         ascii_to_petscii("  [3] READ MESSAGES$NL") .
                         ascii_to_petscii("  [4] LEAVE A MESSAGE$NL") .
        PETSCII_CYAN   . thin_div() .
        PETSCII_YELLOW . ascii_to_petscii("  -- GAMES --$NL") .
        PETSCII_GREEN  . ascii_to_petscii("  [5] GAME ROOM$NL") .
        PETSCII_CYAN   . thin_div() .
        PETSCII_YELLOW . ascii_to_petscii("  -- ACCOUNT --$NL") .
        PETSCII_GREEN  . ascii_to_petscii("  [6] CHANGE PASSWORD$NL");

    if ($user->{admin}) {
        $menu .=
            PETSCII_CYAN   . thin_div() .
            PETSCII_YELLOW . ascii_to_petscii("  -- ADMIN --$NL") .
            PETSCII_RED    . ascii_to_petscii("  [A] ADMIN ROOM$NL");
    }

    $menu .=
        PETSCII_CYAN  . divider() .
        PETSCII_WHITE . ascii_to_petscii("  [Q] LOGOUT$NL$NL") .
                        ascii_to_petscii("ENTER CHOICE: ");

    send_raw($fh, $menu);
}

sub send_admin_menu {
    my ($fh) = @_;
    my $online = scalar grep { $clients{$_}{username} } keys %clients;
    send_raw($fh,
        PETSCII_CLR .
        PETSCII_CYAN   . divider() .
        PETSCII_RED    . ascii_to_petscii("  ** ADMIN ROOM **$NL") .
        PETSCII_CYAN   . divider() .
        PETSCII_YELLOW . ascii_to_petscii("  USERS ONLINE: $online$NL") .
        PETSCII_CYAN   . divider() .
        PETSCII_GREEN  . ascii_to_petscii("  [1] SHOW ONLINE USERS$NL") .
                         ascii_to_petscii("  [2] RESET USER PASSWORD$NL") .
                         ascii_to_petscii("  [3] KICK USER$NL") .
                         ascii_to_petscii("  [4] UNKICK USER$NL") .
        PETSCII_CYAN   . divider() .
        PETSCII_WHITE  . ascii_to_petscii("  [B] BACK TO MAIN MENU$NL$NL") .
                         ascii_to_petscii("ENTER CHOICE: ")
    );
}

sub send_games_menu {
    my ($fh) = @_;
    send_raw($fh,
        PETSCII_CLR .
        PETSCII_CYAN   . divider() .
        PETSCII_YELLOW . ascii_to_petscii("  ** GAME ROOM **$NL") .
        PETSCII_CYAN   . divider() .
        PETSCII_GREEN  . ascii_to_petscii("  [1] DICE HIGH/LOW$NL") .
                         ascii_to_petscii("  [2] DOOMSDAY$NL") .
        PETSCII_WHITE  . ascii_to_petscii("  [B] BACK TO MAIN MENU$NL$NL") .
                         ascii_to_petscii("ENTER CHOICE: ")
    );
}

sub send_dice_screen {
    my ($fh, $st) = @_;
    my ($wins,$losses,$score) = ($st->{dice_wins}//0,$st->{dice_losses}//0,$st->{dice_score}//100);
    send_raw($fh,
        PETSCII_CLR .
        PETSCII_CYAN   . divider() .
        PETSCII_YELLOW . ascii_to_petscii("  ** DICE HIGH/LOW **$NL") .
        PETSCII_CYAN   . divider() .
        PETSCII_WHITE  . ascii_to_petscii("  TWO DICE ARE ROLLED. GUESS IF THE$NL") .
                         ascii_to_petscii("  TOTAL WILL BE HIGH (8-12) OR LOW$NL") .
                         ascii_to_petscii("  (2-6) OR SEVEN (7).$NL") .
        PETSCII_CYAN   . thin_div() .
        PETSCII_YELLOW . ascii_to_petscii("  SCORE : $score$NL") .
                         ascii_to_petscii("  WINS  : $wins   LOSSES: $losses$NL") .
        PETSCII_CYAN   . thin_div() .
        PETSCII_GREEN  . ascii_to_petscii("  [H] HIGH  (8-12) PAYS 1:1$NL") .
                         ascii_to_petscii("  [L] LOW   (2-6)  PAYS 1:1$NL") .
                         ascii_to_petscii("  [S] SEVEN (7)    PAYS 4:1$NL") .
        PETSCII_WHITE  . ascii_to_petscii("  [B] BACK TO GAME ROOM$NL$NL") .
                         ascii_to_petscii("BET AMOUNT + CHOICE (E.G. 10H): ")
    );
}

# ─────────────────────────────────────────────
# Server Setup
# ─────────────────────────────────────────────
my $server = IO::Socket::INET->new(
    LocalPort => $PORT,
    Type      => SOCK_STREAM,
    Reuse     => 1,
    Listen    => $MAX_CLIENTS,
) or die "Cannot create server socket on port $PORT: $!\n";

$server->blocking(0);
$select = IO::Select->new($server);

$SIG{PIPE} = 'IGNORE';

purge_old_messages();
print "C64 PETSCII Terminal Server listening on port $PORT\n";

# ─────────────────────────────────────────────
# Main Event Loop
# ─────────────────────────────────────────────
while (1) {
    my @ready = $select->can_read(0.1);
    for my $fh (@ready) {

        if ($fh == $server) {
            my $client = $server->accept(); next unless $client;
            $select->add($client);
            my $addr = $client->peerhost . ':' . $client->peerport;
            $clients{$client} = {
                addr        => $addr,
                fh          => $client,
                state       => STATE_WELCOME,
                linebuf     => '',
                username    => '',
                reg_user    => '',
                reg_pass    => '',
                dice_score  => 100,
                dice_wins   => 0,
                dice_losses => 0,
                dice_bet    => 10,
            };
            print "[+] Connected: $addr\n";
            send_welcome_screen($client);

        } else {
            if (exists $dd_socks{$fh}) {
                _dd_receive($fh); next;
            }

            my $data = '';
            my $bytes = $fh->recv($data, $BUFFER_SIZE);
            if (!defined $bytes || length($data) == 0) {
                _disconnect($fh, $select); next;
            }

            my $ascii = petscii_to_ascii($data);
            next unless length($ascii);
            my $st = $clients{$fh};

            # Suppress echo during password states
            if ($st->{state} ne STATE_LOGIN_PASS  &&
                $st->{state} ne STATE_REG_PASS    &&
                $st->{state} ne STATE_REG_CONFIRM &&
                $st->{state} ne STATE_CHPASS_OLD  &&
                $st->{state} ne STATE_CHPASS_NEW  &&
                $st->{state} ne STATE_CHPASS_CONF &&
                $st->{state} ne STATE_ADMIN_RESETPW2) {
                $fh->send($data);
            }

            $st->{linebuf} .= $ascii;

            # Process DEL/backspace
            while ($st->{linebuf} =~ s/[^\x7F\x08]\x7F// ||
                   $st->{linebuf} =~ s/[^\x7F\x08]\x08// ||
                   $st->{linebuf} =~ s/^\x7F//            ||
                   $st->{linebuf} =~ s/^\x08//) {}

            while ($st->{linebuf} =~ s/^([^\n]*)\n//) {
                my $line = $1; $line =~ s/\r//g; $line =~ s/^\s+|\s+$//g;
                handle_state($fh, $select, $st, $line);
                last unless exists $clients{$fh};
            }
        }
    }
}

# ─────────────────────────────────────────────
# State Machine
# ─────────────────────────────────────────────
sub handle_state {
    my ($fh, $select, $st, $line) = @_;
    my $state = $st->{state};

    # ── Welcome ───────────────────────────────
    if ($state eq STATE_WELCOME) {
        my $ch = uc($line);
        if    ($ch eq '1') { $st->{state} = STATE_LOGIN_USER; _send_login_prompt($fh); }
        elsif ($ch eq '2') { $st->{state} = STATE_REG_USER;   _send_reg_prompt($fh); }
        elsif ($ch eq 'R') { send_welcome_screen($fh); }
        elsif ($ch eq 'Q') { send_ascii($fh,"${NL}GOODBYE!$NL"); _disconnect($fh,$select); }
        else { send_raw($fh, PETSCII_RED.ascii_to_petscii("${NL}INVALID CHOICE.$NL").
                             PETSCII_WHITE.ascii_to_petscii("ENTER CHOICE: ")); }

    # ── Login: username ───────────────────────
    } elsif ($state eq STATE_LOGIN_USER) {
        return send_raw($fh, PETSCII_WHITE.ascii_to_petscii("${NL}USERNAME: ")) if $line eq '';
        $st->{username} = lc($line);
        if (!user_exists($st->{username})) {
            send_raw($fh, PETSCII_RED.ascii_to_petscii("${NL}USER NOT FOUND.$NL").
                          PETSCII_WHITE.ascii_to_petscii("${NL}USERNAME: "));
            $st->{username} = '';
        } else {
            $st->{state} = STATE_LOGIN_PASS;
            send_raw($fh, PETSCII_WHITE.ascii_to_petscii("${NL}PASSWORD: "));
        }

    # ── Login: password ───────────────────────
    } elsif ($state eq STATE_LOGIN_PASS) {
        if (check_password($st->{username}, $line)) {
            # Check kick status before allowing in
            my $kick = is_kicked($st->{username});
            if ($kick) {
                _show_kicked_screen($fh, $kick);
                _disconnect($fh, $select);
                return;
            }
            update_login($st->{username});
            purge_old_messages();
            $st->{state} = STATE_MAIN_MENU;
            print "[*] Login: $st->{username}\n";
            send_main_menu($fh, $st->{username}, get_user($st->{username}));
        } else {
            send_raw($fh, PETSCII_RED.ascii_to_petscii("${NL}INVALID PASSWORD.$NL").
                          PETSCII_WHITE.ascii_to_petscii("${NL}USERNAME: "));
            $st->{state} = STATE_LOGIN_USER; $st->{username} = '';
        }

    # ── Register: username ────────────────────
    } elsif ($state eq STATE_REG_USER) {
        return send_raw($fh, PETSCII_WHITE.ascii_to_petscii("${NL}CHOOSE A USERNAME: ")) if $line eq '';
        if ($line !~ /^[a-zA-Z0-9_]{3,16}$/) {
            send_raw($fh, PETSCII_RED.ascii_to_petscii("${NL}3-16 CHARS, LETTERS/NUMBERS ONLY.$NL").
                          PETSCII_WHITE.ascii_to_petscii("${NL}CHOOSE A USERNAME: ")); return;
        }
        if (user_exists($line)) {
            send_raw($fh, PETSCII_RED.ascii_to_petscii("${NL}USERNAME TAKEN.$NL").
                          PETSCII_WHITE.ascii_to_petscii("${NL}CHOOSE A USERNAME: ")); return;
        }
        $st->{reg_user} = lc($line); $st->{state} = STATE_REG_PASS;
        send_raw($fh, PETSCII_WHITE.ascii_to_petscii("${NL}CHOOSE A PASSWORD: "));

    # ── Register: password ────────────────────
    } elsif ($state eq STATE_REG_PASS) {
        if (length($line) < 4) {
            send_raw($fh, PETSCII_RED.ascii_to_petscii("${NL}MINIMUM 4 CHARACTERS.$NL").
                          PETSCII_WHITE.ascii_to_petscii("${NL}CHOOSE A PASSWORD: ")); return;
        }
        $st->{reg_pass} = $line; $st->{state} = STATE_REG_CONFIRM;
        send_raw($fh, PETSCII_WHITE.ascii_to_petscii("${NL}CONFIRM PASSWORD: "));

    # ── Register: confirm ─────────────────────
    } elsif ($state eq STATE_REG_CONFIRM) {
        if ($line ne $st->{reg_pass}) {
            send_raw($fh, PETSCII_RED.ascii_to_petscii("${NL}PASSWORDS DO NOT MATCH.$NL").
                          PETSCII_WHITE.ascii_to_petscii("${NL}CHOOSE A PASSWORD: "));
            $st->{state} = STATE_REG_PASS; $st->{reg_pass} = ''; return;
        }
        create_user($st->{reg_user}, $st->{reg_pass});
        $st->{username} = $st->{reg_user};
        update_login($st->{username});
        $st->{state} = STATE_MAIN_MENU;
        print "[*] New user: $st->{username}\n";
        send_raw($fh, PETSCII_GREEN.ascii_to_petscii("${NL}ACCOUNT CREATED! WELCOME, ".uc($st->{username})."!${NL}${NL}"));
        send_main_menu($fh, $st->{username}, get_user($st->{username}));

    # ── Main menu ─────────────────────────────
    } elsif ($state eq STATE_MAIN_MENU) {
        my $ch = uc($line);
        if ($st->{pending_menu} && $ch eq '') {
            delete $st->{pending_menu};
            return send_main_menu($fh, $st->{username}, get_user($st->{username}));
        }
        if    ($ch eq '1') { _chat_join($fh, $st); }
        elsif ($ch eq '2') { _art_gallery($fh, $st); }
        elsif ($ch eq '3') { _show_messages($fh, $st); }
        elsif ($ch eq '4') { $st->{state}=STATE_MSG_WRITE; $st->{msg_buf}=''; _send_msg_write_screen($fh); }
        elsif ($ch eq '5') { $st->{state}=STATE_GAMES_MENU; send_games_menu($fh); }
        elsif ($ch eq '6') {
            $st->{state} = STATE_CHPASS_OLD;
            send_raw($fh, PETSCII_CLR.PETSCII_CYAN.divider().
                PETSCII_YELLOW.ascii_to_petscii("  CHANGE PASSWORD$NL").
                PETSCII_CYAN.divider().
                PETSCII_WHITE.ascii_to_petscii("${NL}CURRENT PASSWORD: "));
        }
        elsif ($ch eq 'A' && is_admin($st->{username})) {
            $st->{state} = STATE_ADMIN_MENU;
            send_admin_menu($fh);
        }
        elsif ($ch eq 'Q') {
            send_raw($fh, PETSCII_YELLOW.ascii_to_petscii("${NL}GOODBYE, ".uc($st->{username})."!$NL"));
            _disconnect($fh, $select);
        } else {
            send_raw($fh, PETSCII_RED.ascii_to_petscii("${NL}INVALID CHOICE.$NL").
                          PETSCII_WHITE.ascii_to_petscii("ENTER CHOICE: "));
        }

    # ── Write message ─────────────────────────
    } elsif ($state eq STATE_MSG_WRITE) {
        if (lc($line) eq '/done') {
            if (length($st->{msg_buf}) > 0) {
                save_message($st->{username}, $st->{msg_buf});
                send_raw($fh, PETSCII_GREEN.ascii_to_petscii("${NL}MESSAGE SAVED! THANK YOU.$NL"));
            } else {
                send_raw($fh, PETSCII_RED.ascii_to_petscii("${NL}NO MESSAGE ENTERED.$NL"));
            }
            $st->{state}=''; $st->{msg_buf}='';
            $st->{state} = STATE_MAIN_MENU;
            $st->{pending_menu} = 1;
            send_raw($fh, PETSCII_WHITE.ascii_to_petscii("${NL}PRESS RETURN FOR MENU..."));
        } else { $st->{msg_buf} .= "$line\n"; }

    # ── Read messages ─────────────────────────
    } elsif ($state eq STATE_MSG_READ) {
        $st->{state} = STATE_MAIN_MENU;
        send_main_menu($fh, $st->{username}, get_user($st->{username}));

    # ── Art gallery ───────────────────────────
    } elsif ($state eq STATE_ART_GALLERY) {
        my $ch = uc($line);
        if ($ch eq 'Q') {
            $st->{state} = STATE_MAIN_MENU;
            send_main_menu($fh, $st->{username}, get_user($st->{username}));
        } elsif ($line =~ /^(\d+)$/) {
            my $idx = $1 - 1;
            my @files = _art_list();
            if ($idx < 0 || $idx >= scalar @files) {
                send_raw($fh, PETSCII_RED.ascii_to_petscii("${NL}INVALID SELECTION.$NL").
                              PETSCII_WHITE.ascii_to_petscii("ENTER CHOICE: "));
            } else {
                $st->{state} = STATE_ART_VIEW;
                _art_send($fh, $files[$idx]);
            }
        } else {
            send_raw($fh, PETSCII_RED.ascii_to_petscii("${NL}INVALID CHOICE.$NL").
                          PETSCII_WHITE.ascii_to_petscii("ENTER CHOICE: "));
        }

    } elsif ($state eq STATE_ART_VIEW) {
        send_raw($fh, PETSCII_CURSOR_ON.PETSCII_CHARSET_LOWER);
        $st->{state} = STATE_ART_GALLERY;
        _art_gallery($fh, $st);

    # ── Chat room ─────────────────────────────
    } elsif ($state eq STATE_CHAT) {
        if (lc($line) eq '/quit') {
            _chat_leave($fh, $st);
            $st->{state} = STATE_MAIN_MENU;
            send_main_menu($fh, $st->{username}, get_user($st->{username}));
        } elsif ($line =~ /^\/kick\s+(\S+)\s*(.*)$/i && is_admin($st->{username})) {
            my ($target, $reason) = ($1, $2 || 'kicked from chat');
            $reason =~ tr/A-Za-z/a-zA-Z/;
            _chat_kick($fh, $st, lc($target), $reason);
        } elsif ($line =~ /^\/me (.+)$/i) {
            my $action = $1;
            _chat_log("* ".$st->{username}." ".$action);
            $action =~ tr/A-Za-z/a-zA-Z/;
            _chat_broadcast($fh, undef, "* ".$st->{username}." ".$action, 'action');
        } elsif ($line ne '') {
            my $msg = $line;
            _chat_log("<".$st->{username}."> ".$msg);
            $msg =~ tr/A-Za-z/a-zA-Z/;
            _chat_broadcast($fh, $st->{username}, $msg, 'msg');
        }

    # ── Games menu ────────────────────────────
    } elsif ($state eq STATE_GAMES_MENU) {
        my $ch = uc($line);
        if    ($ch eq '1') { $st->{state}=STATE_DICE; send_dice_screen($fh,$st); }
        elsif ($ch eq '2') { _dd_connect($fh,$select,$st); }
        elsif ($ch eq 'B') { $st->{state}=STATE_MAIN_MENU; send_main_menu($fh,$st->{username},get_user($st->{username})); }
        else { send_raw($fh, PETSCII_RED.ascii_to_petscii("${NL}INVALID CHOICE.$NL").
                             PETSCII_WHITE.ascii_to_petscii("ENTER CHOICE: ")); }

    # ── Dice ──────────────────────────────────
    } elsif ($state eq STATE_DICE) {
        _handle_dice($fh, $select, $st, $line);

    # ── Doomsday ──────────────────────────────
    } elsif ($state eq STATE_DD) {
        if (lc($line) eq '/quit') {
            _dd_disconnect($fh, $st);
            $st->{state} = STATE_GAMES_MENU;
            send_games_menu($fh);
        } else {
            my $dd_msg = sprintf("DATA %s %s\n", $st->{username}, $line);
            print "[DD] Sending: $dd_msg";
            eval { $st->{dd_sock}->send($dd_msg) };
            if ($@) {
                send_raw($fh, PETSCII_RED.ascii_to_petscii("${NL}LOST CONNECTION TO DOOMSDAY.$NL"));
                _dd_disconnect($fh, $st);
                $st->{state} = STATE_GAMES_MENU;
                send_games_menu($fh);
            }
        }

    # ── Change password ───────────────────────
    } elsif ($state eq STATE_CHPASS_OLD) {
        if (!check_password($st->{username}, $line)) {
            send_raw($fh, PETSCII_RED.ascii_to_petscii("${NL}INCORRECT PASSWORD.$NL").
                          PETSCII_WHITE.ascii_to_petscii("${NL}CURRENT PASSWORD: "));
        } else {
            $st->{state} = STATE_CHPASS_NEW;
            send_raw($fh, PETSCII_WHITE.ascii_to_petscii("${NL}NEW PASSWORD: "));
        }

    } elsif ($state eq STATE_CHPASS_NEW) {
        if (length($line) < 4) {
            send_raw($fh, PETSCII_RED.ascii_to_petscii("${NL}MINIMUM 4 CHARACTERS.$NL").
                          PETSCII_WHITE.ascii_to_petscii("${NL}NEW PASSWORD: ")); return;
        }
        $st->{reg_pass} = $line; $st->{state} = STATE_CHPASS_CONF;
        send_raw($fh, PETSCII_WHITE.ascii_to_petscii("${NL}CONFIRM NEW PASSWORD: "));

    } elsif ($state eq STATE_CHPASS_CONF) {
        if ($line ne $st->{reg_pass}) {
            send_raw($fh, PETSCII_RED.ascii_to_petscii("${NL}PASSWORDS DO NOT MATCH.$NL").
                          PETSCII_WHITE.ascii_to_petscii("${NL}NEW PASSWORD: "));
            $st->{state} = STATE_CHPASS_NEW; $st->{reg_pass} = ''; return;
        }
        my $db = load_users();
        $db->{lc $st->{username}}{password} = md5_hex($line);
        save_users($db);
        $st->{reg_pass} = ''; $st->{state} = STATE_MAIN_MENU;
        send_raw($fh, PETSCII_GREEN.ascii_to_petscii("${NL}PASSWORD CHANGED SUCCESSFULLY!$NL"));
        $st->{pending_menu} = 1;
        send_raw($fh, PETSCII_WHITE.ascii_to_petscii("${NL}PRESS RETURN FOR MENU..."));

    # ── Admin menu ────────────────────────────
    } elsif ($state eq STATE_ADMIN_MENU) {
        return unless is_admin($st->{username});
        my $ch = uc($line);
        if ($ch eq '1') {
            # Show online users
            my @online;
            for my $c (values %clients) {
                next unless $c->{username};
                push @online, sprintf("  %-16s %s", uc($c->{username}), $c->{addr});
            }
            my $list = @online ? join("$NL", @online) : "  NONE";
            send_raw($fh,
                PETSCII_CLR.PETSCII_CYAN.divider().
                PETSCII_YELLOW.ascii_to_petscii("  ONLINE USERS$NL").
                PETSCII_CYAN.divider().
                PETSCII_WHITE.ascii_to_petscii($list."$NL").
                PETSCII_WHITE.ascii_to_petscii("${NL}PRESS RETURN..."));
            $st->{pending_menu} = 1;
            $st->{pending_state} = STATE_ADMIN_MENU;

        } elsif ($ch eq '2') {
            $st->{state} = STATE_ADMIN_RESETPW;
            send_raw($fh, PETSCII_WHITE.ascii_to_petscii("${NL}RESET PASSWORD FOR USER: "));

        } elsif ($ch eq '3') {
            $st->{state} = STATE_ADMIN_KICK;
            send_raw($fh, PETSCII_WHITE.ascii_to_petscii("${NL}KICK USERNAME: "));

        } elsif ($ch eq '4') {
            $st->{state} = STATE_ADMIN_UNKICK;
            send_raw($fh, PETSCII_WHITE.ascii_to_petscii("${NL}UNKICK USERNAME: "));

        } elsif ($ch eq 'B') {
            $st->{state} = STATE_MAIN_MENU;
            send_main_menu($fh, $st->{username}, get_user($st->{username}));

        } else {
            if ($st->{pending_menu}) {
                delete $st->{pending_menu};
                delete $st->{pending_state};
                send_admin_menu($fh);
            } else {
                send_raw($fh, PETSCII_RED.ascii_to_petscii("${NL}INVALID CHOICE.$NL").
                              PETSCII_WHITE.ascii_to_petscii("ENTER CHOICE: "));
            }
        }

    # ── Admin: reset password ─────────────────
    } elsif ($state eq STATE_ADMIN_RESETPW) {
        if (!user_exists(lc $line)) {
            send_raw($fh, PETSCII_RED.ascii_to_petscii("${NL}USER NOT FOUND.$NL").
                          PETSCII_WHITE.ascii_to_petscii("${NL}RESET PASSWORD FOR USER: "));
        } else {
            $st->{admin_target} = lc $line;
            $st->{state} = STATE_ADMIN_RESETPW2;
            send_raw($fh, PETSCII_WHITE.ascii_to_petscii("${NL}NEW PASSWORD FOR ".uc($line).": "));
        }

    } elsif ($state eq STATE_ADMIN_RESETPW2) {
        if (length($line) < 4) {
            send_raw($fh, PETSCII_RED.ascii_to_petscii("${NL}MINIMUM 4 CHARACTERS.$NL").
                          PETSCII_WHITE.ascii_to_petscii("${NL}NEW PASSWORD: ")); return;
        }
        my $db = load_users();
        $db->{$st->{admin_target}}{password} = md5_hex($line);
        save_users($db);
        print "[ADMIN] ".$st->{username}." reset password for ".$st->{admin_target}."\n";
        send_raw($fh, PETSCII_GREEN.ascii_to_petscii("${NL}PASSWORD RESET FOR ".uc($st->{admin_target}).".$NL"));
        $st->{state} = STATE_ADMIN_MENU;
        $st->{pending_menu} = 1;
        $st->{pending_state} = STATE_ADMIN_MENU;
        send_raw($fh, PETSCII_WHITE.ascii_to_petscii("${NL}PRESS RETURN..."));

    # ── Admin: kick ───────────────────────────
    } elsif ($state eq STATE_ADMIN_KICK) {
        if (!user_exists(lc $line)) {
            send_raw($fh, PETSCII_RED.ascii_to_petscii("${NL}USER NOT FOUND.$NL").
                          PETSCII_WHITE.ascii_to_petscii("${NL}KICK USERNAME: "));
        } else {
            $st->{admin_target} = lc $line;
            $st->{state} = STATE_ADMIN_KICK2;
            send_raw($fh, PETSCII_WHITE.ascii_to_petscii("${NL}DURATION IN HOURS (255=FOREVER): "));
        }

    } elsif ($state eq STATE_ADMIN_KICK2) {
        if ($line !~ /^\d+$/ || $line < 1 || $line > 255) {
            send_raw($fh, PETSCII_RED.ascii_to_petscii("${NL}ENTER 1-255 (255=FOREVER).$NL").
                          PETSCII_WHITE.ascii_to_petscii("${NL}DURATION IN HOURS: ")); return;
        }
        $st->{admin_kick_hours} = $line;
        $st->{state} = STATE_ADMIN_KICK3;
        send_raw($fh, PETSCII_WHITE.ascii_to_petscii("${NL}REASON: "));

    } elsif ($state eq STATE_ADMIN_KICK3) {
        my $reason = $line || 'No reason given';
        $reason =~ tr/A-Za-z/a-zA-Z/;
        kick_user($st->{admin_target}, $st->{admin_kick_hours}, $reason);
        # If the user is currently online, show them the kick screen and disconnect
        for my $c (values %clients) {
            if ($c->{username} eq $st->{admin_target}) {
                _show_kicked_screen($c->{fh}, { reason => $reason });
                _disconnect($c->{fh}, $select);
                last;
            }
        }
        print "[ADMIN] ".$st->{username}." kicked ".$st->{admin_target}." for ".$st->{admin_kick_hours}."h: $reason\n";
        send_raw($fh, PETSCII_GREEN.ascii_to_petscii("${NL}".uc($st->{admin_target})." HAS BEEN KICKED.$NL"));
        $st->{state} = STATE_ADMIN_MENU;
        $st->{pending_menu} = 1;
        $st->{pending_state} = STATE_ADMIN_MENU;
        send_raw($fh, PETSCII_WHITE.ascii_to_petscii("${NL}PRESS RETURN..."));

    # ── Admin: unkick ─────────────────────────
    } elsif ($state eq STATE_ADMIN_UNKICK) {
        if (!user_exists(lc $line)) {
            send_raw($fh, PETSCII_RED.ascii_to_petscii("${NL}USER NOT FOUND.$NL").
                          PETSCII_WHITE.ascii_to_petscii("${NL}UNKICK USERNAME: "));
        } else {
            unkick_user(lc $line);
            print "[ADMIN] ".$st->{username}." unkicked ".lc($line)."\n";
            send_raw($fh, PETSCII_GREEN.ascii_to_petscii("${NL}".uc($line)." HAS BEEN UNKICKED.$NL"));
            $st->{state} = STATE_ADMIN_MENU;
            $st->{pending_menu} = 1;
            $st->{pending_state} = STATE_ADMIN_MENU;
            send_raw($fh, PETSCII_WHITE.ascii_to_petscii("${NL}PRESS RETURN..."));
        }
    }
}

# ─────────────────────────────────────────────
# Kick Screen
# ─────────────────────────────────────────────
sub _show_kicked_screen {
    my ($fh, $kick) = @_;
    my $reason = $kick->{reason} // 'No reason given';
    my $until  = ($kick->{until} && $kick->{until} != 0)
        ? scalar localtime($kick->{until})
        : 'PERMANENTLY';
    send_raw($fh,
        PETSCII_CLR .
        PETSCII_RED    . ascii_to_petscii("**************************************$NL") .
        PETSCII_YELLOW . ascii_to_petscii("*         YOU HAVE BEEN KICKED       *$NL") .
        PETSCII_RED    . ascii_to_petscii("**************************************$NL") .
        PETSCII_WHITE  . ascii_to_petscii("${NL}REASON : $reason$NL") .
                         ascii_to_petscii("UNTIL  : $until$NL$NL") .
        PETSCII_YELLOW . ascii_to_petscii("GOODBYE.$NL")
    );
}

# ─────────────────────────────────────────────
# Art Gallery
# ─────────────────────────────────────────────
sub _art_list {
    return () unless -d $ART_DIR;
    return sort glob("$ART_DIR/*.seq");
}

sub _art_gallery {
    my ($fh, $st) = @_;
    $st->{state} = STATE_ART_GALLERY;
    my @files = _art_list();
    send_raw($fh,
        PETSCII_CLR.PETSCII_CYAN.divider().
        PETSCII_YELLOW.ascii_to_petscii("  ** PETSCII ART GALLERY **$NL").
        PETSCII_CYAN.divider()
    );
    if (!@files) {
        send_raw($fh, PETSCII_WHITE.ascii_to_petscii("  NO ART FILES FOUND.$NL"));
    } else {
        for my $i (0..$#files) {
            (my $name = $files[$i]) =~ s{.*/}{};
            $name =~ s/\.seq$//i;
            send_raw($fh, PETSCII_GREEN.ascii_to_petscii(sprintf("  [%2d] %s$NL", $i+1, uc($name))));
        }
    }
    send_raw($fh,
        PETSCII_CYAN.divider().
        PETSCII_WHITE.ascii_to_petscii("  [Q] BACK TO MAIN MENU$NL$NL").
                      ascii_to_petscii("ENTER CHOICE: ")
    );
}

sub _art_send {
    my ($fh, $filepath) = @_;
    unless (-r $filepath) {
        send_raw($fh, PETSCII_RED.ascii_to_petscii("${NL}COULD NOT OPEN FILE.$NL")); return;
    }
    send_raw($fh, PETSCII_CHARSET_GRAPHICS.PETSCII_CLR);
    open(my $art, '<:raw', $filepath) or return;
    local $/; my $data = <$art>; close $art;
    $data = substr($data, 0, -1) if length($data) > 1;
    send_raw($fh, $data);
}

# ─────────────────────────────────────────────
# Chat Room
# ─────────────────────────────────────────────
sub _chat_join {
    my ($fh, $st) = @_;
    $st->{state} = STATE_CHAT;
    my @in_room = grep { $_->{fh} != $fh && $_->{state} eq STATE_CHAT } values %clients;
    send_raw($fh,
        PETSCII_CLR.PETSCII_CYAN.divider().
        PETSCII_YELLOW.ascii_to_petscii("  ** CHAT ROOM **$NL").
        PETSCII_CYAN.divider().
        PETSCII_WHITE.ascii_to_petscii("  TYPE TO CHAT. /ME FOR ACTIONS.$NL").
                      ascii_to_petscii("  /QUIT TO RETURN TO MENU.$NL")
    );
    if (is_admin($st->{username})) {
        send_raw($fh, PETSCII_RED.ascii_to_petscii("  /KICK <USER> <REASON> TO KICK.$NL"));
    }
    send_raw($fh, PETSCII_CYAN.divider());
    if (@in_room) {
        my $names = join(', ', map { uc($_->{username}) } @in_room);
        send_raw($fh, PETSCII_YELLOW.ascii_to_petscii("  IN ROOM: $names$NL"));
    } else {
        send_raw($fh, PETSCII_YELLOW.ascii_to_petscii("  YOU ARE THE ONLY ONE HERE.$NL"));
    }
    send_raw($fh, PETSCII_CYAN.divider());
    my @history = _chat_history();
    if (@history) {
        send_raw($fh, PETSCII_WHITE.ascii_to_petscii("  -- RECENT MESSAGES --$NL"));
        send_raw($fh, PETSCII_WHITE.ascii_to_petscii("  ".flip_case($_)."$NL")) for @history;
        send_raw($fh, PETSCII_CYAN.divider());
    }
    _chat_broadcast($fh, undef, "*** ".uc($st->{username})." JOINED THE CHAT", 'join');
    _chat_log("*** ".$st->{username}." joined");
    send_raw($fh, PETSCII_WHITE.ascii_to_petscii("$NL"));
}

sub _chat_leave {
    my ($fh, $st) = @_;
    _chat_broadcast($fh, undef, "*** ".uc($st->{username})." LEFT THE CHAT", 'leave');
    _chat_log("*** ".$st->{username}." left");
}

sub _chat_kick {
    my ($admin_fh, $admin_st, $target, $reason) = @_;
    for my $cst (values %clients) {
        if (lc($cst->{username}) eq $target && $cst->{state} eq STATE_CHAT) {
            # Broadcast the kick to the room
            _chat_broadcast($admin_fh, undef,
                "*** ".uc($target)." WAS KICKED ($reason)", 'kick');
            _chat_log("*** ".uc($target)." WAS KICKED ($reason)");
            # Remove them from chat and put them back at the main menu after 1 min
            send_raw($cst->{fh},
                PETSCII_RED.ascii_to_petscii("${NL}*** YOU HAVE BEEN KICKED FROM CHAT$NL").
                PETSCII_WHITE.ascii_to_petscii("    REASON: $reason$NL").
                ascii_to_petscii("    YOU MAY REJOIN IN 1 MINUTE.$NL"));
            $cst->{state} = STATE_MAIN_MENU;
            $cst->{chat_kick_until} = time() + 60;
            send_main_menu($cst->{fh}, $cst->{username}, get_user($cst->{username}));
            return;
        }
    }
    send_raw($admin_fh, PETSCII_RED.ascii_to_petscii("${NL}*** USER NOT IN CHAT ROOM.$NL"));
}

sub _chat_broadcast {
    my ($sender_fh, $nick, $text, $type) = @_;
    my $encoded = ($type eq 'msg')
        ? PETSCII_YELLOW.ascii_to_petscii("<".uc($nick)."> ").PETSCII_WHITE.ascii_to_petscii("$text$NL")
        : PETSCII_CYAN.ascii_to_petscii("$text$NL");
    for my $cst (values %clients) {
        next unless $cst->{state} eq STATE_CHAT;
        next if ($type eq 'join' || $type eq 'leave') && $cst->{fh} == $sender_fh;
        send_raw($cst->{fh}, $encoded);
    }
}

sub _chat_log {
    my ($text) = @_;
    my @t  = localtime;
    my $ts = sprintf("[%02d/%02d/%04d %02d:%02d]", $t[3],$t[4]+1,$t[5]+1900,$t[2],$t[1]);
    open(my $fh, '>>', $CHAT_LOG) or return;
    print $fh "$ts $text\n"; close $fh;
}

sub _chat_history {
    return () unless -f $CHAT_LOG;
    open(my $fh, '<', $CHAT_LOG) or return ();
    my @lines = <$fh>; close $fh;
    chomp @lines;
    return () unless @lines;
    # Keep regular messages AND kick notices, but strip join/leave lines
    my @msgs = grep { !/^\[\S+\s+\S+\]\s*\*\*\*.*(?:JOINED|LEFT)\b/i } @lines;
    s/^\[\S+\s+\S+\]\s*// for @msgs;
    my $count = scalar @msgs < $CHAT_HISTORY ? scalar @msgs : $CHAT_HISTORY;
    return () unless $count;
    return splice(@msgs, -$count);
}

# ─────────────────────────────────────────────
# Doomsday Proxy
# ─────────────────────────────────────────────
sub _dd_connect {
    my ($fh, $select, $st) = @_;
    send_raw($fh,
        PETSCII_CLR.PETSCII_CYAN.divider().
        PETSCII_YELLOW.ascii_to_petscii("  ** DOOMSDAY **$NL").
        PETSCII_CYAN.divider().
        PETSCII_WHITE.ascii_to_petscii("  CONNECTING TO $DD_HOST...$NL")
    );
    my $dd_sock = eval {
        IO::Socket::INET->new(PeerAddr=>$DD_HOST, PeerPort=>$DD_PORT, Proto=>'tcp', Timeout=>10)
    };
    if (!$dd_sock) {
        send_raw($fh, PETSCII_RED.ascii_to_petscii("  COULD NOT CONNECT TO DOOMSDAY.$NL").
                      PETSCII_WHITE.ascii_to_petscii("  PRESS RETURN FOR GAME MENU..."));
        $st->{pending_menu}=1; $st->{pending_state}=STATE_GAMES_MENU; return;
    }
    $select->add($dd_sock);
    $st->{dd_sock} = $dd_sock;
    $st->{state}   = STATE_DD;
    $dd_socks{$dd_sock} = $fh;
    $dd_sock->blocking(1);
    $dd_sock->send("CLIENT SET 40COL\n");
    select(undef,undef,undef,0.1);
    $dd_sock->send("CLIENT BBSAUTH ".$st->{username}." ".$DD_BBS_TOKEN."\n");
    $dd_sock->blocking(0);
    send_raw($fh,
        PETSCII_GREEN.ascii_to_petscii("  CONNECTED!$NL").
        PETSCII_CYAN.divider().
        PETSCII_WHITE.ascii_to_petscii("  TYPE YOUR COMMANDS BELOW.$NL").
                      ascii_to_petscii("  TYPE /QUIT TO RETURN TO MENU.$NL").
        PETSCII_CYAN.divider().
        PETSCII_GREEN.ascii_to_petscii("$NL")
    );
}

sub _dd_disconnect {
    my ($fh, $st) = @_;
    if ($st->{dd_sock}) {
        $select->remove($st->{dd_sock});
        delete $dd_socks{$st->{dd_sock}};
        eval { $st->{dd_sock}->close() };
        delete $st->{dd_sock};
    }
}

sub _dd_receive {
    my ($dd_sock) = @_;
    my $client_fh = $dd_socks{$dd_sock};
    return unless $client_fh && exists $clients{$client_fh};
    my $buf = '';
    my $bytes = $dd_sock->recv($buf, 4096);
    if (!defined $bytes || length($buf) == 0) {
        send_raw($client_fh, PETSCII_RED.ascii_to_petscii("${NL}DOOMSDAY SERVER DISCONNECTED.$NL").
                              PETSCII_WHITE.ascii_to_petscii("PRESS RETURN FOR GAME MENU..."));
        my $st = $clients{$client_fh};
        _dd_disconnect($client_fh, $st);
        $st->{state}=STATE_GAMES_MENU; $st->{pending_menu}=1; return;
    }
    for my $raw_line (split /\n/, $buf) {
        $raw_line =~ s/\r//g; next unless length $raw_line;
        my $text;
        if    ($raw_line =~ /^PLAYER \S+ (.+)$/) { $text = $1; }
        elsif ($raw_line =~ /^GLOBAL (.+)$/)      { $text = "[GLOBAL] $1"; }
        elsif ($raw_line =~ /^SERVER (.+)$/)      { $text = $1; }
        else                                       { $text = $raw_line; }
        next if $text eq '<END/>';
        $text =~ tr/A-Za-z/a-zA-Z/;
        send_raw($client_fh, PETSCII_GREEN.ascii_to_petscii("$text$NL").PETSCII_WHITE.ascii_to_petscii(""));
    }
}

# ─────────────────────────────────────────────
# Dice High/Low Game
# ─────────────────────────────────────────────
sub _handle_dice {
    my ($fh, $select, $st, $line) = @_;
    my $ch = uc($line);
    if ($ch eq 'B') { $st->{state}=STATE_GAMES_MENU; return send_games_menu($fh); }
    my $score = $st->{dice_score}//100;
    my ($bet,$choice) = (0,'');
    if    ($ch =~ /^(\d+)\s*([HLS])$/) { ($bet,$choice)=($1,$2); }
    elsif ($ch =~ /^([HLS])$/)          { $bet=$st->{dice_bet}||10; $choice=$1; }
    else {
        send_raw($fh, PETSCII_RED.ascii_to_petscii("${NL}ENTER: <AMOUNT><H/L/S>  E.G. 10H$NL").
                      PETSCII_WHITE.ascii_to_petscii("YOUR BET: ")); return;
    }
    $bet=$score if $bet>$score; $bet=1 if $bet<1; $st->{dice_bet}=$bet;
    my $d1=int(rand(6))+1; my $d2=int(rand(6))+1; my $total=$d1+$d2;
    my $cat=$total<=6?'L':$total==7?'S':'H';
    my ($won,$payout)=(0,0);
    if ($choice eq $cat) {
        $payout=($choice eq 'S')?$bet*4:$bet; $st->{dice_score}+=$payout; $st->{dice_wins}++; $won=1;
    } else { $st->{dice_score}-=$bet; $st->{dice_losses}++; }
    my $cat_word=$cat eq 'H'?'HIGH':$cat eq 'L'?'LOW':'SEVEN';
    my $result_col=$won?PETSCII_GREEN:PETSCII_RED;
    my $result_text=$won?"  YOU WIN ".($choice eq 'S'?"$payout (4:1 BONUS!)":$payout)."!":"  YOU LOSE $bet!";
    send_raw($fh,
        PETSCII_CYAN.ascii_to_petscii("${NL}"."-"x38 ."$NL").
        PETSCII_WHITE.ascii_to_petscii("  ROLLING THE DICE...$NL$NL").
        PETSCII_YELLOW.ascii_to_petscii("  [D$d1] [D$d2]  =  TOTAL: $total ($cat_word)$NL$NL").
        $result_col.ascii_to_petscii("  $result_text$NL").
        PETSCII_WHITE.ascii_to_petscii("  SCORE: ".$st->{dice_score}."$NL").
        PETSCII_CYAN.ascii_to_petscii("-"x38 ."$NL")
    );
    if ($st->{dice_score}<=0) {
        send_raw($fh, PETSCII_RED.ascii_to_petscii("${NL}  YOU'RE BROKE! RESETTING TO 100.$NL").
                      PETSCII_WHITE.ascii_to_petscii("  PRESS RETURN..."));
        $st->{dice_score}=100; $st->{pending_dice}=1; return;
    }
    if ($st->{pending_dice}) { delete $st->{pending_dice}; send_dice_screen($fh,$st); return; }
    send_raw($fh, PETSCII_GREEN.ascii_to_petscii("${NL}  PLAY AGAIN? BET+CHOICE OR [B] BACK$NL").
                  PETSCII_WHITE.ascii_to_petscii("YOUR BET: "));
}

# ─────────────────────────────────────────────
# Helper Screen Senders
# ─────────────────────────────────────────────
sub _send_login_prompt {
    my ($fh) = @_;
    send_raw($fh, PETSCII_CLR.PETSCII_CYAN.divider().
        PETSCII_YELLOW.ascii_to_petscii("  LOGIN$NL").
        PETSCII_CYAN.divider().
        PETSCII_WHITE.ascii_to_petscii("${NL}USERNAME: "));
}

sub _send_reg_prompt {
    my ($fh) = @_;
    send_raw($fh, PETSCII_CLR.PETSCII_CYAN.divider().
        PETSCII_YELLOW.ascii_to_petscii("  NEW USER REGISTRATION$NL").
        PETSCII_CYAN.divider().
        PETSCII_WHITE.ascii_to_petscii("${NL}CHOOSE A USERNAME: "));
}

sub _send_msg_write_screen {
    my ($fh) = @_;
    send_raw($fh, PETSCII_CLR.PETSCII_CYAN.divider().
        PETSCII_YELLOW.ascii_to_petscii("  LEAVE A MESSAGE$NL").
        PETSCII_CYAN.divider().
        PETSCII_WHITE.ascii_to_petscii("TYPE YOUR MESSAGE BELOW.$NL").
                      ascii_to_petscii("TYPE /DONE WHEN FINISHED.$NL").
        PETSCII_CYAN.divider().
        PETSCII_GREEN.ascii_to_petscii("$NL"));
}

sub _show_messages {
    my ($fh, $st) = @_;
    my $msgs = load_messages();
    send_raw($fh, PETSCII_CLR.PETSCII_CYAN.divider().
        PETSCII_YELLOW.ascii_to_petscii("  MESSAGE BOARD$NL").
        PETSCII_CYAN.divider());
    if (!@$msgs) {
        send_raw($fh, PETSCII_WHITE.ascii_to_petscii("  NO MESSAGES YET.$NL"));
    } else {
        for my $msg (@$msgs) {
            send_raw($fh,
                PETSCII_YELLOW.ascii_to_petscii("FROM: ".uc($msg->{from})."$NL").
                PETSCII_CYAN.ascii_to_petscii("DATE: ".flip_case($msg->{date})."$NL").
                PETSCII_WHITE.ascii_to_petscii(flip_case($msg->{text})."$NL").
                thin_div());
        }
    }
    $st->{state} = STATE_MSG_READ;
    send_raw($fh, PETSCII_WHITE.ascii_to_petscii("${NL}PRESS RETURN FOR MENU..."));
}

sub _show_datetime {
    my ($fh, $st) = @_;
    my @t  = localtime;
    my $dt = sprintf("%04d-%02d-%02d %02d:%02d:%02d",$t[5]+1900,$t[4]+1,$t[3],$t[2],$t[1],$t[0]);
    my $online = scalar grep { $clients{$_}{username} } keys %clients;
    send_raw($fh,
        PETSCII_CYAN.ascii_to_petscii("${NL}SERVER DATE/TIME: ").
        PETSCII_YELLOW.ascii_to_petscii("$dt$NL").
        PETSCII_CYAN.ascii_to_petscii("USERS ONLINE    : ").
        PETSCII_YELLOW.ascii_to_petscii("$online$NL").
        PETSCII_WHITE.ascii_to_petscii("${NL}PRESS RETURN FOR MENU..."));
    $st->{pending_menu}=1;
}

sub _show_who {
    my ($fh, $st) = @_;
    my $list='';
    for my $c (values %clients) {
        next unless $c->{username};
        $list .= "  ".uc($c->{username})." FROM ".$c->{addr}.$NL;
    }
    $list ||= "  NOBODY ELSE IS ONLINE.$NL";
    send_raw($fh,
        PETSCII_CYAN.divider().
        PETSCII_YELLOW.ascii_to_petscii("  WHO IS ONLINE$NL").
        PETSCII_CYAN.divider().
        PETSCII_WHITE.ascii_to_petscii($list).
                      ascii_to_petscii("${NL}PRESS RETURN FOR MENU..."));
    $st->{pending_menu}=1;
}

# ─────────────────────────────────────────────
# Disconnect
# ─────────────────────────────────────────────
sub _disconnect {
    my ($fh, $select) = @_;
    my $addr = $clients{$fh}{addr}//'unknown';
    _chat_leave($fh, $clients{$fh}) if $clients{$fh}{state} eq STATE_CHAT;
    _dd_disconnect($fh, $clients{$fh}) if $clients{$fh}{dd_sock};
    print "[-] Disconnected: $addr\n";
    $select->remove($fh); delete $clients{$fh}; $fh->close();
}
