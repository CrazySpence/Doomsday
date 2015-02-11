#!/usr/bin/perl
# Doomsday IRC 2007
# Core IRC functions Erik Fears 2003
# Game server connection Phil "CrazySpence" Spencer 2007

 
use strict;
use Event;
use Socket;
use IO::Select;
use IO::Socket::INET;
use DBD::mysql;

require "log.pl";


#Options
my $SQL;
my %OPTIONS = (
                 IRC_HOST      => "eu.undernet.org",
                 IRC_PORT      => "6667",
                 IRC_NICK      => "Doomsday",
                 IRC_USERNAME  => "doomsday",
                 IRC_REALNAME  => "Doomsday http://doomsday.philtopia.com",
                 IRC_CHANNEL   => "#Conquest",
                 GAMEHOST      => "127.0.0.1",
                 GAMEPORT      => "10001",
                 RECONNECT     => 30,
                 LOCALADDRESS  => "85.119.82.182", #If m_perform fails send this
                 DD_BUILD      => "0.5",
                 PLAYERTIMEOUT => 1800, #Player timeout
                 DEBUG         => 0,
                 LOGIP         => 1, #Ip address logging, requires database connection
              );

my %DB_OPTIONS = (
                 DB_HOST => "localhost",
                 DB_PORT => 3306,
                 DB_USER => "doomsday",
                 DB_PASS => "partytime",
                 DB_DB   => "doomsday"                 
                 );

my %IRC_FUNCTIONS = (
                     '001'     => \&m_perform,
                     'NICK'    => \&m_nick,
                     'KICK'    => \&m_kick,
                     'PART'    => \&m_part,
                     'PING'    => \&m_ping,
                     'PRIVMSG' => \&m_privmsg,
                     'QUIT'    => \&m_part,
                    );


#Global Variables
my $PTIMER;          #Player timer for checking last time players msged game
my $GTIMER;          #Game timer handler for reconnection to game server
my $GAME;            #Game file handle
my $GAME_DATA;       #Game buffer
my $IRC_MYIP;        #My ip
my $IRC_SOCKET;      #IRC Connection
my $IRC_DATA;        #Data read from IRC
my $SELECT;          #IO::Select
my @DCC;             #List of DCC connections (source hashes)

my @IRC_QUEUE;       #irc message queue

main();

# main
#
# Main initializes the main listening socket
# and handles the main daemon loop.


sub main #()
{
   if(!$OPTIONS{DEBUG}) {
        fork and exit; #Into the background!
   }
   do_log(sprintf('MAIN -> Doomsday IRC %.1f', $OPTIONS{DD_BUILD} ));

   $PTIMER = Event->timer(interval=>60, cb=>\&player_timeout); #timeout check every minute
   if($OPTIONS{LOGIP}) {
      db_init();
   }
   irc_init();
   irc_connect();
   game_connect();
   
   while(1)
   {
       irc_cycle();
       Event::sweep();
   }

}


#### DB connection
sub db_init()
{
   my $data_source;
   #Connect to database

   if(exists($DB_OPTIONS{DB_SOCK}))
   {
      $data_source = sprintf('DBI:mysql:database=%s;mysql_socket=%s', $DB_OPTIONS{DB_DB}, $DB_OPTIONS{DB_SOCK});
   }
   else
   {
      $data_source = sprintf('DBI:mysql:database=%s;host=%s;port=%d', $DB_OPTIONS{DB_DB}, $DB_OPTIONS{DB_HOST},
                              $DB_OPTIONS{DB_PORT});
   }

   $SQL = DBI->connect($data_source, $DB_OPTIONS{DB_USER}, $DB_OPTIONS{DB_PASS});

}

####Client to game functions
sub game_connect()
{
   my $source;
   #Connect to game server
   if(!socket($GAME, PF_INET, SOCK_STREAM, getprotobyname('tcp')))
   {
      printf(sprintf('ERROR -> Error initializing GAME socket: %s\n', $!));
      return;
   }

   $SELECT->add($GAME);

   if(!connect($$GAME, sockaddr_in($OPTIONS{GAMEPORT}, inet_aton($OPTIONS{GAMEHOST}))))
   {
      printf(sprintf('ERROR -> Error connecting to GAME host: %s\n', $!));
       $SELECT->remove($GAME);
      return;
   }
   irc_channel("Game connection established");
   if ($GTIMER) {
      $GTIMER->cancel;
      $GTIMER = 0;
   }
}

