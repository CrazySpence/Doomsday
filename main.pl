#!/usr/bin/perl
#CrazySpence's rewrite of the main line for Doomsday PERL 2010
#Original Doomsday perl and 90% of dd.pl copyright of strtok 2003

#June 3rd 2007, It works! I can play DD via remote connection
#Now that the basics work I have some cleanup code to add for departing players/clients
#  - add logout cmd to doomsday :: June 5th DONE
#  - add cleanup routine for disconnected clients DONE
#  - add @cpool cleanup routine to remove disconnected players DONE
#  - make a client! :: June 6th DONE
#   June 8th 2007 all milestones completed

use strict;
use Event;
use Socket;
use IO::Select;
use IO::Socket::INET;

require "./log.pl";
require "./dd.pl";

my %OPTIONS = ( 
                DD_BUILD  => "1.5.1",
                DDD_BUILD => "0.6.2",
                DEBUG     => 1,
		);
my $SOCKET; #Main Socket
my $SELECT; 
my @CPOOL;  #Connection pool hashes
 
main();

sub main()
{
  if (!$OPTIONS{DEBUG})
  {
     fork and exit;
  }
  do_log(sprintf('MAIN -> Doomsday Build %s, Server %s', $OPTIONS{DD_BUILD},$OPTIONS{DDD_BUILD} ));
  server_init(); #Start the DoomsDaemon
  dd_init(); # Initialize game engine
  while (1) 
  {
    server_cycle();
    Event::sweep();
  }
}

sub server_init() 
{
  $SELECT = new IO::Select;
  $SOCKET = new IO::Socket::INET( Proto     => "tcp",
                                  Listen    => 10,
                                  LocalPort => "10001",
                                  Reuse     => "1"
                                );
  die "Could not create socket: $!\n" unless $SOCKET;
  $SELECT->add($SOCKET);
}

sub server_cycle()
{
  my $NEW_CONNECTION;
  my @ready;
  my $handle;
  my $data;
  
  
  @ready = $SELECT->can_read(.1);
  
  foreach $handle (@ready)
  {
    if ($handle == $SOCKET) #new connection time
    {
      $NEW_CONNECTION = $SOCKET->accept();
      $SELECT->add($NEW_CONNECTION);
    } else
    {
      if(sysread($handle, $data, 512) == 0) #read it or close it
      {
        #report error and cleanup any players associated with that connection 
        do_log("ERROR -> READ failed on socket closing connection\n");
        server_cleanup($handle);
      } else {
        server_recieve($handle,$data);
      }
  
   }
 }
}

