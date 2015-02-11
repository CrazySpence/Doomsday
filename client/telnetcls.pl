#!/usr/bin/perl
use strict;
use Event;
use Socket;
use IO::Select;
use IO::Socket::INET;

#My second doomdsay client, the telnet server
#This client connects to the Game server and allows multiple players to
#play through one server at a time
#Telnet Clients I have tried: Linux/BSD telnet
#                             Putty
#                             Windows Telnet (terrible character mode client)
#The server works so now I am going to make some extra goals to accomplish in order of importance
# - Add check for User already being logged in to avoid current conflict error - DONE
# - Or add a time based HASH to the connection source to differentiate 2 logins from 1 user
# - add command history with working up button
# - add local chat with anyone connected

my %OPTIONS = ( 
                DEBUG      => 1, #debug flag
                GAMEHOST   => "127.0.0.1",
                GAMEPORT   => "10001",
                CLIENTMAX  => "20",
                CLIENTPORT => "6000",
                VERSION    => "0.5",
                PROMPT     => "DDAY =>",
                RECONNECT  => 30,
                CLIENTTIMEOUT => 1800, #Client timeout
               
);

my $CLIENTS; #Main Socket
my $GAME;
my $SELECT; 
my @CPOOL;  #Connection pool hashes
my $BUFFER;
my $TIMER;
my $CTIMER;

main();

sub main()
{
  if (!$OPTIONS{DEBUG}) {
     fork and exit;
  }
  server_init(); #Start the Server
  game_connect();
  while (1) 
  {
    server_cycle();
    Event::sweep();
  }
}

sub server_init() 
{
  #set up sever on given port
  $SELECT  = new IO::Select;
  $CLIENTS = new IO::Socket::INET( Proto     => "tcp",
                                   Listen    => $OPTIONS{CLIENTMAX},
                                   LocalPort => $OPTIONS{CLIENTPORT},
                                   Reuse     => "1"
                                );
  die "Could not create socket: $!\n" unless $CLIENTS;
  $SELECT->add($CLIENTS);
  $CTIMER = Event->timer(interval=>60, cb=>\&client_timeout); #timeout check every minute

}

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
   foreach $source (@CPOOL) {
       #sends message to any connected players that game has been established
       server_send($$source{handle},"Game Connected, use LOGIN <yourpassword>\n\r");    
       server_send($$source{handle},$OPTIONS{PROMPT});     
   }
   if ($TIMER) {
      $TIMER->cancel;
      $TIMER = 0;
   }
}

sub server_cycle()
{
  my $NEW_CONNECTION;
  my @ready;
  my $handle;
  my $data;
  my %source;
  my $client;  
  my $line;
  my $pos;
  
  @ready = $SELECT->can_read(.1);
  
  foreach $handle (@ready)
  {
    if ($handle == $CLIENTS) #new connection time
    {
      #Incoming connection
      $NEW_CONNECTION = $CLIENTS->accept();
      #get rid of garbage GNU and putty telnet send, Im sure it isnt garbage but i do not need it
      sysread($NEW_CONNECTION, $data, 512); #find a better way to do this eventually. lazy right now
      $SELECT->add($NEW_CONNECTION);
      $source{handle} = $NEW_CONNECTION;
      $source{prompt} = 1;
      $source{data} = "";
      push @CPOOL, \%source; 
      server_send($NEW_CONNECTION,sprintf("Doomsday Telnet Server %s\n\rUsername: ",$OPTIONS{VERSION}));
    } else {
         if ($handle == $GAME) {
             if(sysread($handle, $data, 512) == 0) #read it or close it
             {
                #report error and start reconnect timer 
                printf("ERROR -> READ failed on GAME socket closing connection\n");
                server_cleanup($handle);
             } else {         
                $data = $BUFFER . $data;
                while(($pos = index($data, "\n")) != -1)
                {
                   $line = substr($data, 0, $pos + 1, "");
                   server_recieve($handle,$line);
                }
                $BUFFER = $data;
            }
         } else {
            $client = getsource($handle);
            if(sysread($handle, $data, 512) == 0) #read it or close it
            {
               #report error and cleanup any players associated with that connection 
               printf("ERROR -> READ failed on CLIENT socket closing connection\n");
               server_cleanup($handle);
            } else {         
               if ($data eq "\b") {
                  #backspace detection for character feed connections
                  if ($$client{data}) { #only meddle with it if there is buffer already
                     server_send($handle," \b"); #clear the character on the client end
                     $$client{data} = substr($$client{data},0,length($$client{data}) - 1);
                     $data = undef; #clear data variable, we dont want to add \b to the buffer!
                  }
               }
               $data = $$client{data} . $data;
               while(($pos = index($data, "\n")) != -1)
               {
                  $line = substr($data, 0, $pos + 1, "");
                  server_recieve($handle,$line);
               }
               $$client{data} = $data;
             }
        }
    }
  }
}