sub game_send #\%$data,source
{
     #send to game
     my $source = $_[1];
     my $data = $_[0];
     my $time;
     
     if($GTIMER) {
        return;
     }
     if (!send($$GAME,sprintf("DATA %s %s\n",$$source{nickname},$data) , 0))
     {
          printf("ERROR -> SEND failed on GAME socket closing connection\n");
          #server_cleanup($handle);
     }
     if($time = getsource_nick($$source{nickname}))
     {
        $$time{last} = time();
     }
}

sub game_read
{
   my $data;
   my $pos;
   my $line;
   my $source;

   if(sysread($$GAME, $data, 512) == 0)
   {
      do_log('GAME -> Read error from server');
      $GTIMER = Event->timer(interval=>$OPTIONS{RECONNECT},cb=>\&game_connect);
      irc_channel("Game Disconnected, all sessions closed.\n");
      $SELECT->remove($GAME);
      $GAME->close;
      foreach $source (@DCC) {
           dcc_close($source);
      }
      return;
   }

   $data = $GAME_DATA . $data;

   while(($pos = index($data, "\n")) != -1)
   {
      $line = substr($data, 0, $pos + 1, "");
      chomp $line;
      game_parse($line);
   }
   $GAME_DATA = $data;
}

sub game_parse #\$data
{
   my @message;
   my $source;
   my $data = $_[0];
   
   @message = split(/\s+/,$data);
   if($message[0] eq "PLAYER") {
      #Game is sending a message to specific PLAYER
      $source = getsource(gethandle($message[1]));
      if (!$source) {
         $source = no_source($message[1]);
      }
      #$data =~ s/^PLAYER $$source{nickname}//; #strip protocol
      $data =~ s/^PLAYER (.*?) //; #strip protocol 2, the next generation
      irc_msg($source,$data);    
      if ($data =~ /GOODBYE$/) {
         dcc_close($source); #logged out, disconnect
      }
      if ($data =~ /WELCOME$/) {
         irc_dcc($source); #logged in, DCC
      }
  }
  
  if($message[0] eq "GLOBAL") {
     #Game is sending world message
     $data =~ s/^GLOBAL//; #strip protocol
     irc_channel($data);    
  }
}

sub no_source #\$nick
{
   my $nick =$_[0];
   my %source;
   
   $source{nickname} = $nick;
   $source{alias} = $nick;
   
   return \%source;
}

sub player_timeout
{
    #disconnect idle players
    #mostly to keep non dcc players from holding up the game
    my $player;
    my $duration;
    foreach $player (@DCC)
    {
        $duration = time() - $$player{last};
        if ($duration > $OPTIONS{PLAYERTIMEOUT}) {
            irc_msg($player,sprintf("Connection idle %d minutes. Logged off",($duration / 60)));
            game_send("LOGOUT",$player);
            dcc_close($player);
        }
    }
}
### IRC FUNCTIONS
#
# Initialize IRC socket
#
sub irc_init #()
{
   if(!socket($IRC_SOCKET, PF_INET, SOCK_STREAM, getprotobyname('tcp')))
   {
      do_log(sprintf('IRC -> Error initializing IRC socket: %s', $!));
      die;
   }

   $SELECT = new IO::Select;
   $SELECT->add($$IRC_SOCKET);

   Event->timer(interval=>1, cb=>\&irc_dequeue);
}


# irc_cycle
#
# Run select() on the IRC client and dcc connections to
# check for new data. Reconnect if needed.