sub server_recieve #\$handle,$data
{
   my $handle = $_[0];
   my $data = $_[1];
   my @message;
   my %source;
   my $origsource;
   my $message;
   my $pool;
   my $nick;
   
   @message = split(/\s+/,$data);
   if ($message[0] eq "CLIENT") 
   {
       #Handle CLIENT to SERVER
       if ($message[1] eq "GLOBAL")
       {
            #some types of clients may not be constantly connected to get public messages
            #this function will return last 10 public messages
            client_fetchglobal($handle);
       } 
       if ($message[1] eq "SET")
       {
           if($message[2] eq "SINGLE") {
             #Clients like thr web client that send single commands set this to be sent
             #a Cue as to when the message is done
             #So when the web client is connected it should so the following in its message:
             # CLIENT SET SINGLE\n
             # DATA WHATEVER\n
             foreach $pool (@CPOOL)
             {
                if ($$pool{handle} == $handle) {
                   $$pool{SINGLE} = 1;
                }
             }
             if (!$pool) {
                $source{handle} = $handle;
                $source{SINGLE} = 1;
                push @CPOOL, \%source;
             }
          }
          if ($message[2] eq "NOFORMAT") {
            #Clients that want to do their own formatting can set this and be sent raw data with no tables
            #CLIENT SET NOFORMAT\n
            foreach $pool (@CPOOL)
            {
               if ($$pool{handle} == $handle) {
                  $$pool{NOFORMAT} = 1;
               }
            }
            if (!$pool) {
               $source{handle} = $handle;
               $source{NOFORMAT} = 1;
               push @CPOOL, \%source;
            }
 
          }
	  if ($message[2] eq "40COL") {
              #40col client, game will try and cut back the width of output
	      print("CLIENT -> Set 40 col mode\n");
	      foreach $pool (@CPOOL)
	      {
                  if ($$pool{handle} == $handle) {
	              $$pool{cbm} = 1;
		      print("40col set\n");
		  }
	      }
	      if(!$pool) {
                  $source{handle} = $handle;
		  $source{cbm} = 1;
		  print("40col set new\n");
		  push @CPOOL, \%source;
	      }

          }
      }
   }
   if ($message[0] eq "DATA")
   {
       foreach $pool (@CPOOL)
       {
          if ($$pool{handle} == $handle) {
             #apply Client settings to any players using said client
             if($$pool{SINGLE}) {
                $source{SINGLE} = 1;
             }
          }
       }
       $source{nickname} = $message[1];
       $source{handle} = $handle;
       $message = substr($data,(index($data, "",length(sprintf("DATA %s ",$source{nickname})))));
       dd_privmsg($message, \%source);
   }
   if ($message[0] eq "SESS")
   {
        #Session based connection, check session ID in database, execute command
        $nick = sql_session($message[1]);
        if ($nick) {
             if(is_registered($nick)) {
                $origsource = getsource(is_player($nick)); #Already has a registered source, apply the handle
                if(!$$origsource{sess}) {
                   send($handle,sprintf("PLAYER %s You are currently logged into another client, please log out before using the website\n",$nick),0);
                   $SELECT->remove($handle);
                   $handle->close;
                   
                } else {
                   $$origsource{handle} = $handle;
                
                   $message = substr($data,(index($data, "",length(sprintf("SESS %s ",$message[1])))));
                   dd_privmsg($message,$origsource);
                   $SELECT->remove($$origsource{handle}); #Get rid of the connection but leave the source in the pool
                   $$origsource{handle}->close;
                   delete($$origsource{handle}); 
                }  
             } else {
                $source{nickname} = $nick; #Not registered yet, build source hash
                $source{handle}   = $handle;
                $source{sess}     = 1;
                $source{id}       = is_player($nick); #This will get the player ID, the ID will exist because the nick was already found in the DB
                if(has_flag($source{id}, 'admin')) {
                   $source{admin} = 1;
                } else {
                   $source{admin} = 0;
                } 
              
                register_player(\%source);
                $message = substr($data,(index($data, "",length(sprintf("SESS %s ",$message[1])))));
                dd_privmsg($message,\%source);
                $SELECT->remove($source{handle}); #Get rid of the connection but leave the source in the pool
                $source{handle}->close; 
                delete($source{handle});
             }
                
        } else {
           $SELECT->remove($handle);
        }
   }
}

sub server_cleanup #\$handle
{
    #if a client disconnects compare its handle against players and remove any
    #matching players from the CPOOL
    my $handle = $_[0];
    my @DISCARD;
    my $discard;
    my $pool;

    foreach $pool (@CPOOL)
    {

       if($handle == $$pool{handle}) {
          #Originally I had unregister_player here but that changes the length of
          #@CPOOL and then players are missed so I created a DISCARD array for everyone
          #I need to get rid of.
          push @DISCARD, $pool;
       }
    }
    foreach $discard (@DISCARD) {
       unregister_player($discard); #Good bye!
    }
    $SELECT->remove($handle);
    $handle->close;
}

sub client_fetchglobal #\$handle
{
    #Send client last 10 global messages 
    my $handle = $_[0];
    my @global = sql_global();
    my $msg;
    
    foreach $msg (@global) {
        if (!send($handle, sprintf("SERVER %s\n", $msg), 0))
        {
            do_log("ERROR -> SEND failed on socket closing connection\n");
            server_cleanup($handle);
        }   
    }     
   
   if (!send($handle,"SERVER <END/>\n", 0))
   {
      do_log("ERROR -> SEND failed on socket closing connection\n");
      server_cleanup($handle);
   }      
}

