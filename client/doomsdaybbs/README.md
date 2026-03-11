# C64 PETSCII BBS Server

A Commodore 64 compatible PETSCII BBS server written in Perl. Designed to be accessed from a real C64 or emulator using a terminal program such as CCGMS or Striketerm over TCP/IP.

## Features

- **PETSCII native** — full character set translation between ASCII and PETSCII, with correct mixed-case handling for the C64's display
- **User accounts** — registration, login, and MD5-hashed password storage in JSON
- **Chat room** — real-time multi-user chat with `/me` action support and recent message history on join
- **Message board** — leave and read public messages, auto-purged after 7 days
- **PETSCII Art Gallery** — serve `.seq` art files directly to the terminal
- **Dice game** — High/Low dice betting game with score tracking per session
- **Doomsday proxy** — optional connection proxy to an external Doomsday game server
- **Admin system** — in-BBS admin menu plus CLI tool for managing users
- **Kick system** — temporary or permanent kicks with reason, enforced at login

## Requirements

- Perl 5.10+
- Modules: `IO::Socket::INET`, `IO::Select`, `JSON::PP`, `Digest::MD5`

All modules are available in core Perl or via CPAN.

## Setup

```bash
# Clone the repo
git clone https://github.com/YOURNAME/REPONAME.git
cd REPONAME

# Create the art directory (optional)
mkdir art

# Edit configuration at the top of bbs_server.pl
vi bbs_server.pl

# Run the server
perl bbs_server.pl
```

## Configuration

Edit the configuration block at the top of `bbs_server.pl`:

```perl
my $PORT         = 6400;       # TCP port to listen on
my $MAX_CLIENTS  = 10;         # Maximum simultaneous connections
my $USER_DB      = './users.json';
my $MSG_DB       = './messages.json';
my $CHAT_LOG     = './chat.log';
my $ART_DIR      = './art';    # Directory for .seq PETSCII art files
my $MSG_MAX_AGE  = 7;          # Days before messages are purged
my $CHAT_HISTORY = 5;          # Recent messages shown on chat join
my $DD_HOST      = '';         # Doomsday game server hostname (optional)
my $DD_PORT      = 0;          # Doomsday game server port
my $DD_BBS_TOKEN = '';         # Doomsday BBS auth token
```

## Admin CLI

Use `admin_mgr.pl` to manage admin flags from the command line (run from the same directory as `users.json`):

```bash
perl admin_mgr.pl list              # List all users and admin status
perl admin_mgr.pl set <username>    # Grant admin to a user
perl admin_mgr.pl remove <username> # Remove admin from a user
perl admin_mgr.pl show <username>   # Show full details for a user
```

## Art Gallery

Place `.seq` format PETSCII art files in the `./art` directory. They will appear automatically in the gallery menu. Art is sent raw to the terminal so files should be standard 40-column C64 PETSCII sequences.

## Data Files

The following files are created at runtime and should be excluded from version control:

```
users.json      # User account database
messages.json   # Message board posts
chat.log        # Chat room log
art/            # PETSCII art files (add your own)
```

A `.gitignore` is included to exclude these automatically.

## Connecting

Connect from a C64 terminal program (CCGMS, Striketerm, etc.) pointed at your server's IP and configured port. Set your terminal to **PETSCII mode** and **300–9600 baud** emulation.

You can also test with a plain telnet client, though PETSCII control codes will appear as raw bytes without a proper C64 terminal.