sub irc_cycle #()
{
   my $handle;
   my $newhandle;
   my $dcc;
   my @ready;
   my @errored;
   my $query;
  
   #do error events
   @errored = $SELECT->has_error(0);
   
   foreach $handle (@errored)
   {
      if($handle == $$IRC_SOCKET)
      {
         do_log('IRC -> IRC socket has_error');
         irc_reconnect();
         next;
      }

      if($handle == $GAME) {
         next;          
      }
      #it must be a dcc, find the dcc
      foreach $dcc (@DCC)
      {
         if($$dcc{handle} == $handle)
         {
            dcc_close($dcc);
            next;
         }
      }

   }

   #do read events
   @ready = $SELECT->can_read(.1);
  
   foreach $handle (@ready)
   {
      #Data from IRC server
      if($handle == $$IRC_SOCKET)
      {
         irc_read();
         next;
      }
      
      if($handle == $GAME) {
          game_read();            
          next;
      }
      #it must be a dcc, find the dcc
      foreach $dcc (@DCC)
      {
         if($$dcc{handle} == $handle)
         {
            if($$dcc{waiting})
            {
              $SELECT->remove($handle);
               $$dcc{handle} = $handle->accept();
               $SELECT->add($$dcc{handle});

               $$dcc{waiting} = 0;

               
               irc_msg($dcc, 'Welcome to Doomsday!');
               game_send("motd",$dcc);
               if($OPTIONS{LOGIP}) {
                  $query = $SQL->prepare("INSERT INTO address_log SET nick=?, IP=?, date=NOW()");
                  $query->execute($$dcc{nickname},inet_ntoa($$dcc{handle}->peeraddr()));
               }
            }
            else
            {
               dcc_read($dcc);
            }
            next;
         }
      }
   }
}

# irc_connect
#
# Connect to IRC and send registration data
#

sub irc_connect #()
{
   if(!connect($$IRC_SOCKET, sockaddr_in($OPTIONS{IRC_PORT}, inet_aton($OPTIONS{IRC_HOST}))))
   {
      do_log(sprintf('IRC -> Error connecting to IRC host: %s', $!));
      irc_reconnect();
      return;   
   }

   irc_send(sprintf("NICK %s", $OPTIONS{IRC_NICK} ));
   irc_send(sprintf("USER %s %s %s :%s", $OPTIONS{IRC_NICK}, $OPTIONS{IRC_NICK},$OPTIONS{IRC_NICK},
                                         $OPTIONS{IRC_REALNAME} ));
   return;
}



# irc_reconnect
#
# Reconnct to IRC server
#

sub irc_reconnect #()
{

   do_log('IRC -> Reconnecting to server');

   close($$IRC_SOCKET);
   $SELECT->remove($$IRC_SOCKET);

   if(!socket($IRC_SOCKET, PF_INET, SOCK_STREAM, getprotobyname('tcp')))
   {
      do_log(sprintf('IRC -> Error initializing IRC socket: %s', $!));
      die;
   }

   sleep($OPTIONS{RECONNECT});
   irc_connect();
   return;
}



# irc_send
#
# Send data to IRC server
#
# $_[0] IRC Data to send

sub irc_send #($data)
{
   my $data = $_[0];

   $data .= "\n\r";

   push @IRC_QUEUE, $data;
}

sub irc_dequeue
{
   
   return if(!@IRC_QUEUE);

   if(!send($$IRC_SOCKET, shift @IRC_QUEUE, 0))
   {
      do_log(sprintf('IRC -> send() error: %s', $!));
      irc_reconnect();
   }
}


# irc_msg
#
# Send data to a user (given their source)
#

sub irc_msg # \%source, $msg
{
   my $source = $_[0];
   my $msg    = $_[1];

   my @lines;
   my $line;

   @lines = split(/[\n\r]+/, $msg);
 
   return if (!$source);

   if($$source{handle} && !$$source{waiting})
   {
      foreach $line (@lines)
      {
         do_log(sprintf('DCC SEND %s -> %s', $$source{nickname}, $line));
         if (!send($$source{handle}, ' ' . $line . "\n", 0)) {
              do_log(sprintf('DCC SEND ERROR %s',$$source{nickname}));
              dcc_close($source);
         }
      }
   }
   else
   {
      irc_send(sprintf('NOTICE %s :%s', $$source{alias}, $msg));
   }
}