sub server_recieve #\$handle,$data
{
   my $handle = $_[0];
   my $data = $_[1];
   my @message;
   my $source;
   my $message;
   my $format;
   
   @message = split(/\s+/,$data);
   if ($handle == $GAME) {
        if($message[0] eq "PLAYER") {
             #Game is sending a message to specific PLAYER
             $source = getsource(gethandle($message[1]));
             if($source) {
                  #$data =~ s/^PLAYER $$source{user}//; #strip protocol
                  $data =~ s/^PLAYER (.*?) //; #strip protocol 2, the next generation
                  $data =~ s/\n+/\n\r/; #Carriage return, telnet likes you better this way
                  server_send($$source{handle},$data);    
                  server_send($$source{handle},$OPTIONS{PROMPT});
                  if ($data =~ /GOODBYE\n\r$/) {
                       server_cleanup($$source{handle}); #logged out, disconnect
                  }
             }
        }
        if($message[0] eq "GLOBAL") {
             #Game is sending world message
             foreach $source (@CPOOL) {
                  $data =~ s/^GLOBAL//; #strip protocol
                  $data =~ s/\n+/\n\r/; #Carriage return, telnet likes you better this way
                  server_send($$source{handle},$data);    
                  server_send($$source{handle},$OPTIONS{PROMPT});     
             }
        }
   } else {
       $source = getsource($handle);
       if ($source) {
          if ($$source{prompt} == 1) {
            #User at log in prompt still
            if (!$$source{user}) {
                 $data =~s/\s+$//; #strip whitespace
                 if (is_user($data)) {
                    server_send($$source{handle},"User logged on already, try another\n\rUsername: ");    
                 } else {
                    $$source{user} = $data;
                    #Prompt password
                    server_send($$source{handle},"Password: ");
                 }
            } else {
                 $data =~s/\s+$//;
                 $$source{pass} = $data;
                 $$source{prompt} = 0;
                 server_send($$source{handle},$OPTIONS{PROMPT});
                 $$source{last} = time();
                 if (!$TIMER) {
                     server_send($$GAME,sprintf("DATA %s LOGIN %s\n",$$source{user},$$source{pass}));
                 }
            }
        } else {
            server_send($$source{handle},$OPTIONS{PROMPT});
            $$source{last} = time();
            if (!$TIMER)
            {
                 #Game active so send data
                 server_send($$GAME,sprintf("DATA %s %s\n",$$source{user},$data));
            }
        }
      }
   }
   
}

sub server_cleanup #\$handle
{
    #if a client disconnects compare its handle against players and remove any
    #matching players from the CPOOL
    my $handle = $_[0];
    my $source;
    my $i;
    
    if ($handle == $GAME){
    #Game disconnected start reconnect timer
         if (!$TIMER) {
            $TIMER = Event->timer(interval=>$OPTIONS{RECONNECT},cb=>\&game_connect);
            foreach $source (@CPOOL) {
               server_send($$source{handle},"Game Disconnected\n\r");    
               server_send($$source{handle},$OPTIONS{PROMPT});     
            }
         }
    } else {
         #send logout to game
         $source = getsource($handle);
         if ($source){
             server_send($$GAME,sprintf("DATA %s LOGOUT\n",$$source{user}));
             for(my $i = 0; $i < scalar @CPOOL; $i++)
             {
                 if($CPOOL[$i] == $source)
                 {
                     printf(sprintf("MAIN -> %s logging off\n",$$source{user}));
                     splice(@CPOOL, $i, 1);
                 }
             }
        }
    }
    $SELECT->remove($handle);
    $handle->close();
}

sub server_send #\$handle #\$data
{
    #send to whatever handle needed Data will be preformatted by other functions
    my $handle = $_[0];
    my $data   = $_[1];
    
    #send stuff to whomever
    if (!send($handle, $data, 0))
    {
          printf("ERROR -> SEND failed on socket closing connection\n");
          server_cleanup($handle);
    }
}
sub client_timeout
{
    #disconnect idle clients
    my $client;
    my $duration;
    foreach $client (@CPOOL)
    {
        $duration = time() - $$client{last};
        if ($duration > $OPTIONS{CLIENTTIMEOUT}) {
            server_send($$client{handle},sprintf("Connection idle %d minutes. Logged off",($duration / 60)));
            server_cleanup($$client{handle});
        }
    }
}

sub getsource #\$handle
{
    #get source by file handle from connection pool
    my $handle = $_[0];
    my $pool;
    
    foreach $pool (@CPOOL) {
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
   
   foreach $pool (@CPOOL) {
      if ($$pool{user} eq $user) {
           return $$pool{handle};
      }
   }
   return 0;
}

sub is_user #\$user
{
   my $user = $_[0];
   my $pool;
   
   foreach $pool (@CPOOL) {
      if ($$pool{user} eq $user) {
           return 1;
      }
   }
   return 0;   
}