sub player_msg # \%source, $msg
{
   my $source = $_[0];
   my $msg    = $_[1];
   my $nickname;
   my @lines;
   my $line;
   my $handle;
   
   @lines = split(/[\n\r]+/, $msg);
 
   return if (!$source);

   if($$source{handle})
   {
      foreach $line (@lines)
      {
         if($$source{sess})
         {
            sql_sessionlog($$source{nickname},sprintf("%s\n",$line));
         }   
         do_log(sprintf("SEND %s -> %s\n", $$source{nickname}, $line));
         if (!send($$source{handle}, sprintf("PLAYER %s %s\n", $$source{nickname},  $line ), 0))
         {
            do_log("ERROR -> SEND failed on socket closing connection\n");
            server_cleanup($$source{handle});
         }
      }
   } else {
      #If a player was logged in recently to a session based source add to session log
      if($$source{sess})
      {
         foreach $line (@lines)
         {
            sql_sessionlog($$source{nickname},sprintf("%s\n",$line));
            do_log(sprintf("SESS %s -> %s\n", $$source{nickname}, $line));
         }
      }  
   }
}   

sub global_msg #\$msg
{
   my $msg    = $_[0];
   my $handle;
   my @handles;
   
   @handles = $SELECT->handles;
   foreach $handle (@handles) {
    send($handle, "GLOBAL " . $msg . "\n", 0);
   }
   sql_global_sessionlog($msg);
   sql_log("0",'GLOBAL',$msg);
} 

sub register_player #\%source
{
  #old DD had irc_dcc which set up the connection and added them to a searchable hash
  #but this incarnation of dd the connection is already made so We just need to add $source
  #to @cpool so when needed we can find this player later
  my $source = $_[0];
  my $inbox = mailbox($source);
  my $query;
  
  push @CPOOL, $source;
  if(!$$source{sess}) {
     player_msg($source,"WELCOME\n");
  }
  if ($inbox && !$$source{SINGLE}) {
     player_msg($source,sprintf("You have %s message(s) waiting",$inbox));
  }
  
  sql_quest_state($source);
  #show_cpool();
}  

sub unregister_player #\%source
{
   #take leaving players out of the hash pool
   #This does not disconnect the player as the player may be connected to a hub
   #client that accepts multiple connections

   my $source = $_[0];
   my $i;

   return if (!$source);

   for(my $i = 0; $i < scalar @CPOOL; $i++)
   {
      if($CPOOL[$i] == $source)
      {
         do_log(sprintf("MAIN -> %s logging off",$$source{nickname}));
         splice(@CPOOL, $i, 1);
      }
   }
   #show_cpool();
   return;
}

sub show_cpool
{
   #displays nicks in cpool so I can tell if it is deleting items properly
   my $pool;
   foreach $pool (@CPOOL)
   {
      printf("connection: %s\n",$$pool{nickname});
   }
   return;
}

sub getsource #\$id
{
   my $id = $_[0];
   my $pool;

   foreach $pool (@CPOOL)
   {
      if($$pool{id} == $id)
      {
         return $pool;
      }
   }
   return 0;
}

sub is_registered #\$nickname
{
   my $nickname = $_[0];
   my $pool;

   foreach $pool (@CPOOL)
   {
      if(lc($$pool{nickname}) eq lc($nickname))
      {
         return 1;
      }
   }
   return 0;
}

sub is_registered_session #\$nickname
{
   #This function is almost identical to is_registered however it also checks for {sess} on the source
   #As some old client (irc,telnet) users ran into an issue where the handle would become hijacked and cause quirky connection
   #problems
   my $nickname = $_[0];
   my $pool;

   foreach $pool (@CPOOL)
   {
      if(lc($$pool{nickname}) eq lc($nickname))
      {
         if($$pool{sess}) {
            return 1;
         }
      }
   }
   return 0;
}

sub dday_version
{
     return sprintf("Doomsday Build %s Server %s",$OPTIONS{DD_BUILD},$OPTIONS{DDD_BUILD});
}