# irc_channel
#
# Send data to the channel
#

sub irc_channel #\$msg
{
   my $msg = $_[0];

  irc_send( sprintf("PRIVMSG %s :%s\r\n", $OPTIONS{IRC_CHANNEL}, $msg));

}
   
# irc_dcc
#
# Send a dcc chat request to source
# and listen on the socket waiting
# for their connection

sub irc_dcc # \%source
{
   my $source = $_[0];
   my $listen;
   my @ss;

   #We will be storing the source hash in @DCC, setup some default values
   $$source{data}      = ""; #data is our data buffer
   $$source{waiting}   = 1;  #Set waiting 1 to show we're waiting for a connection
   $$source{last}      = time();
   $listen = new IO::Socket::INET( Proto     => "tcp",
                                   Listen    => 1);

   $SELECT->add($listen);
   $$source{handle} = $listen;
   push @DCC, $source;

 #  if ($$source{nickname} == "CrazySpence") {
  #    irc_send(sprintf("PRIVMSG %s :\001DCC CHAT chat %d %d\001",$$source{nickname}, 2130706433, $listen->sockport()));
  # } else {
      irc_send(sprintf("PRIVMSG %s :\001DCC CHAT chat %d %d\001",$$source{alias}, $IRC_MYIP, $listen->sockport()));
  # }
}

# dcc_close
#
# Close a dcc chat

sub dcc_close #\%source
{
   my $source = $_[0];
   my $i;

   return if (!$source);

   $SELECT->remove($$source{handle});
   close $$source{handle};
   $$source{handle} = undef;

   for(my $i = 0; $i < scalar @DCC; $i++)
   {
      if($DCC[$i] == $source)
      {
         splice(@DCC, $i, 1);
      }
   }

}


# irc_read
#
# Read data from IRC server
#

sub irc_read #()
{
   my $data;
   my $pos;
   my $line;

   if(sysread($$IRC_SOCKET, $data, 512) == 0)
   {
      do_log('IRC -> Read error from server');
      irc_reconnect();
      return;
   }

   $data = $IRC_DATA . $data;

   while(($pos = index($data, "\n")) != -1)
   {
      $line = substr($data, 0, $pos + 1, "");
      chomp $line;
      irc_parse($line);
   }
   $IRC_DATA = $data;
}


# dcc_read
#
# Read data from dcc and pass it straight to the game engine
#

sub dcc_read #(\%source)
{

   my $source = $_[0];

   my $data;
   my $pos;
   my $line;

   if(sysread($$source{handle}, $data, 512) == 0)
   {
      do_log('DCC -> Read error from client.');
      dcc_close($source);
      return;
   }

   $data = $$source{data} . $data;

   while(($pos = index($data, "\n")) != -1)
   {
      $line = substr($data, 0, $pos + 1, "");
      chomp $line;
      do_log(sprintf('DCC RECV %s -> %s', $$source{nickname}, $line));
      game_send($line, $source);
   }
   $$source{data} = $data;
}


# irc_getsource
sub irc_getsource #\id
{
   my $id = $_[0];
   my $dcc;

   foreach $dcc (@DCC)
   {
      if($$dcc{id} == $id)
      {
         return $dcc;
      }
   }
   return 0;
}


# irc_parse
#
# Parse a line of data from the irc server
#

sub irc_parse #($line)
{
   my $line = $_[0];
  
   my @parv;
   my $command;
   my $message;
   my %source;
   chomp $line;

   @parv = split(/\s+/, substr($line, 0, index($line, ':', 1)));
   $message = substr($line, index($line, ':', 1) + 1, length($line)); 

   push @parv, $message;

   if($parv[0] =~ /:/)
   {
      $parv[0] = substr($parv[0], 1, length($parv[0]));
   }
   else
   {
      unshift @parv, $OPTIONS{IRC_HOST};
   }

   #parse the nick!user@host if it exists
   if($parv[0] =~ /([^!]+)!([^@]+)@(.*)/)
   {
      $source{nickname} = $1;
      $source{alias} = $1;
      $source{username} = $2;
      $source{hostname} = $3;
      $source{is_user}  = 1;
   }
   else { $source{is_user}   = 0; }
  
   
   if(exists($IRC_FUNCTIONS{$parv[1]}))
   {
      $IRC_FUNCTIONS{$parv[1]}(\@parv, \%source);
   }
}


# m_ping
#
# PING from server. 
#
# parv[0] = SOURCE
# parv[1] = PING
# parv[2] = PACKAGE
#

sub m_ping # \@parv, \%source
{
   my $parv = $_[0];
   irc_send(sprintf('PONG :%s', $$parv[2]));  
} 



# m_perform
#
# Successfull connection (perform)
#

sub m_perform # \@parv, \%source
{
   my $parv = $_[0];

   irc_send(sprintf('JOIN %s', $OPTIONS{IRC_CHANNEL}));

   #our IP should be in the 001
   if($$parv[3] =~ /@([^\s]+)/)
   {
    $IRC_MYIP = unpack("N",inet_aton($1));
   }
   
   else { $IRC_MYIP = unpack("N",inet_aton($OPTIONS{LOCALADDRESS}));
  #die "Did not get IP from IRC server (001)!"; 
  }
}


# m_privmsg
#
# privmsg to channel OR user
#
# parv[0] source
# parv[1] PRIVMSG
# parv[2] target
# parv[3] message

sub m_privmsg #\@parv, \%source
{
   my $parv = $_[0];
   my $source = $_[1];

   # We're only interested in privmsg from users to a user (us)
   if(!$$source{is_user} || $$parv[2] =~ /#/) { return; }

   game_send($$parv[3], $source);
}

# m_nick
#
# User changed nick
#
# parv[0] source
# parv[1] NICK
# parv[2] target nick 

sub m_nick #\@parv, \%source
{
   my $parv = $_[0];
   my $source = $_[1];
   my $dcc;

   foreach $dcc (@DCC)
   {
      if($$dcc{alias} eq $$source{alias})
      {
         $$dcc{alias} = $$parv[2];
         irc_msg($dcc, sprintf('Tracking your nick change to %s.', $$parv[2]));
      }
   }
}


# m_part
#
# user parted or quit
#
# parv[0] source
# parv[1] QUIT/PART
# parv[2] message

sub m_part
{

   my $parv = $_[0];
   my $source = $_[1];
   my $dcc;

   foreach $dcc (@DCC)
   {
      if($$dcc{nickname} eq $$source{nickname})
      {
        # irc_msg($dcc, sprintf('You have been logged off for leaving the channel.'));
        # game_send("LOGOUT",$dcc);
        # dcc_close($dcc);
      }
   }

}

# m_kick
#
# user got kicked
#
# parv[0] source
# parv[1] KICK
# parv[2] channel
# parv[3] user kicked
# parv[4] kick message

sub m_kick
{
   my $parv = $_[0];
   my $source = $_[1];
   my $dcc;

   foreach $dcc (@DCC)
   {
      if($$dcc{nickname} eq $$parv[3])
      {
        # irc_msg($dcc, sprintf('You have been logged off for leaving the channel.'));
        # game_send("LOGOUT",$dcc);
        # dcc_close($dcc);
      }
   }

}

sub getsource #\$handle
{
    #get source by file handle from connection pool
    my $handle = $_[0];
    my $pool;
    
    foreach $pool (@DCC) {
        if ($$pool{handle} == $handle) {
           return $pool;
        }
    }
    return 0;
}

sub gethandle #\$user
{
   #get file handle by username from connection pool
   my $user = $_[0];
   my $pool;
   
   foreach $pool (@DCC) {
      if ($$pool{nickname} eq $user) {
           return $$pool{handle};
      }
   }
   return 0;
}

sub getsource_nick #\$nick
{
    #for some people dcc doesnt work but if they are logged in get their correct source
    my $nick = $_[0];
    my $pool;
    
   foreach $pool (@DCC) {
      if ($$pool{alias} eq $nick) {
           
           return $pool;
      }
   }
   return 0;
}

