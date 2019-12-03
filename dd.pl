#ltfavlt Copyright (C) 2003  Erik Fears
# ALL RIGHTS RESERVED
# King Phil CrazySpence 2007-2014
use strict;
use Event;
use Event::timer;
use DBD::mysql;
use Text::ASCIITable;
use Text::Wrap;
use MIME::Lite;

#EVENT WATCHERS
my $HK_TIMER;
my $TEN_TIMER;

#GLOBAL VARIABLES
my $SQL;
my $GAME_EVENT;
my $SHUTDOWN = 0;
my $AIRFIELD = 17;
my $STARTX;
my $STARTY;

#OPTIONS
my %DB_OPTIONS = (
             #   DB_SOCK => "/path/to/database.sock",
                 DB_HOST => "somehost",
                 DB_PORT => 3306,
                 DB_USER => "someuser",
                 DB_PASS => "somepass",
                 DB_DB   => "somedb"                 
                 );

#GAME OPTIONS
my %GAME_OPTIONS = ( );

#FAVOR OPTIONS
my %FAVOR        = (
                      base         => 100,   #BASE FAVOR, ALTS ARE MULTIPLIED BY THIS
                      weight       => 2.5,   #FAVOR CURVE MODIFIER
                      hiregive     => 200,   #AMOUNT HIRED / POPULATION * THIS 
                      hiretake     => -225,  #AMOUNT FIRED / POPULATION * THIS
                      educategive  => 250,   #AMOUNT EDUCATED / POPULATION * THIS
                      educatetake  => -275,  #AMOUNT UNEDUCATED / POULATION * THIS
                      bully        => -325,  #HOW MUCH LARGER BULLY IS * THIS
                      bullymax     => -1875, #MAX BULLY CAN BE
                      antibully    => 75,    #HOW MUCH SMALLER ANTIBULLY * THIS
                      antibullymax => 200,   #MAX ANTIBULLY CAN BE
                      war_win      => 125,   #SURRENDER * THIS 
                      war_lose     => -100,  #SURRENDER * THIS
                      war_defend   => 75,    #SURRENDER * THIS
                      nowage       => 100,   #AMOUNT LEFT / POPULATION * THIS
                    );

#STRUCTURE TYPES
my %STYPE = (
                 'lab'     => 1,
                 'factory' => 2,
                 'Airfield'=> 3,
            );

my %UTYPE = (
                 'ground'       => 1,
                 'shuttle'      => 2,
                 'spacemissile' => 3,
                 'spy'          => 4,
                 'air'          => 5,
                 'item'         => 10,
                 'asteroid'     => 11,
            );

my %GTYPE = (
                 'anarchy'      => 1,
                 'dictatorship' => 2,
            );

my %SPY   = (
                 'spy'   => 13,
                 'recon' => 20,
);

my @AIEASY   = (1, 3, 8, 10  ,-1);
my @AIMEDIUM = (1, 2, 3, 4, 8, 10 ,-1);
my @AIHARD   = (1, 2, 3, 4, 5, 8  ,10 ,9 ,-1);
  
#command array
my @CMDS =    (
      #Administrator
      {cmd => 'mapregen' ,  lg => 1, mp => -1, est => 0, quest =>  0, param => 0,   handler => \&quest_mapregen     },
      {cmd => 'events'   ,  lg => 1, mp => -1, est => 0, quest => -1, param => 0,   handler => \&cmd_events    }, 
      {cmd => 'shutdown' ,  lg => 1, mp => -1, est => 0, quest => -1, param => 0,   handler => \&cmd_shutdown  },
      {cmd => 'add_ai'   ,  lg => 1, mp => -1, est => 0, quest => -1, param => 1,   handler => \&cmd_add_ai    },
      {cmd => 'month'    ,  lg => 1, mp => -1, est => 0, quest => -1, param => 0,   handler => \&cmd_month     },
      {cmd => 'ten'      ,  lg => 1, mp => -1, est => 0, quest => -1, param => 0,   handler => \&cmd_ten       },
      {cmd => 'newpass'  ,  lg => 1, mp => -1, est => 0, quest => -1, param => 2,   handler => \&cmd_newpass   },
      {cmd => 'say'      ,  lg => 1, mp => -1, est => 0, quest => -1, param => 1,   handler => \&cmd_say       },
      {cmd => 'msg'      ,  lg => 1, mp => -1, est => 0, quest => -1, param => 2,   handler => \&cmd_msg       },
      #Main game
      {cmd => 'advice'   ,  lg => 1, mp => 4,  est => 0, quest => 0,  param => 1,   handler => \&cmd_advise    },
      {cmd => 'advise'   ,  lg => 1, mp => 4,  est => 0, quest => 0,  param => 1,   handler => \&cmd_advise    },
      {cmd => 'allocate' ,  lg => 1, mp => 1,  est => 0, quest => 0,  param => 2,   handler => \&cmd_allocate  },
      {cmd => 'attack'   ,  lg => 1, mp => 25, est => 1, quest => 0,  param => 2,   handler => \&cmd_attack    },
      {cmd => 'build'    ,  lg => 1, mp => 3,  est => 0, quest => 0,  param => 1,   handler => \&cmd_build     },
      {cmd => 'bulldoze' ,  lg => 1, mp => 3,  est => 0, quest => 0,  param => 1,   handler => \&cmd_bulldoze  },
      {cmd => 'country'  ,  lg => 1, mp => 1,  est => 0, quest => 0,  param => 1,   handler => \&cmd_country   },
      {cmd => 'disband'  ,  lg => 1, mp => 5,  est => 0, quest => 0,  param => 2,   handler => \&cmd_disband   },
      {cmd => 'educate'  ,  lg => 1, mp => 5,  est => 0, quest => 0,  param => 1,   handler => \&cmd_educate   },
      {cmd => 'establish',  lg => 1, mp => 20, est => 0, quest => 0,  param => 1,   handler => \&cmd_establish },
      {cmd => 'explore'  ,  lg => 1, mp => 8,  est => 0, quest => 0,  param => 0,   handler => \&cmd_explore   },
      {cmd => 'fire'     ,  lg => 1, mp => 3,  est => 0, quest => 0,  param => 2,   handler => \&cmd_fire      },
      {cmd => 'help'     ,  lg => 0, mp => 0,  est => 0, quest => -1, param => 1,   handler => \&cmd_help      },
      {cmd => 'hire'     ,  lg => 1, mp => 3,  est => 0, quest => 0,  param => 2,   handler => \&cmd_hire      },
      {cmd => 'launch'   ,  lg => 1, mp => 10, est => 1, quest => 0,  param => 2,   handler => \&cmd_launch    },
      {cmd => 'list'     ,  lg => 1, mp => 0,  est => 0, quest => 0,  param => 0,   handler => \&cmd_list      },
      {cmd => 'log'      ,  lg => 1, mp => 0,  est => 0, quest => -1, param => 2,   handler => \&cmd_log       },
      {cmd => 'login'    ,  lg => 0, mp => 0,  est => 0, quest => -1, param => 1,   handler => \&cmd_login     },
      {cmd => 'newplayer',  lg => 0, mp => 0,  est => 0, quest => 0,  param => 0,   handler => \&cmd_newplayer },
      {cmd => 'password' ,  lg => 1, mp => 0,  est => 0, quest => -1, param => 1,   handler => \&cmd_password  },
      {cmd => 'r'        ,  lg => 1, mp => 0,  est => 0, quest => 0,  param => 1,   handler => \&cmd_report    },
      {cmd => 'rep'      ,  lg => 1, mp => 0,  est => 0, quest => 0,  param => 1,   handler => \&cmd_report    },
      {cmd => 'report'   ,  lg => 1, mp => 0,  est => 0, quest => 0,  param => 1,   handler => \&cmd_report    },
      {cmd => 'spy'      ,  lg => 1, mp => 10, est => 0, quest => 0,  param => 1,   handler => \&cmd_spy       },
      {cmd => 'surrender',  lg => 1, mp => 3,  est => 0, quest => 0,  param => 1,   handler => \&cmd_surrender },       
      {cmd => 'tax'      ,  lg => 1, mp => 3,  est => 0, quest => 0,  param => 1,   handler => \&cmd_tax       },
      {cmd => 'train'    ,  lg => 1, mp => 3,  est => 0, quest => 0,  param => 2,   handler => \&cmd_train     },
      {cmd => 'sell'     ,  lg => 1, mp =>  3, est => 0, quest => 0,  param => 4,   handler => \&cmd_sell      },      
      {cmd => 'buy'      ,  lg => 1, mp =>  3, est => 0, quest => 0,  param => 2,   handler => \&cmd_buy       },
      {cmd => 'logout'   ,  lg => 1, mp => 0 , est => 0, quest => -1, param => 0,   handler => \&cmd_logout    },
      {cmd => 'info'     ,  lg => 0, mp => 0 , est => 0, quest => -1, param => 0,   handler => \&cmd_info      },
      {cmd => 'mail'     ,  lg => 1, mp => 0 , est => 0, quest => -1, param => 2,   handler => \&cmd_mail      },
      {cmd => 'inbox'    ,  lg => 1, mp => 0 , est => 0, quest => -1, param => 1,   handler => \&cmd_inbox     },
      {cmd => 'bomb'     ,  lg => 1, mp => 25, est => 1, quest => 0,  param => 2,   handler => \&cmd_bomb      },
      {cmd => 'motd'     ,  lg => 1, mp => 0 , est => 0, quest => -1, param => 0,   handler => \&cmd_motd      },
      {cmd => 'recon'    ,  lg => 1, mp => 10, est => 1, quest => 0,  param => 1,   handler => \&cmd_recon     },
      {cmd => 'recall'   ,  lg => 1, mp => 15, est => 1, quest => 0,  param => 0,   handler => \&cmd_recall    },
      {cmd => 'setemail' ,  lg => 1, mp => 0 , est => 0, quest => -1, param => 1,   handler => \&cmd_setemail  },
      {cmd => 'formation',  lg => 1, mp => 3 , est => 0, quest => 0,  param => 1,   handler => \&cmd_formation },
      {cmd => 'lotto'    ,  lg => 1, mp => 3 , est => 0, quest => 0,  param => 1,   handler => \&cmd_lotto     },
      #Quest commands
      {cmd => 'go'       ,  lg => 1, mp => 0 , est => 0, quest => 1,  param => 1,   handler => \&quest_go      },
      {cmd => 'raid'     ,  lg => 1, mp => 12, est => 0, quest => -1, param => 1,   handler => \&quest_raid    },
      {cmd => 'fight'    ,  lg => 1, mp => 0 , est => 0, quest => 1,  param => 1,   handler => \&quest_fight   },
      {cmd => 'quest'    ,  lg => 1, mp => 12, est => 0, quest => -1, param => 1,   handler => \&quest_raid    },
      {cmd => 'g'        ,  lg => 1, mp => 0 , est => 0, quest => 1,  param => 1,   handler => \&quest_go      },
 

);

sub quest_raid
{
   my $query;
   my $message = $_[0];
   my $source = $_[1];
   my $row;
   
   if(has_flag($$source{id},'quest')) {
      if($$message[1] eq "leave") {
        player_msg($source,"You have decided the journey is to difficult and return to your nation.");
        rem_flag($$source{id},'quest');
        return 0;
      }
      player_msg($source,"You are already in the raid");
      return 0;
   }
   
   $query = $SQL->prepare("SELECT took_quest FROM player WHERE id=?");
   $query->execute($$source{id});
   $row = $query->fetchrow_hashref();
   
   if($$row{took_quest} == 1) 
   {
      player_msg($source,"You have already attempted the raid this housekeeping");
      return 0;     
   }
   
   set_flag($$source{id},'quest');
   player_msg($source,"You enter uncharted territory, hoping to find something of value for your nation. Hopefully you return....Alive!");
   $query = $SQL->prepare("UPDATE player SET took_quest='1' WHERE id = ?");
   $query->execute($$source{id});
   $$source{xcords} = $STARTX;
   $$source{ycords} = $STARTY;
   $$source{hp}     = quest_hp($source); #determine hit points
   player_msg($source,sprintf("Your vitality for this adventure is: [%s\\%s]",$$source{hp},1));

   return 1;
}

sub quest_hp
{
   #determine the HP of player
   my $source = $_[0];
   my $query;
   my $rquery; #research table query
   my $row;
   
   $query = $SQL->prepare("SELECT prereq,attack,defense FROM unittype WHERE type=? AND train=true ORDER BY attack DESC");
   $query->execute($UTYPE{"ground"});

   if(!$query->rows()) {
      #impossible to happen but *shrugs*
      return 1;
   }

   while($row = $query->fetchrow_hashref()) {
      $rquery = $SQL->prepare("SELECT id FROM research WHERE player_id=? AND research_id=? AND level=100");
      $rquery->execute($$source{id},$$row{prereq});
      if($rquery->rows()) {
         return $$row{attack};    
      }
   }  

   return 1; 
}

sub quest_go
{
   my $message = $_[0];
   my $source  = $_[1];
   my $query;
   my $row;
   my $action;
   my $xmove = 0;
   my $ymove = 0;
   my $directions = "Available moves: ";

   if(($$message[1] eq "north") || ($$message[1] eq "n")) {
      $ymove = -1;
   }
   if(($$message[1] eq "south") || ($$message[1] eq "s")) {
      $ymove = 1;
   }
   if(($$message[1] eq "east") || ($$message[1] eq "e")) {
      $xmove = 1;
   }
   if(($$message[1] eq "west") || ($$message[1] eq "w")) {
      $xmove = -1
   }
  
   $action = sql_checkmove(($$source{xcords} + $xmove ),($$source{ycords} + $ymove));
   if ($action == 1 ) {
      $$source{xcords} = $$source{xcords} + $xmove;
      $$source{ycords} = $$source{ycords} + $ymove;
      player_msg($source,sprintf("You moved %s without incident (%s,%s)",$$message[1],$$source{xcords},$$source{ycords}));
      $query = $SQL->prepare("SELECT * FROM quest_log WHERE player_id=? AND x=? AND y=?");
      $query->execute($$source{id},$$source{xcords},$$source{ycords});
      if(!$query->rows()) { #player hasn't been to this square, they get an event chance
         if (rand(100) < 10) {
            #random event
            hk_event($$source{id});
         } 
      }
      quest_log($source);
   }
   
   if ($action == 3 ) {
      player_msg($source,sprintf("You've reached the end of your difficult journey! Prepare to be rewarded!"));
      quest_reward($source);
      rem_flag($$source{id},'quest');
      return;
   }
   if ($action == 2) {
      $$source{xcords} = $$source{xcords} + $xmove;
      $$source{ycords} = $$source{ycords} + $ymove;
      player_msg($source,sprintf("You managed to go back to the start *slow clap* (%s,%s)",$$source{xcords},$$source{ycords}));
      quest_log($source);
   }
   if ($action == 4) {
      $$source{xcords} = $$source{xcords} + $xmove;
      $$source{ycords} = $$source{ycords} + $ymove;
      player_msg($source,sprintf("Oh no.....a TRAP! (%s,%s)",$$source{xcords},$$source{ycords}));
      quest_trap($source);
      quest_log($source);
      return;
   }
   if ($action == 0 ) {
      player_msg($source,sprintf("You cannot go that way (%s,%s)",$$source{xcords},$$source{ycords}));
   }
   
   if(sql_checkmove(($$source{xcords}),($$source{ycords} - 1)) != 0) {
      $directions = sprintf("%sNorth ",$directions);
   }
   if(sql_checkmove(($$source{xcords} + 1),($$source{ycords})) != 0) {
      $directions = sprintf("%sEast ",$directions);
   }
   if(sql_checkmove(($$source{xcords}),($$source{ycords} + 1)) != 0) {
      $directions = sprintf("%sSouth ",$directions);
   }
   if(sql_checkmove(($$source{xcords} - 1),($$source{ycords})) != 0) {
      $directions = sprintf("%sWest ",$directions);
   }
   player_msg($source,$directions);
   
   sql_checkplayers($source,0);
   return 1;
}

sub quest_log {
   #log places the player has been
   my $query;
   my $row;
   my $source = $_[0];
   
   $query = $SQL->prepare("INSERT INTO quest_log SET player_id=?,x=?,y=?");
   $query->execute($$source{id},$$source{xcords},$$source{ycords});

}

sub quest_trap {
   my $query;
   my $row;
   my $source = $_[0];
   my %player;
   my $dice;   
   my $player_power;
   my $trap_power;
   my $switch = 0;    
   my $counter;

   if(!$$source{hp}) {
      $$source{hp} = quest_hp($source);
   }
   $player{attack}  = $$source{hp};
   $player{defense} = 1;
   
   $query = $SQL->prepare("SELECT * FROM traps ORDER BY RAND()");
   $query->execute();
  
   $row = $query->fetchrow_hashref();
   player_msg($source,sprintf("A %s [%s\\%s] %s",$$row{name},$$row{attack},$$row{defense},$$row{description}));
 
   $dice = rand(100);

   if ($dice > 50) {
      $switch = 1;
   }

   if(!$switch)
   {
      $player_power = $player{attack};
      $trap_power = $$row{defense};
   } 
   else
   {
      $player_power = $player{defense};
      $trap_power = $$row{attack};
   }
   
   $counter = 100 / ($player_power + $trap_power);
   $dice = rand(100);
   if($dice < $player_power * $counter)
   {
      #player avoided trap
      if($$row{death} == 1) {
         player_msg($source,"You have prevailed in the face of danger!");
      } else {
         player_msg($source,"You avoid the inconvience but wonder if it reflects poorly on you...");
      }
   }
   else
   {
      #trap wins
      if($$row{death} == 1) {
         player_msg($source,"You've been killed!");
         rem_flag($$source{id},'quest');
         sql_log($$source{id},'RAID','You were killed by a trap');
      } else {
         player_msg($source,"You have been sent back to start, better than dieing I suppose.");
         sql_log($$source{id},'RAID','You were sent back to the start');
         $$source{xcords} = $STARTX;
         $$source{ycords} = $STARTY;
      }
   }
   return 1;
}

sub quest_reward {
   my $source = $_[0];
   my $query;
   my $land;
   my $money;
   my $farmers;
   
   $land    = int rand(5000) + 100; #randomize but have minimums
   $money   = int rand(100000) + 1000;
   $farmers = int rand($land) + 100;

   $query = $SQL->prepare("UPDATE player SET land =(land + ?), money =(money + ?), farmers =(farmers + ?) WHERE id=?");
   $query->execute($land,$money,$farmers,$$source{id});
   player_msg($source,sprintf("You have recieved %s land populated with %s farmers and a bonus of \$%s",$land,$farmers,$money));
   global_msg(sprintf("%s has completed the raid and recieved %s land populated with %s farmers and a bonus of \$%s",$$source{nickname},$land,$farmers,$money));
   $query = $SQL->prepare("UPDATE player_statistics SET quest_complete = (quest_complete + 1) WHERE player_id=?");
   $query->execute($$source{id});
   dd_mapgen();
   global_msg("A new map has been generated for the raid");
   $query = $SQL->prepare('UPDATE player SET flags=replace(flags, "quest", "")');
   $query->execute();
   
   #empty current quest log
   $query = $SQL->prepare('TRUNCATE quest_log');
   $query->execute();
   return 1;
}

sub quest_mapregen {
   #admin user forces map regen which clears quest log and resets quest flags ontop of making new map
   my $query;

   dd_mapgen();
   global_msg("A new map has been generated for the raid");
   $query = $SQL->prepare('UPDATE player SET flags=replace(flags, "quest", "")');
   $query->execute();

   #empty current quest log
   $query = $SQL->prepare('TRUNCATE quest_log');
   $query->execute();
   return 1;
   
}

sub sql_checkplayers {
   #Checks if players are in the same spot as current player
   my $query;
   my $row;
   my $source = $_[0];
   my $toggle = $_[1];
   my $remotesource; #other players

   $query = $SQL->prepare("SELECT id FROM player WHERE active='1' AND FIND_IN_SET('quest', flags)");
   $query->execute();

   while($row = $query->fetchrow_hashref()) {
      #Perhaps I should have checked for players or rows but if they don;t exist I shouldn't be here and it should crash so I know.   
      $remotesource = getsource($$row{id});
      if($remotesource != 0) {
         if($$remotesource{id} != $$source{id}) {
            #if it isn't me, continue
            if(($$source{xcords} == $$remotesource{xcords}) && ($$source{ycords} == $$remotesource{ycords})) {
               if($toggle) {
                  if($$remotesource{id} == $toggle) {
                     return 1;
                  } 
               } else {
                  player_msg($source,sprintf("%s is here with you...",$$remotesource{nickname}));
                  player_msg($remotesource,sprintf("%s has just arrived at your location",$$source{nickname}));
               }
            }
         }
      } else {
         $query = $SQL->prepare("SELECT x,y,player_id FROM quest_state WHERE player_id=?");
         $query->execute($$row{id});
         if($query->rows()) {
            $row = $query->fetchrow_hashref();
            if(($$source{xcords} == $$row{x}) && ($$source{ycords} == $$row{y})) {
               if($$row{player_id} == $toggle) {
                  return 1;
               }
               player_msg($source,sprintf("%s is here with you...",sql_gettitle($$row{player_id})));
            }      
         }
      }
   }
}

sub quest_fight {
   my $query;
   my $row;
   my $source = $_[1];
   my $defendersource;
   my $enemy = $_[0];

   my %attackplayer;
   my %defendplayer;
   my $dice;   
   my $attack_power;
   my $defend_power;
   my $switch = 0;    
   my $counter;
   my $defender_id;

   $query = $SQL->prepare("SELECT id FROM player WHERE nick=? AND FIND_IN_SET('quest', flags)");
   $query->execute($$enemy[1]);

   if(!$query->rows()) {
      player_msg($source,"No such player exists in the raid");
      return 0;  
   } 
  
   $row = $query->fetchrow_hashref();
   
   $defender_id = $$row{id};
   if(sql_checkplayers($source,$defender_id)) {
      #fight club

      if(!$$source{hp}) {
         $$source{hp} = quest_hp($source);
      }

      $attackplayer{attack}  = $$source{hp};
      $attackplayer{defense} = 1;
      
      $defendersource = getsource($defender_id);
      
      if(!$$defendersource{hp}) {
         $$defendersource{hp} = quest_hp($defendersource);
      }

      $defendplayer{attack}  = $$defendersource{hp};
      $defendplayer{defense} = 1;

      player_msg($source,sprintf("-= %s [%s\\%s] VS %s [%s\\%s] =-",$$source{nickname},$attackplayer{attack},$attackplayer{defense},$$defendersource{nickname},$defendplayer{attack},$defendplayer{defense}));
      player_msg($defendersource,sprintf("-= %s [%s\\%s] VS %s [%s\\%s] =-",$$source{nickname},$attackplayer{attack},$attackplayer{defense},$$defendersource{nickname},$defendplayer{attack},$defendplayer{defense}));
      $dice = rand(100);

      if ($dice > 50) {
         $switch = 1;
      }

      if(!$switch)
      {
         $attack_power = $attackplayer{attack};
         $defend_power = $defendplayer{defense};
      } 
      else
      {
         $attack_power = $attackplayer{defense};
         $defend_power = $defendplayer{attack};
      }
   
      $counter = 100 / ($attack_power + $defend_power);
      $dice = rand(100);
      if($dice < $attack_power * $counter)
      {
         #attackplayer wins
         player_msg($source,"You have slain the enemy in an attempt to secure your right to the prize");
         player_msg($defendersource,sprintf("%s has killed you.....",$$source{nickname}));
         rem_flag($defender_id,'quest');
         $query = $SQL->prepare("UPDATE player_statistics SET quest_pk = (quest_pk + 1) WHERE player_id=?");
         $query->execute($$source{id});
         sql_log($defender_id,'RAID',sprintf("You were killed by %s",sql_gettitle($$source{id})));
         return 0;
      }
      else
      {
         #defender wins
         player_msg($defendersource,sprintf("You have defended yourself from %s! Go forth and find the treasure!",$$source{nickname}));
         player_msg($source,"Your greed has caused you to bite off more than you can chew and you have been killed.....be more careful in the future");
         rem_flag($$source{id},'quest');
         $query = $SQL->prepare("UPDATE player_statistics SET quest_pk = (quest_pk + 1) WHERE player_id=?");
         $query->execute($defender_id);
         sql_log($$source{id},'RAID',sprintf("You were killed by %s",sql_gettitle($defender_id)));
         return 0;
      }
      
   } else {
      #player not on map with you 
      player_msg($source,"That player is not close enough to fight");
      return 0;
   }
}

sub sql_checkmove {
   my $coordx = $_[0];
   my $coordy = $_[1];
   my $query;
   my $row;
   
   $query = $SQL->prepare("SELECT * FROM map WHERE id=?");
   $query->execute($coordy);

   if(!$query->rows()) {
      return 0; #No move   
   }
   
   $row = $query->fetchrow_hashref();

   return($$row{$coordx}); #will be 1 or 4
}

# dd_init
#
# Initialize game engine
#

sub dd_init
{
   my $data_source;
   my @present;
   my $sec;

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
   die if(!$SQL);

   #seed our random numbers
   srand time;

   #Set up game parameters
   dd_game_setup(); 
    
   #schedule the next hk
   hk_schedule();
   
   #start a ten minute timer
   ten_schedule();

   #Setup MIME::lite sender
   MIME::Lite->send('smtp', $GAME_OPTIONS{'email_server'}, Timeout=>60, AuthUser=>$GAME_OPTIONS{'email_account'}, AuthPass=>$GAME_OPTIONS{'email_password'});
   MIME::Lite->quiet(1);
}

# dd_game_setup
#
# This function should run whenever the game is started or a new round begins

sub dd_game_setup
{
   my $query;
   my $query2;
   my $row;
   
   #Set up GAME variables
   $query = $SQL->prepare('SELECT * FROM game_options');
   $query->execute();
   die if(!$query->rows());
   $row = $query->fetchrow_hashref();
   $GAME_OPTIONS{'mp_max'} = $$row{'mp_max'};
   do_log(sprintf("Configuration\nMP Max: %s\nMP Growth: %s\nMP Bank max: %s\nMin land: %s\nHK interval: %s\nPopulation growth min: %s\nPopulation growth max: %s\nBully: %s\nAnti bully: %s\nBully seperation: %s\nSpace range: %s\nLand ratio: %s\nAnarchy max: %s\nBank allocate max: %s\nTax Bonus: %s\nBaby Bonus: %s\nFactory bonus: %s\nAI Count: %s\nShuttle Limit: %s\nAsteroid: %s\nColonist: %s\nE-mail account: %s\nE-mail password: %s\nE-mail server: %s\n",$$row{'mp_max'},$$row{'mp_growth'},$$row{'mp_bankmax'},$$row{'minland'},$$row{'hk_interval'},$$row{'popgrowth_min'},$$row{'popgrowth_max'},$$row{'bully'},$$row{'antibully'},$$row{'bullysep'},$$row{'spacerange'},$$row{'land_ratio'},$$row{'anarch_max'},$$row{'bankallocate_max'},$$row{'tax_bonus'},$$row{'baby_bonus'},$$row{'factory_bonus'},$$row{'ai_count'},$$row{'shuttle_limit'},$$row{'asteroid'},$$row{'colonist'},$$row{'email_account'},$$row{'email_password'},$$row{'email_server'}));
   $GAME_OPTIONS{'mp_growth'} = $$row{'mp_growth'};
   $GAME_OPTIONS{'mp_bankmax'} = $$row{'mp_bankmax'};
   $GAME_OPTIONS{'minland'} = $$row{'minland'};
   $GAME_OPTIONS{'hk_interval'} = $$row{'hk_interval'};
   $GAME_OPTIONS{'popgrowth_min'} = $$row{'popgrowth_min'};
   $GAME_OPTIONS{'popgrowth_max'} = $$row{'popgrowth_max'};
   $GAME_OPTIONS{'bully'} = $$row{'bully'};
   $GAME_OPTIONS{'antibully'} = $$row{'antibully'};
   $GAME_OPTIONS{'bullysep'} = $$row{'bullysep'};
   $GAME_OPTIONS{'spacerange'} = $$row{'spacerange'};
   $GAME_OPTIONS{'land_ratio'} = $$row{'land_ratio'};
   $GAME_OPTIONS{'anarch_max'} = $$row{'anarch_max'};
   $GAME_OPTIONS{'bankallocate_max'} = $$row{'bankallocate_max'};
   $GAME_OPTIONS{'tax_bonus'} = $$row{'tax_bonus'};
   $GAME_OPTIONS{'baby_bonus'} = $$row{'baby_bonus'};
   $GAME_OPTIONS{'factory_bonus'} = $$row{'factory_bonus'};
   $GAME_OPTIONS{'ai_count'} = $$row{'ai_count'};
   $GAME_OPTIONS{'shuttle_limit'} = $$row{'shuttle_limit'};
   $GAME_OPTIONS{'asteroid'} = $$row{'asteroid'};
   $GAME_OPTIONS{'colonist'} = $$row{'colonist'};
   $GAME_OPTIONS{'email_account'} = $$row{'email_account'};
   $GAME_OPTIONS{'email_password'} = $$row{'email_password'};
   $GAME_OPTIONS{'email_server'} = $$row{'email_server'};
   
   #Set up Global events so they aren't so static
   cmd_events();

   #If Asteroid Game check if asteroid is in space, if not then add it
   if($GAME_OPTIONS{'asteroid'} == 1) {
      $query = $SQL->prepare("SELECT * FROM space WHERE unit_id='21'");
      $query->execute();
      if(!$query->rows()) {
         do_log("No asteroid in space, Adding in");
         $query = $SQL->prepare("INSERT INTO space SET player_id='0', unit_id='21', distance=?");
         $query->execute($GAME_OPTIONS{'spacerange'});
      }
   }

   #Make sure enough Ai exist
   if($GAME_OPTIONS{'ai_count'} > 0) {
      $query = $SQL->prepare("SELECT id FROM player WHERE FIND_IN_SET('ai',flags) and active=1");
      $query->execute();
      if(!$query->rows()) {
         $query = $SQL->prepare("SELECT id FROM player WHERE FIND_IN_SET('ai',flags) and active='0' ORDER BY rand() LIMIT ?");
         $query->execute($GAME_OPTIONS{'ai_count'});
         do_log("Activating AI");
         if($query->rows() > 0) {
            while($row = $query->fetchrow_hashref()) {
                 $query2 = $SQL->prepare("UPDATE player SET active='1' WHERE id=?");
                 $query2->execute($$row{'id'});
            }   
         }   
      } 
   }

   #Generate fresh map, clear quest flags
   dd_mapgen();
   $query = $SQL->prepare('UPDATE player SET flags=replace(flags, "quest", ""),took_quest=0');
   $query->execute();

}

sub dd_mapgen {
   my $maxpath = 80; #Max path length
   my $minpath = 20; #Min Path Length
   my $pathminsteps = 2; #when paths are laid out how many tiles will each random interval take
   my $boguspath = 8; #amount of false paths
   my $trapchance = .15; #% a trap will be created on a bogus path
   my $pathsteps;
   my $xcords;
   my $ycords;
   my $currentsteps;
   my $direction;
   my $reversedirection;
   my $query;
   my $querytext;
   my $tile;

   $query = $SQL->prepare("UPDATE map SET `1`=0,`2`=0,`3`=0,`4`=0,`5`=0,`6`=0,`7`=0,`8`=0,`9`=0,`10`=0,`11`=0,`12`=0,`13`=0,`14`=0,`15`=0,`16`=0,`17`=0,`18`=0,`19`=0,`20`=0,`21`=0,`22`=0,`23`=0,`24`=0,`25`=0,`26`=0,`27`=0,`28`=0,`29`=0,`30`=0,`31`=0,`32`=0,`33`=0,`34`=0,`35`=0,`37`=0,`38`=0,`39`=0,`40`=0,`41`=0,`42`=0,`43`=0,`44`=0,`45`=0,`46`=0,`47`=0,`48`=0,`49`=0,`50`=0");
   $query->execute();

   while($boguspath > 0) {
      #these are not the main path and may contain traps
      $currentsteps = rand($maxpath - $minpath) + $minpath; #Path lentgh
      #printf("Steps: %d\n",$currentsteps);
      my $xcords = int(rand(50) + 1);
      my $ycords = int(rand(50) + 1);
      #printf("Starting point: %d/%d\n",$xcords,$ycords);   
      while($currentsteps > 0) {
         while(($direction = int(rand(4) + 1)) == $reversedirection) {}
         #printf("Direction: %d\n",$direction);
         if((rand(1)) <= $trapchance)
         {
            $tile = 4;
         } else {
            $tile = 1;
         }
         if ($direction == 1) {
              #Path goes North
              if($ycords != 1) {
                 $pathsteps = $pathminsteps;
                 while($pathsteps > 0)
                 {
                    $ycords--;
                    if($ycords < 1) {
                       $ycords = 1;
                       $pathsteps = 0;
                    }
                    $pathsteps--;
                    $querytext = sprintf("UPDATE `map` SET `%d` = '%d' WHERE `map`.`id` = %d",$xcords,$tile,$ycords);
                    $query = $SQL->prepare($querytext);
                    $query->execute();
                 }
                 $reversedirection = 3;
                 $currentsteps--;
              }
         }
         if($direction == 2) {
            #Path goes East
            if($xcords != 50) {
               $pathsteps = $pathminsteps;
               while($pathsteps > 0)
               {
                  $xcords++;
                  if($xcords > 50) {
                     $xcords = 50;
                     $pathsteps = 0;
                  }
                  $pathsteps--;
                  $querytext = sprintf("UPDATE `map` SET `%d` = '%d' WHERE `map`.`id` = %d",$xcords,$tile,$ycords);
                  $query = $SQL->prepare($querytext);
                  $query->execute();
               }
               $reversedirection = 4;
               $currentsteps--;
            }
         }
         if($direction == 3) {
            #Path goes south
            if($ycords != 50) {
               $pathsteps = $pathminsteps;
               while($pathsteps > 0)
               {
                  $ycords++;
                  if($ycords > 50) {
                     $ycords = 50;
                     $pathsteps = 0;
                  }
                  $pathsteps--;
                  $querytext = sprintf("UPDATE `map` SET `%d` = '%d' WHERE `map`.`id` = %d",$xcords,$tile,$ycords);
                  $query = $SQL->prepare($querytext);
                  $query->execute();
               }
               $reversedirection = 1;
               $currentsteps--;
            }
         }
         if($direction == 4) {
            #Path goes West
            if($xcords != 1) {
               $pathsteps = $pathminsteps;
               while($pathsteps > 0)
               {
                  $xcords--;
                  if($xcords < 1) {
                     $xcords = 1;
                     $pathsteps = 0;
                  }
                  $pathsteps--;
                  $querytext = sprintf("UPDATE `map` SET `%d` = '%d' WHERE `map`.`id` = %d",$xcords,$tile,$ycords);
                  $query = $SQL->prepare($querytext);
                  $query->execute();
               }
               $reversedirection = 2;
               $currentsteps--;
            }
         }      
         #printf("Cords: %d/%d\n",$xcords,$ycords); 
      }
      $boguspath--;
   }
   #Main Path
   $tile = 1; #No traps on main path
   $currentsteps = rand($maxpath - $minpath) + $minpath; #Path lentgh
   #printf("Steps: %d\n",$currentsteps);
   $xcords = int(rand(50) + 1);
   $ycords = int(rand(50) + 1);
   $STARTX = $xcords;
   $STARTY = $ycords;
   #printf("Starting point: %d/%d\n",$xcords,$ycords);   
   while($currentsteps > 0) {
      while(($direction = int(rand(4) + 1)) == $reversedirection) {}
      #printf("Direction: %d\n",$direction);
      if ($direction == 1) {
         #Path goes North
         if($ycords != 1) {
            $pathsteps = $pathminsteps;
            while($pathsteps > 0)
            {
               $ycords--;
               if($ycords < 1) {
                  $ycords = 1;
                  $pathsteps = 0;
               }
               $pathsteps--;
               $querytext = sprintf("UPDATE `map` SET `%d` = '%d' WHERE `map`.`id` = %d",$xcords,$tile,$ycords);
               $query = $SQL->prepare($querytext);
               $query->execute();
            }
            $reversedirection = 3;
            $currentsteps--;
         }
      }
      if($direction == 2) {
         #Path goes East
         if($xcords != 50) {
            $pathsteps = $pathminsteps;
            while($pathsteps > 0)
            {
               $xcords++;
               if($xcords > 50) {
                  $xcords = 50;
                  $pathsteps = 0;
               }
               $pathsteps--;
               $querytext = sprintf("UPDATE `map` SET `%d` = '%d' WHERE `map`.`id` = %d",$xcords,$tile,$ycords);
               $query = $SQL->prepare($querytext);
               $query->execute();
            }
            $reversedirection = 4;
            $currentsteps--;
         }
      }
      if($direction == 3) {
         #Path goes south
         if($ycords != 50) {
            $pathsteps = $pathminsteps;
            while($pathsteps > 0)
            {
               $ycords++;
               if($ycords > 50) {
                  $ycords = 50;
                  $pathsteps = 0;
               }
               $pathsteps--;
               $querytext = sprintf("UPDATE `map` SET `%d` = '%d' WHERE `map`.`id` = %d",$xcords,$tile,$ycords);
               $query = $SQL->prepare($querytext);
               $query->execute();
            }
            $reversedirection = 1;
            $currentsteps--;
         }
      }
      if($direction == 4) {
         #Path goes West
         if($xcords != 1) {
            $pathsteps = $pathminsteps;
            while($pathsteps > 0)
            {
               $xcords--;
               if($xcords < 1) {
                  $xcords = 1;
                  $pathsteps = 0;
               }
               $pathsteps--;
               $querytext = sprintf("UPDATE `map` SET `%d` = '%d' WHERE `map`.`id` = %d",$xcords,$tile,$ycords);
               $query = $SQL->prepare($querytext);
               $query->execute();
            }
            $reversedirection = 2;
            $currentsteps--;
         }
      }      
      #printf("Cords: %d/%d\n",$xcords,$ycords); 
   }

   #Write start and exit points
   $querytext = sprintf("UPDATE `map` SET `%d` = '3' WHERE `map`.`id` = %d",$xcords,$ycords);
   $query = $SQL->prepare($querytext);
   $query->execute();
   #Flag Starting point of map
   $querytext = sprintf("UPDATE `map` SET `%d` = '2' WHERE `map`.`id` = %d",$STARTX,$STARTY);
   $query = $SQL->prepare($querytext);
   $query->execute();
}

# dd_privmsg
#
# Private message was sent to the bot 

sub dd_privmsg #$message, \%source
{
   my @parv;
   my $message = $_[0];
   my $source = $_[1];
   my $command;

   my $query;
   my $row;
   my $csource;
   my $id;
   my $handle;
   
   #split up parv by elements, $$parv[0] is now the command
   @parv = split(/\s+/, $message);

   
   $query = $SQL->prepare('SELECT id FROM player WHERE nick=?');
   $query->execute($$source{nickname});
   if($query->rows())
   {
       $row = $query->fetchrow_hashref();
       $id = $$row{id};
       if($csource = getsource($id))
       {
          if ($$source{handle} == $$csource{handle} )
          {
             $source = $csource;
          }
       }   
   }
  
   #Find command and flatten parameters down
   foreach $command (@CMDS)
   {
      if($parv[0] =~ /^$$command{cmd}$/i)
      {

         #determine if the player needs to be logged in, and isn't
         if($$command{lg} && !is_registered($$source{nickname}))
         {
            player_msg($source, 'You need to be logged in to use that command.');
            if($$source{SINGLE}) {
                 player_msg($source,"<END/>");
            } 
            return;            
         }

         if($$command{est})
         {
            if(!has_flag($$source{id}, 'established'))
            {
               player_msg($source, 'Your nation must be established before you can do that!');
               if($$source{SINGLE}) {
                    player_msg($source,"<END/>");
               } 
               return;               
            }
         }
         if($$command{quest} == 1)
         {
             if(!has_flag($$source{id}, 'quest'))
             {
                player_msg($source,'This command is not accessable outside a raid.');
                if($$source{SINGLE}) {
                    player_msg($source,"<END/>");
               } 
               return;               
            }  
         } elsif($$command{quest} == 0) {
             if(has_flag($$source{id}, 'quest'))
             {
                player_msg($source,'How can you manage your nation from inside a Raid?');
                if($$source{SINGLE}) {
                    player_msg($source,"<END/>");
               } 
               return;               
            }  
         }

         #calculate if the player has enough mp
         if($$command{mp})
         {
            $query = $SQL->prepare('SELECT mp FROM player WHERE id=?');
            $query->execute($$source{id});

            $row = $query->fetchrow_hashref();

            if($$command{mp} < 0 && !$$source{admin})
            {
               return;
            }

            if($$row{mp} < $$command{mp})
            {
               player_msg($source, sprintf("You don't have enough MP (%d).", $$command{mp}));
               if($$source{SINGLE}) {
                    player_msg($source,"<END/>");
               } 
               return;
            }
         }

         #squish the parameters
         if($$command{param} > 0 && @parv > 2)
         {
            push(@parv, join(' ', splice(@parv, $$command{param})));
         }
         
         #execute command and subtract mp from player
         if($$command{handler}(\@parv, $source))
         {
            if($$command{mp}) {
               sql_mp($$source{id}, -$$command{mp});
            }
            if($$source{SINGLE}) {
               #save quest state if there is one
               if(has_flag($$source{id}, 'quest')) {
                  $query = $SQL->prepare("SELECT x,y FROM quest_state WHERE player_id=?");
                  $query->execute($$source{id});
                  if($query->rows()) {
                     $query = $SQL->prepare("UPDATE quest_state SET x=?,y=? WHERE player_id=?");
                     $query->execute($$source{xcords},$$source{ycords},$$source{id});
                  } else {
                     $query = $SQL->prepare("INSERT INTO quest_state SET x=?,y=?,player_id=?");
                     $query->execute($$source{xcords},$$source{ycords},$$source{id});
                  }
               }
            }
         }

         if($$source{SINGLE}) {
            player_msg($source,"<END/>");
            
         } 
         return;
      }
   }

   player_msg($source, 'what???');
   if($$source{SINGLE}) {
        player_msg($source,"<END/>");
        
   } 
   return;
}

sub cmd_month 
{ 
   do_housekeeping();
}

sub cmd_ten
{
   do_tenminute();
}

sub cmd_newpass
{
   my $parv   = $_[0];
   my $source = $_[1];

   my $query;
   my $row;

   $query = $SQL->prepare('UPDATE player SET password=md5(?) WHERE nick=?');
   $query->execute($$parv[2], $$parv[1]);

   player_msg($source, 'Done.');

   return 1;
}

sub cmd_say
{
   my $parv   = $_[0];
   my $source = $_[1];

   global_msg($$parv[1]);
   player_msg($source, 'Done.');
}

sub cmd_msg
{
   my $parv   = $_[0];
   my $source = $_[1];

   my $target_source;

   my $query;
   my $row;

   $query = $SQL->prepare('SELECT id FROM player WHERE nick=?');
   $query->execute($$parv[1]);

   if(!$query->rows())
   {
      player_msg($source, 'No such player.');
      return
   }
   $row = $query->fetchrow_hashref();

   if(!($target_source = getsource($$row{id})))
   {
      player_msg($source, 'That player is not logged in.');
      return;
   }

   player_msg($target_source, $$parv[2]);
}

###########################################################################################
#                              COMMAND HANDLING FUNCTIONS                                 #
###########################################################################################


# cmd_newplayer
#
# NEWPLAYER

sub cmd_newplayer #\@parv, \%source
{
   my $parv   = $_[0];
   my $source = $_[1];
  
   my $query;
   my $row;

   my $password;

   if ($$source{nickname} =~ /^[a-zA-Z]+[a-zA-Z0-9-_-|]+[a-zA-Z0-9-_-|]$/) 
   {
      $query = $SQL->prepare('SELECT id FROM player WHERE nick = ?');
      $query->execute($$source{nickname});

      if($query->rows())
      {
         $row = $query->fetchrow_hashref();
         $query = $SQL->prepare('SELECT id FROM player WHERE nick = ? AND active=1');
         $query->execute($$source{nickname});
         if($query->rows())
         {
            player_msg($source, 'You already have sovereignty over a nation! Use the LOGIN command to login.');
            return 1;
         } else {
             $query = $SQL->prepare('UPDATE player SET active=1 WHERE nick= ?'); #Returning players just need to be activated
             $query->execute($$source{nickname});
             global_msg(sprintf("In the relentless pursuit of escaping Doomsday, $$source{nickname} has returned to claimed Sovereignty over %s",sql_getcountry(is_player($$source{nickname}))));
             
             #Legacy Check for older players to ensure a statistics row exists
             $query = $SQL->prepare("SELECT * FROM player_statistics WHERE player_id=?");
             $query->execute($$row{id});

             if($query->rows() == 0)
             {
                $query = $SQL->prepare("INSERT INTO player_statistics SET player_id=?,killed='0',died='0',launched='0',downed='0',wins='0'");
                $query->execute($$row{id});
             }
         }
      } else {
         $password = sprintf('None%d',int(rand 9999));

         player_msg($source, "Your password is $password. Please write it down. " . 
                    "You can change it later with the password command.");
 
         global_msg("In the relentless pursuit of escaping Doomsday, $$source{nickname} " . 
               "has claimed Sovereignty over $$source{nickname}opia.");

         $query = $SQL->prepare('INSERT INTO player SET nick=?,password=md5(?),country=?,government_id=?');
         $query->execute($$source{nickname}, $password, $$source{nickname} . 'opia',$GTYPE{anarchy});
         
         #bugfix for the Create stats line, somehow other than an error that didn't break the game but now the error is fixed too
         $query = $SQL->prepare('SELECT id FROM player WHERE nick = ?');
         $query->execute($$source{nickname});
         $row = $query->fetchrow_hashref();

         #Create Statitisics row for new players
         $query = $SQL->prepare("INSERT INTO player_statistics SET player_id=?,killed='0',died='0',launched='0',downed='0',wins='0'");
         $query->execute($$row{id});
      }

      #now we want their id
      $query = $SQL->prepare('SELECT id FROM player WHERE nick = ?');
      $query->execute($$source{nickname});

      #save their id in the dcc chat, we'll need it for later on
      #a live id is what proves you are validated
      if($query->rows())
      {
         $row = $query->fetchrow_hashref();
         $$source{id} = $$row{id};
         #print $$row{id} . "\n";
      }

      register_player($source);
   }
   else
   { 
       player_msg($source,"Nicknames must start with a letter and contain characters A-Z and 0-9"); 
       return;
   }    
}

sub cmd_add_ai 
{
   my $parv   = $_[0];
   my $source = $_[1];
  
   my $query;
   my $row;
   my $id;
   
   my $password;
   my $choice;
      
   $password = sprintf('None%d',int(rand 9999));
   $choice = int(rand 100);
   
   global_msg("In the relentless pursuit of escaping Doomsday, $$parv[1] " . 
               "has claimed Sovereignty over $$parv[1]Land.");

   $query = $SQL->prepare('INSERT INTO player SET nick=?,password=md5(?),country=?,government_id=?');
   $query->execute($$parv[1], $password, $$parv[1] . 'Land',$GTYPE{anarchy});


   #now we want their id
   $query = $SQL->prepare('SELECT id FROM player WHERE nick = ?');
   $query->execute($$parv[1]);
   $row = $query->fetchrow_hashref();
   
   set_flag($$row{id},'ai');
   
   if (($choice > 40) && ($choice < 65) ) {
   	set_flag($$row{id},'hard');
   	$query = $SQL->prepare('UPDATE player SET surrender=? WHERE id=?');
      	$query->execute((int(rand 20) + 25), $$row{id});
   } elsif ($choice > 64) {
   	set_flag($$row{id},'medium');
        $query = $SQL->prepare('UPDATE player SET surrender=? WHERE id=?');
        $query->execute((int(rand 20) + 20), $$row{id});
    } else {
   	set_flag($$row{id},'easy');
   }
}
# cmd_advise
#
# ADVISE <player>

sub cmd_advise #\@parv, \%source
{
   my $parv   = $_[0];
   my $source = $_[1];

   my $query;
   my $row;

   $query = $SQL->prepare('SELECT id,nick,land FROM player WHERE nick=?');
   $query->execute($$parv[1]);

   if($query->rows())
   {
      $row = $query->fetchrow_hashref();
      if($$row{id} == $$source{id})
      {
         player_msg($source, 'You can\'t advise against yourself...');
         return 0;
      }

      if(bully($$source{id}, $$row{id}, 0))
      {
          if (sql_retaliation($$source{id},$$row{id})) {
	      	   player_msg($source, sprintf('Your nation\'s political leaders have determined that due to outrage from prior unanswered attacks %s (%d land) is ' . 
	                                  'within your political grasp at this time.', $$row{nick}, $$row{land}));   
          } else {
             player_msg($source, sprintf('Your nation\'s political leaders advise against attacking %s (%d land) at this time. (-Favor)',
                          $$row{nick}, $$row{land}));
          }    
      }
      elsif(antibully($$source{id}, $$row{id}, 0))
      {
         player_msg($source, sprintf('Your nation\'s political leaders have determined that %s (%d land) is ' .
                                  'within your political grasp at this time. (+Favor)', $$row{nick}, $$row{land}));
      }
      else
      {
         player_msg($source, sprintf('Your nation\'s political leaders have determined that %s (%d land) is ' . 
                                  'within your political grasp at this time.', $$row{nick}, $$row{land}));
      }

      return 1;
   }
   else
   {
      player_msg($source, 'There is no such player in this world.');
      return 0; 
   }
}


# cmd_allocate
#
# ALLOCATE <0-100%> <research topic>

sub cmd_allocate #\@parv, \%source
{
   my $parv   = $_[0];
   my $source = $_[1];

   my $query;
   my $row;
   my $row2;
   
   my $allocation = int($$parv[1]);
   my $topic = $$parv[2];

   if($allocation < 0 || $allocation > 100)
   {
      player_msg($source, 'You must specify a valid percentage to allocate (0-100%).');
      return 0;
   }

 
   #First check if this research type exists, and if so get us an id and the prereq
   $query = $SQL->prepare('SELECT id, prereq, name FROM researchtype ' .
                          'WHERE name = ?');
   $query->execute($topic);

   if(!$query->rows())
   {
      player_msg($source, 'No such topic exists. Check REPORT RESEARCH for a listing');
      return 0;
   }

   $row = $query->fetchrow_hashref();

   #next check if we even have room for this allocation!
   $query = $SQL->prepare('SELECT sum(allocation) AS allocation ' .
                          'FROM research WHERE player_id = ? AND research_id != ?');

   $query->execute($$source{id}, $$row{id});

   $row2 = $query->fetchrow_hashref();

   if($allocation > (100 - $$row2{allocation}))
   {
      player_msg($source, sprintf('You can only allocate a maximum of %d%%. Free up ' .
                               'research allocation if more is needed.',
                               100 - $$row2{allocation}));
      return 0;
   }


   #next, if there is a prereq, lets check it out first
   if($$row{prereq})
   {
      if(!sql_has_research($$source{id}, $$row{prereq}))
      {
         player_msg($source, 'Your nation does not yet possess the knowledge required to research ' .
                          'such a subject');
         return 0;
      }
   }

   #Now we check if the actual level of what we want to research is already 100 (complete)
   $query = $SQL->prepare('SELECT level FROM research WHERE research_id=? AND player_id=?');
   $query->execute($$row{id}, $$source{id});
   
   #change the allocation if we can learn more on this topic
   if($query->rows())
   {
      $row2 = $query->fetchrow_hashref();
      if($$row2{level} == 100)
      {
         player_msg($source, 'Your nation has learnt all it can about that topic already.');
         return 0;
      }
      else
      {
         $query = $SQL->prepare('UPDATE research SET allocation=? WHERE player_id=? AND research_id=?');
         $query->execute($allocation, $$source{id}, $$row{id});
      }
   }
   else
   {
      $query = $SQL->prepare('INSERT INTO research SET allocation=?, player_id=?, research_id=?, level=0');
      $query->execute($allocation, $$source{id}, $$row{id});
   }

   #if we got this far the allocation was changed
   player_msg($source, sprintf('%d%% of your science team has been allocated to research %s.',
                            $allocation, $$row{name}));

   return 1; 
}

# cmd_attack
#
# ATTACK <player>

sub cmd_attack #\@parv, \%source
{
   my $parv   = $_[0];
   my $attacker_source = $_[1];
   my $defender_source;
 
   my %attacker;
   my %defender;

   my @attacker_units;
   my @defender_units;

   my $attacker_unit;
   my $defender_unit;

   my $attacker_power;
   my $defender_power;

   my @attacker_formation;
   my @defender_formation;

   my $switch = 0; #switch off between being attacker/defender
   my $counter;
   my $dice;
   my $i;

   my $query;
   my $row;

   my $round;
   
   my $aiattack;
   
   #can only ATTACK once per every 15 seconds
   if(time - $$attacker_source{last_attack} < 15)
   {
      player_msg($attacker_source, 'Your troops must rest before attacking again!');
      return 0;
   }


   $query = $SQL->prepare('SELECT id,surrender,nick,land FROM player WHERE nick=? AND active=1');
   $query->execute($$parv[1]);
   
   if(!$query->rows())
   {
      player_msg($attacker_source, 'No player by that name exists in this world.');
      return 0;
   }

   $row = $query->fetchrow_hashref();

   $defender{id} = $$row{id}; 
   $defender{surrender} = $$row{surrender} * .01;
   $defender{nick} = $$row{nick};
   $defender{land} = $$row{land};
   $defender{title} = sql_gettitle($defender{id});
   $defender{titlecountry} = sql_gettitlecountry($defender{id});
   $defender{country} = sql_getcountry($defender{id});
   $defender_source = getsource($defender{id});

   if(!has_flag($defender{id},'established'))
   {
      player_msg($attacker_source, 'You cannot attack an unestablished nation.');
      return;
   }
   #get attacker surrender
   $query = $SQL->prepare('SELECT surrender FROM player WHERE id=?');
   $query->execute($$attacker_source{id});
   $row = $query->fetchrow_hashref();

   $attacker{surrender} = $$row{surrender} * .01;
   $attacker{id} = $$attacker_source{id};
   $attacker{nick} = $$attacker_source{nickname};
   $attacker{title} = sql_gettitle($attacker{id});
   $attacker{country} = sql_getcountry($attacker{id});
   $attacker{titlecountry} = sql_gettitlecountry($attacker{id});

 
   #CHECK TO SEE IF BOTH SIDES HAVE ENOUGH UNITS
   if($attacker{id} == $defender{id})
   {
      player_msg($attacker_source, 'It would not be a feasible marketing campaign to attack yourself!');
      return 0;
   }
       
   $query = $SQL->prepare('SELECT unittype.attack, unittype.defense, unittype.name, unit.unit_id, unit.amount, unit.player_id, unit.id FROM unittype, unit WHERE unittype.id = unit.unit_id AND (unit.player_id=? OR unit.player_id=?) AND unittype.type=?');

   $query->execute($attacker{id}, $defender{id}, $UTYPE{ground});

   if(!$query->rows())
   {
      player_msg($attacker_source, 'How can a war occur if neither side have any units?!');
      return 0;
   }

   #SORT PLAYER UNITS AND CALCULATE ATTACK/DEFENSE TOTAL VALUES
   while($row = $query->fetchrow_hashref())
   {
      if($$row{player_id} == $attacker{id})
      {
         push @attacker_units, $row;
         $attacker{unit_total} += $$row{amount};
         $attacker{attack_power} += $$row{amount} * $$row{attack};
         $attacker{defense_power} += $$row{amount} * $$row{defense};
      }
      else
      {
         push @defender_units, $row;
         $defender{unit_total} += $$row{amount};
         $defender{attack_power} += $$row{amount} * $$row{attack};
         $defender{defense_power} += $$row{amount} * $$row{defense};
      }
   }
   #DETERMINE UNIT INITIAL TOTALS AND CURRENT TOTALS
   $attacker{unit_init_total} = $attacker{unit_total};
   $defender{unit_init_total} = $defender{unit_total};

   if(!@attacker_units)
   {
      player_msg($attacker_source, 'Your nation does not have any ground units to attack with!');
      return;
   }


   player_msg($attacker_source, sprintf('You have declared a state of war with %s', 
                             $defender{title} ));
   player_msg($defender_source, sprintf('%s has declared war with your nation!', 
                             $attacker{title} ));
   sql_log($defender{id},    'DEFENSE', 
                             sprintf('%s has declared war with your nation!',
                             $attacker{title} ));

   global_msg(sprintf('In a ground force attack, %s has declared ' . 
                       'war on %s.',
                       $attacker{titlecountry}, $defender{titlecountry} ));

   #show eachother's units!
   player_msg($attacker_source, 'Your scouts report the following enemy defense positions:');
   player_msg($attacker_source, sql_military($defender{id}));

   player_msg($defender_source, 'Your scouts report the following enemy ground units:');
   player_msg($defender_source, sql_military($attacker{id}));

  
   #determine if attacker forces are exceedingly powerful
   if(bully($attacker{id}, $defender{id}, 1))
   {
      if (sql_retaliation($attacker{id},$defender{id})) {
          #revenge is a dish best served cold
          global_msg(sprintf('The people of %s demand someone pay for the attacks against their nation',$attacker{country}));
          if ($defender{surrender} > .5) { $defender{surrender} = .5 } #Retaliation has a max surrender of 50% to avoid an exploit where people give their land to larger players using retaliation
          sql_retaliated($attacker{id},$defender{id});
      }
      global_msg(sprintf('The citizens of %s scramble in terror at the massive power of the attacking forces.',$defender{country}));
   }
   elsif(antibully($attacker{id}, $defender{id}, 1))
   {
      sql_add_retaliation($defender{id}, $attacker{id}); #add an attack to the defenders retaliation table as this player is outside of their range
      global_msg(sprintf('The citizens of %s stand proud to fight the massive power of the defending force.',
                         $attacker{country}));
   }

   #if defense will be potentially going UNDER their minland, fight for the death 
   if(($defender{land} - ($defender{land} * $defender{surrender})) < $GAME_OPTIONS{minland})
   {
      #fight to the death
      $defender{surrender} = 1;
      global_msg(sprintf('The forces of %s are prepared to fight ' . 
                          'to the death for their nation!', $defender{title} ));
   }
   
   #Grab formation tables
   $query = $SQL->prepare("SELECT player_id, formation FROM player_formation WHERE player_id=? OR player_id=?");
   $query->execute($attacker{id},$defender{id});

   if($query->rows()) {
      while($row = $query->fetchrow_hashref())
      {
           if($$row{player_id} == $attacker{id}) {
              @attacker_formation = split(/,\s/,$$row{formation});
           } else {
              @defender_formation = split(/,\s/,$$row{formation});
           }

      }
   }

   while(1)
   {
      $round++;
 
      #choose an attacker unit 
      $counter = 0;
      
      $dice = rand(1);
      
      for($i = 0; $i < @attacker_units; $i++)
      {
         $attacker_unit = $attacker_units[$i];
         #printf("F %s\nU %s",$attacker_formation[0],$$attacker_unit{unit_id});
         if(@attacker_formation) {
             last if(($attacker_formation[0] == $$attacker_unit{unit_id}) && ($$attacker_unit{amount} > 0));
             if(($attacker_formation[0] == $$attacker_unit{unit_id}) && ($$attacker_unit{amount} <= 0)) {
                shift(@attacker_formation);
                $i = -1; #the for loop ++'s it so if the next unit is 0 it gets skipped and you run into ghost unit issues
             }
         } else {
            if($$attacker_unit{amount} > 0) {
               last if( ($counter += $$attacker_unit{amount} / $attacker{unit_total}) > $dice);
            }
         }
      } 
      #printf("Attacker unit: %d\n", $$attacker_unit{unit_id});

      #choose a defender unit
      $counter = 0;
      $dice = rand(1);
      for($i = 0; $i < @defender_units; $i++)
      {
         $defender_unit = $defender_units[$i];
         #printf("F %s\nU %s",$defender_formation[0],$$defender_unit{unit_id});

         if(@defender_formation) {
             last if(($defender_formation[0] == $$defender_unit{unit_id}) && ($$defender_unit{amount} > 0));
             if(($defender_formation[0] == $$defender_unit{unit_id}) && ($$defender_unit{amount} <= 0)) {
                shift(@defender_formation);
                $i = -1; #the for loop ++'s it so if the next unit is 0 it gets skipped and you run into ghost unit issues
             }
         } else {
            if($$defender_unit{amount} > 0) {
               last if( ($counter += $$defender_unit{amount} / $defender{unit_total}) > $dice);
            }
         }
      }

      #printf("Defender unit: %d\n", $$defender_unit{unit_id});
      
      if(!$switch)
      {
         $attacker_power = $$attacker_unit{attack};
         $defender_power = $$defender_unit{defense};
      } 
      else
      {
         $attacker_power = $$attacker_unit{defense};
         $defender_power = $$defender_unit{attack};
      }
   
      $counter = 100 / ($attacker_power + $defender_power);
      $dice = rand(100);
      if($dice < $attacker_power * $counter)
      {
         #if attacker won AND he was attacking, defender loses unit
         if(!$switch)
         {
            $defender{unit_total}--;
            $$defender_unit{amount}--;
         }
      }
      else
      {
         #if defender won AND he was attacking, attacker loses a unit
         if($switch)
         {
            $attacker{unit_total}--;
            $$attacker_unit{amount}--;
         }

     }

      #rotate switch
      if($switch) { $switch = 0 } else { $switch = 1 };
 
      if($attacker{unit_total} <= 0 || 
         ((1 - $attacker{unit_total} / $attacker{unit_init_total}) > $attacker{surrender}))
      {

         #announce winners, no pillage if defender won!
         player_msg($attacker_source, sprintf('%s has pushed back your forces in a counter-attack!',$defender{nick}));
         player_msg($defender_source, 'The opposing forces have surrendered!');
         sql_log($defender{id}, 'DEFENSE', 'The opposing forces have surrendered!');
         global_msg(sprintf('The defense of %s counter-attacks %s and eliminates %d%% ' .
                             'of the advancing force.',
                             $defender{title}, $attacker{title}, 
                             100 * (1 - $attacker{unit_total} / $attacker{unit_init_total})));

         altfavor($defender{id}, $defender{surrender} * $FAVOR{war_win});
         altfavor($attacker{id}, $attacker{surrender} * $FAVOR{war_lose});
         if(has_flag($defender{id},'ai')) {
             sql_add_achievement($attacker{id},"NPC Thrashing");
             
         }
	 #if the defender is offline try to send an e-mail
	 if (!$defender_source) 
         {
            cmd_sendmail($defender{id},sprintf("You have fought back an attack from %s\n\n--Doomsday\n",$attacker{nick}));
         }
         #flag for AI to attack
	     $aiattack = 1;
         last;
      }

      if($defender{unit_total} <= 0 ||  
         ((1 - $defender{unit_total} / $defender{unit_init_total}) > $defender{surrender}))      
      {


         #announce and pillage!
         player_msg($attacker_source, 'You are victorious! The opposing forces have surrendered.');
         player_msg($defender_source, 'You have been defeated!');
         sql_log($defender{id}, 'DEFENSE', 'You have been defeated!');
         global_msg(sprintf('In a moment of victory, %s has won the war over %s.',
                             $attacker{titlecountry}, $defender{titlecountry}));
         sql_pillage($attacker_source, $attacker{id}, $defender{id},$defender{surrender});

         #do favor alt
         altfavor($defender{id}, $defender{surrender} * $FAVOR{war_lose});
         altfavor($attacker{id}, $attacker{surrender} * $FAVOR{war_win});

         #if the defender is offline try to send an e-mail
         if (!$defender_source)
         {
            cmd_sendmail($defender{id},sprintf("%s has attacked you and defeated your army\n\n--Doomsday\n",$attacker{nick}));
         }
         if(has_flag($attacker{id},'ai')) {
             sql_add_achievement($defender{id},"NPC Thrashing");
             
         }
         last;
      }
      #stalemate
      if($round > 3 * (($defender{unit_init_total} + $attacker{unit_init_total}) / 2) * 
                  (($defender{surrender} + $attacker{surrender}) / 2))
      {


         player_msg($attacker_source, sprintf('You are unable to break the defenses of %s.',
                               $defender{title}));
         player_msg($defender_source, 'The opposing forces are no match for your defense!');
         sql_log($defender{id}, 'DEFENSE',  'The opposing forces are no match for your defense!');
         global_msg(sprintf('The forces of %s hold their defense.',
                             $defender{title}));


         #do favor alt
         altfavor($defender{id}, $defender{surrender} * $FAVOR{war_defend});
         $aiattack = 1;
	 last; 
      }
   }

   player_msg($attacker_source, sprintf('Your troops report %d units lost, and %d enemy units lost, in battle.',
                           $attacker{unit_init_total} - $attacker{unit_total},
                           $defender{unit_init_total} - $defender{unit_total}));

   player_msg($defender_source, sprintf('Your troops report %d units lost, and %d enemy units lost, in battle.',
                           $defender{unit_init_total} - $defender{unit_total},
                           $attacker{unit_init_total} - $attacker{unit_total}));
   sql_log($defender{id}, 'DEFENSE', sprintf('Your troops report %d units lost, and %d enemy units lost, in battle.',
                           $defender{unit_init_total} - $defender{unit_total},
                           $attacker{unit_init_total} - $attacker{unit_total}));


   #update the killed/died amounts attacker and defender
   if(!has_flag($attacker{id},'ai')) 
   {
      #attacker
      $query = $SQL->prepare("UPDATE player_statistics SET killed=(killed + ?),died=(died + ?) WHERE player_id=?");
      $query->execute(($defender{unit_init_total} - $defender{unit_total}),($attacker{unit_init_total} - $attacker{unit_total}),$attacker{id});
   }
   if(!has_flag($defender{id},'ai'))
   {
      #defender
      $query = $SQL->prepare("UPDATE player_statistics SET killed=(killed + ?),died=(died + ?) WHERE player_id=?");
      $query->execute(($attacker{unit_init_total} - $attacker{unit_total}),($defender{unit_init_total} - $defender{unit_total}),$defender{id});
   }
   #lets update the unit tables to reflect the loss
   foreach $attacker_unit (@attacker_units)
   {
      $query = $SQL->prepare('UPDATE unit SET amount=? WHERE id=?');
      $query->execute($$attacker_unit{amount}, $$attacker_unit{id});
   }

   foreach $defender_unit (@defender_units)
   {
      $query = $SQL->prepare('UPDATE unit SET amount=? WHERE id=?');
      $query->execute($$defender_unit{amount}, $$defender_unit{id});
   }

   global_msg('The war has ended.');

   #keep track of last attack time
   $$attacker_source{last_attack} = time;
    
    #If the defending country was an AI and the attack variable is set it is time to make humans cry!
   if(has_flag($defender{id},'ai') && $aiattack == 1) {
	    do_ai_attack($defender{id},$attacker{nick});
   }
   return 1;
}


# cmd_bomb
#
# BOMB <player>

sub cmd_bomb #\@parv, \%source
{
   my $parv   = $_[0];
   my $attacker_source = $_[1];
   my $defender_source;
 
   my %attacker;
   my %defender;

   my @attacker_units;
   my @defender_units;

   my $attacker_unit;
   my $defender_unit;

   my $attacker_power;
   my $defender_power;

   my $switch = 0; #switch off between being attacker/defender
   my $counter;
   my $dice;
   my $i;

   my $query;
   my $row;
   
   my $round;
   my $structures; #amount of structures
   my $aiattack;
   
   #can only BOMB once per every 15 seconds
   if(time - $$attacker_source{last_bomb} < 15)
   {
      player_msg($attacker_source, 'Your planes must refuel before attacking again!');
      return 0;
   }
   #Check if attacker has airfields
   $query = $SQL->prepare('SELECT id FROM structure WHERE player_id=? AND structure_id=? AND amount > 0');
   $query->execute($$attacker_source{id},$AIRFIELD);

   if(!$query->rows()) {
      player_msg($attacker_source,'You have no airfield for your planes');
      return 0;
   }
   
   #Check if defender exists
   $query = $SQL->prepare('SELECT id,surrender,nick,land FROM player WHERE nick=? AND active=1');
   $query->execute($$parv[1]);
   
   if(!$query->rows())
   {
      player_msg($attacker_source, 'No player by that name exists in this world.');
      return 0;
   }

   $row = $query->fetchrow_hashref();

   $defender{id} = $$row{id}; 
   $defender{surrender} = $$row{surrender} * .01;
   $defender{nick} = $$row{nick};
   $defender{land} = $$row{land};
   $defender{title} = sql_gettitle($defender{id});
   $defender{titlecountry} = sql_gettitlecountry($defender{id});
   $defender{country} = sql_getcountry($defender{id});
   $defender_source = getsource($defender{id});

   if(!has_flag($defender{id},'established'))
   {
      player_msg($attacker_source, 'You cannot bomb an unestablished nation.');
      return;
   }
   
   #check for BOMB_ID
   if ($$parv[2])
   {
      $query = $SQL->prepare('SELECT structure.amount, structure.player_id FROM structure WHERE structure.id=? AND structure.player_id=?');
      $query->execute($$parv[2],$defender{id});
      if (!$query->rows())
      {
	     player_msg($attacker_source,'Invalid Bomb ID');
	     return 0;
      }      
      $structures = $query->fetchrow_hashref(); 
      if ($$structures{amount} < 1) {
	     player_msg($attacker_source,'There are no structures remaining under that ID');
	     return 0;
      }
   }
 
   #get attacker surrender
   $query = $SQL->prepare('SELECT surrender,recon FROM player WHERE id=?');
   $query->execute($$attacker_source{id});
   $row = $query->fetchrow_hashref();

   if ($$structures{amount}) 
   {
      if ($$row{recon} != $defender{id}) 
  	  {
	      player_msg($attacker_source,'You must have a Recon spy stationed in this nation in order to specify bombing targets');
	      return 0;         
      }
   }
   $attacker{surrender} = $$row{surrender} * .01;
   $attacker{id} = $$attacker_source{id};
   $attacker{nick} = $$attacker_source{nickname};
   $attacker{title} = sql_gettitle($attacker{id});
   $attacker{country} = sql_getcountry($attacker{id});
   $attacker{titlecountry} = sql_gettitlecountry($attacker{id});

 
   #CHECK TO SEE IF BOTH SIDES HAVE ENOUGH UNITS
   if($attacker{id} == $defender{id})
   {
      player_msg($attacker_source, 'It would not be a feasible marketing campaign to bomb yourself!');
      return 0;
   }

   $query = $SQL->prepare('SELECT unittype.attack, unittype.defense, unittype.name, ' . 
                          'unit.amount, unit.player_id,unit.id ' . 
                          'FROM unittype, unit ' .  
                          'WHERE unittype.id = unit.unit_id AND unit.amount > 0 ' . 
                          'AND (unit.player_id=? OR unit.player_id=?) AND ' .
                          'unittype.type=?');

   $query->execute($attacker{id}, $defender{id}, $UTYPE{air});

   if(!$query->rows())
   {
      player_msg($attacker_source, 'How can a war occur if neither side have any units?!');
      return 0;
   }

   #SORT PLAYER UNITS AND CALCULATE ATTACK/DEFENSE TOTAL VALUES
   while($row = $query->fetchrow_hashref())
   {
      if($$row{player_id} == $attacker{id})
      {
         push @attacker_units, $row;
         $attacker{unit_total} += $$row{amount};
         $attacker{attack_power} += $$row{amount} * $$row{attack};
         $attacker{defense_power} += $$row{amount} * $$row{defense};
      }
      else
      {
         push @defender_units, $row;
         $defender{unit_total} += $$row{amount};
         $defender{attack_power} += $$row{amount} * $$row{attack};
         $defender{defense_power} += $$row{amount} * $$row{defense};
      }
   }
   #DETERMINE UNIT INITIAL TOTALS AND CURRENT TOTALS
   $attacker{unit_init_total} = $attacker{unit_total};
   $defender{unit_init_total} = $defender{unit_total};

   if(!@attacker_units)
   {
      player_msg($attacker_source, 'Your nation does not have any Bombers to attack with!');
      return;
   }


   player_msg($attacker_source, sprintf('You have launched an air strike against %s', 
                             $defender{title} ));
   player_msg($defender_source, sprintf('%s has launched an Airstrike against your nation!', 
                             $attacker{title} ));
   sql_log($defender{id},    'DEFENSE', 
                             sprintf('%s launched an Airstrike against your nation!',
                             $attacker{title} ));

   global_msg(sprintf('In an Airstrike attack, %s has declared ' . 
                       'war on %s.',
                       $attacker{titlecountry}, $defender{titlecountry} ));

   #show eachother's units!
   player_msg($attacker_source, 'Your scouts report the following enemy defenses:');
   player_msg($attacker_source, sql_airforce($defender{id}));

   player_msg($defender_source, 'Your scouts report the following enemy plane:');
   player_msg($defender_source, sql_airforce($attacker{id}));

  
   #determine if attacker forces are exceedingly powerful
   if(bully($attacker{id}, $defender{id}, 1))
   {
      if (sql_retaliation($attacker{id},$defender{id})) {
          #revenge is a dish best served cold
          global_msg(sprintf('The people of %s demand someone pay for the attacks against their nation',$attacker{country}));
          if ($defender{surrender} > .5) { $defender{surrender} = .5 } #Retaliation has a max surrender of 50% to avoid an exploit where people give their land to larger players using retaliation
          sql_retaliated($attacker{id},$defender{id});
      }   
      global_msg(sprintf('The citizens of %s scramble in terror at the massive power of the attacking forces.',
                         $defender{country}));
   }
   elsif(antibully($attacker{id}, $defender{id}, 1))
   {
      sql_add_retaliation($defender{id}, $attacker{id}); #add an attack to the defenders retaliation table as this player is outside of their range
      global_msg(sprintf('The pilots of %s are proud to fight the massive power of the defending force.',
                         $attacker{country}));
   }

   while(1)
   {
      $round++;
 
      #choose an attacker unit 
      $counter = 0;
      $dice = rand(1);
      for($i = 0; $i < @attacker_units; $i++)
      {
         $attacker_unit = $attacker_units[$i];
         last if( ($counter += $$attacker_unit{amount} / $attacker{unit_total}) > $dice);
      } 

      #choose a defender unit
      $counter = 0;
      $dice = rand(1);
      for($i = 0; $i < @defender_units; $i++)
      {
         $defender_unit = $defender_units[$i];
         last if( ($counter += $$defender_unit{amount} / $defender{unit_total}) > $dice);
      }


      if(!$switch)
      {
         $attacker_power = $$attacker_unit{attack};
         $defender_power = $$defender_unit{defense};
      } 
      else
      {
         $attacker_power = $$attacker_unit{defense};
         $defender_power = $$defender_unit{attack};
      }
   
      $counter = 100 / ($attacker_power + $defender_power);
      $dice = rand(100);
      if($dice < $attacker_power * $counter)
      {
         #if attacker won AND he was attacking, defender loses unit
         if(!$switch)
         {
            $defender{unit_total}--;
            $$defender_unit{amount}--;
         }
      }
      else
      {
         #if defender won AND he was attacking, attacker loses a unit
         if($switch)
         {
            $attacker{unit_total}--;
            $$attacker_unit{amount}--;
         }

     }

      #rotate switch
      if($switch) { $switch = 0 } else { $switch = 1 };
 
      if($attacker{unit_total} <= 0 || 
         ((1 - $attacker{unit_total} / $attacker{unit_init_total}) > $attacker{surrender}))
      {

         #announce winners, no pillage if defender won!
         player_msg($attacker_source, sprintf('%s has pushed back your forces in a counter-attack!', 
                               $defender{nick}));
         player_msg($defender_source, 'The opposing forces have surrendered!');
         sql_log($defender{id}, 'DEFENSE', 'The opposing forces have surrendered!');
         global_msg(sprintf('The defense of %s counter-attacks %s and eliminates %d%% ' .
                             'of the advancing force.',
                             $defender{title}, $attacker{title}, 
                             100 * (1 - $attacker{unit_total} / $attacker{unit_init_total})));

         altfavor($defender{id}, $defender{surrender} * $FAVOR{war_win});
         altfavor($attacker{id}, $attacker{surrender} * $FAVOR{war_lose});
	 #flag for AI to attack
	 $aiattack = 1;
         last;
      }

      if($defender{unit_total} <= 0 ||  
         ((1 - $defender{unit_total} / $defender{unit_init_total}) > $defender{surrender}))      
      {


         #announce and pillage!
         player_msg($attacker_source, 'You are victorious! The opposing forces have been destroyed!');
         player_msg($defender_source, 'You have been defeated!');
         sql_log($defender{id}, 'DEFENSE', 'You have been defeated!');
         global_msg(sprintf('In a moment of victory, %s has won the war over %s.',
                             $attacker{titlecountry}, $defender{titlecountry}));
         
         #if the defender is offline try to send an e-mail
         if (!$defender_source)
         {  
            cmd_sendmail($defender{id},sprintf("%s launched and air strike against you and defeated your airforce\n\n--Doomsday\n",$attacker{nick}));
         }

         if (sql_hasbombers($attacker{id}) > 0) {
            if ($$structures{amount}) 
            {
               sql_bomb_id($attacker_source,$attacker{id}, $defender{id},$$parv[2]); 	 
            } else {
               sql_bomb($attacker_source, $attacker{id}, $defender{id});
            }
          } else {
            global_msg(sprintf("%s is spared from assault as no bombers have survived the dogfight",$defender{titlecountry}));
         }
         #do favor alt
         altfavor($defender{id}, $defender{surrender} * $FAVOR{war_lose});
         altfavor($attacker{id}, $attacker{surrender} * $FAVOR{war_win});


         last;
      }
      #stalemate
      if($round > 3 * (($defender{unit_init_total} + $attacker{unit_init_total}) / 2) * 
                  (($defender{surrender} + $attacker{surrender}) / 2))
      {


         #if the defender is offline try to send an e-mail
         if (!$defender_source)
         {  
            cmd_sendmail($defender{id},sprintf("Your airforce was able to protect your airspace from %s\n\n--Doomsday\n",$attacker{nick}));
         }

         player_msg($attacker_source, sprintf('You are unable to break the defenses of %s.',
                               $defender{title}));
         player_msg($defender_source, 'The opposing forces are no match for your defense!');
         sql_log($defender{id}, 'DEFENSE',  'The opposing forces are no match for your defense!');
         global_msg(sprintf('The forces of %s hold their defense.',
                             $defender{title}));


         #do favor alt
         altfavor($defender{id}, $defender{surrender} * $FAVOR{war_defend});
         $aiattack = 1;
	 last; 
      }
   }

   player_msg($attacker_source, sprintf('Your pilots report %d units lost, and %d enemy units lost, in battle.',
                           $attacker{unit_init_total} - $attacker{unit_total},
                           $defender{unit_init_total} - $defender{unit_total}));

   player_msg($defender_source, sprintf('Your pilos report %d units lost, and %d enemy units lost, in battle.',
                           $defender{unit_init_total} - $defender{unit_total},
                           $attacker{unit_init_total} - $attacker{unit_total}));
   sql_log($defender{id}, 'DEFENSE', sprintf('Your pilots report %d units lost, and %d enemy units lost, in battle.',
                           $defender{unit_init_total} - $defender{unit_total},
                           $attacker{unit_init_total} - $attacker{unit_total}));


   #lets update the unit tables to reflect the loss
   foreach $attacker_unit (@attacker_units)
   {
      $query = $SQL->prepare('UPDATE unit SET amount=? WHERE id=?');
      $query->execute($$attacker_unit{amount}, $$attacker_unit{id});
   }

   foreach $defender_unit (@defender_units)
   {
      $query = $SQL->prepare('UPDATE unit SET amount=? WHERE id=?');
      $query->execute($$defender_unit{amount}, $$defender_unit{id});
   }

   global_msg('The war has ended.');

   #keep track of last attack time
   $$attacker_source{last_bomb} = time;
    
    #If the defending country was an AI and the attack variable is set it is time to make humans cry!
   #if(has_flag($defender{id},'ai') && $aiattack == 1) {
	 #   do_ai_attack($defender{id},$attacker{nick});
   #}
   return 1;
}

# cmd_build
#
# BUILD <amount> <structure>

sub cmd_build #\@parv, \%source
{
   my $parv   = $_[0];
   my $source = $_[1];

   my $query;

   my $structure;
   my $land;
   my $player;
   my $cost;
 
   $query = $SQL->prepare('SELECT name, id, cost, size, prereq ' .
                          'FROM structuretype ' . 
                          'WHERE structuretype.name=?');

   $query->execute($$parv[1]);
   
   if(!$query->rows())
   {
      player_msg($source, 'Your engineers search through their computers and cannot find blueprints on that' .
                       ' structure.');
      return 0;
   }

   $structure = $query->fetchrow_hashref();

   if($$structure{prereq} && !sql_has_research($$source{id}, $$structure{prereq}))
   {
      player_msg($source, 'Your research on that structure is not yet complete.');
      return 0;
   }

   #check land use + size, and cost of structure
   $query = $SQL->prepare('SELECT money,land FROM player WHERE id=?');
   $query->execute($$source{id});
   $player = $query->fetchrow_hashref();

   if((($$structure{size}) + sql_landuse($$source{id},0)) > $$player{land})
   {
      player_msg($source, "Your nation does not have enough land to support the new structures."); 
      return 0
   }


   $cost = $$structure{cost};

   if($cost > $$player{money})
   {
      player_msg($source, sprintf("Your nation cannot afford that construction.", $cost));
      return 0;
   }

   #this far? all is okay, build the structure
   sql_build($$source{id}, $$structure{id}, 1);
   sql_money($$source{id}, -$cost);

   player_msg($source, sprintf('Your engineers construct a %s', $$structure{name}));   

   return 1;
}


# cmd_bulldoze
#
# BULLDOZE <structure>

sub cmd_bulldoze #\@parv, \%source
{
   my $parv   = $_[0];
   my $source = $_[1];

   my $query;
   my $row;

   my $structure;

   $query = $SQL->prepare('SELECT structuretype.name, structure.id, structuretype.cost, structuretype.size, ' . 
                          'structure.amount ' .
                          'FROM structuretype, structure ' .
                          'WHERE structuretype.name=? AND structure.player_id=? AND structure.amount > 0 ' . 
                          'AND structuretype.id = structure.structure_id');
   $query->execute($$parv[1], $$source{id});

   if(!$query->rows())
   {
      player_msg($source, 'Your nation does not have any structures of that name. Check REPORT LAND.');
      return 0;
   }

  $row = $query->fetchrow_hashref();

  $query = $SQL->prepare('UPDATE structure SET amount = amount - 1 WHERE id=?');
  $query->execute($$row{id});

  sql_money($$source{id}, $$row{cost} / 2);

  player_msg($source, sprintf('Demolition crews have destroyed a %s, freeing up %d land. You have gained $%d from the ' . 
                           'raw materials.', $$row{name}, $$row{size}, $$row{cost} / 2));

  sql_balance_workers($$source{id});
  sql_balance_scientists($$source{id});

  return 1;
}

sub cmd_buy
{
   #hail CrazySpence
   my $parv   = $_[0];
   my $source = $_[1];
   my $query;
   my $row;
   my $mid = $$parv[1];
   my $amount = $$parv[2];
   my $sellersource;
   $mid =~ /^[\d]+$/; 
   $amount =~ /^[\d]+$/; 
   
   if($amount <= 0 || $mid <= 0)
     {
          player_msg($source, 'You must specify positive numerical values');
          return 0;
     } 

   $query = $SQL->prepare('SELECT market.id, market.player_id, market.unit_id, market.amount, market.sell, (market.sell * ?) AS totalcost, unittype.name, player.nick AS buyer, player.money FROM market, player, unittype WHERE player.id=? AND market.id=? AND unittype.id=market.unit_id');
   $query->execute($amount,$$source{id},$mid);
   if(!$query->rows()) {
        player_msg($source,'Invalid market ID');
        return 0;
   }
   $row = $query->fetchrow_hashref();
   if($$row{amount} < $amount) {
        player_msg($source,sprintf('The seller does not have that many %s(s)',$$row{name}));
        return 0;
   }
   if($$row{money} < $$row{totalcost}) {
        player_msg($source,'You cannot afford that purchase');
        return 0;
   }
   #when we get here the transation is finalized
   
   #update sellers money
   if ($$row{player_id} == 0) {
      #add to lottery instead of player as player_id 0 is the system generated market
      $query = $SQL->prepare("SELECT money FROM lottery WHERE winner = ''");
      $query->execute();
      if($query->rows()){
         $query = $SQL->prepare("UPDATE lottery SET money = (money + ?) WHERE winner =''");
         $query->execute($$row{totalcost});
      } else {
         $query = $SQL->prepare("INSERT INTO lottery (money) VALUES ( ? ) ");
         $query->execute($$row{totalcost});
      }
   } else {
      $sellersource = getsource($$row{player_id});
      sql_money($$row{player_id},$$row{totalcost});
      player_msg($sellersource,sprintf('%s has purchased %d %s(s) from market item %d for $%d',$$row{buyer},$amount,$$row{name},$mid,$$row{totalcost}));
      sql_log($$row{player_id},'MARKET',sprintf('%s has purchased %d %s(s) from market item %d for $%d',$$row{buyer},$amount,$$row{name},$mid,$$row{totalcost}));
   }
   #update buyers units and money
   sql_money($$source{id},-($$row{totalcost}));
   sql_unit($$source{id},$$row{unit_id},$amount);
   player_msg($source,sprintf('You have purchased %d %s(s) for $%d',$amount,$$row{name},$$row{totalcost}));  

   #update market
   
   if(($$row{amount} - $amount) == 0) {
        $query = $SQL->prepare('DELETE FROM market WHERE market.id=?');
        $query->execute($$row{id});
   } else {
        $query = $SQL->prepare('UPDATE market SET market.amount=(market.amount - ?) WHERE market.id=?');
        $query->execute($amount,$$row{id});
   }
   return 1;
}

# cmd_country
#
# COUNTRY <name>

sub cmd_country
{
   my $parv   = $_[0];
   my $source = $_[1];

   my $query;
   my $row;

   if($$parv[1] =~ /^[0-9A-Za-z\-]+$/ && length($$parv[1]) <= 15 && length($$parv[1]) > 0)
   {
      $query = $SQL->prepare('UPDATE player SET country=? WHERE id=?');
      $query->execute($$parv[1], $$source{id});
      player_msg($source, sprintf('You now have sovereignty over \'%s\'.', $$parv[1]));
      return 1;
   }
   else
   {
      player_msg($source, 'Your nation\'s name can only contain alphanumeric and the - character. ' . 
                       'It also may only be 15 characters in length.');
      return 0;
   }
}


# cmd_disband
#
# DISBAND <name>

sub cmd_disband
{
   my $parv   = $_[0];
   my $source = $_[1];

   my $query;
   my $row;
   my $recon;

   my $amount = $$parv[1];
   my $type = $$parv[2];

   
   if($amount < 0)
   {
      player_msg($source, 'You must specify a positive amount.');
      return 0;
   }

   #first get the unit type and check if it actually exists!
   $query = $SQL->prepare('SELECT unittype.id AS uid, unittype.name, unit.id, unit.amount FROM unit,unittype ' . 
                          'WHERE unittype.name=? AND unittype.train=\'true\' AND unittype.id = unit.unit_id ' . 
                          'AND unit.player_id=?');

   $query->execute($type, $$source{id});

   if(!$query->rows())
   {
      player_msg($source, 'Your nation does not have any troops of that type.');
      return 0;
   }

   $row = $query->fetchrow_hashref();

   if($amount > $$row{amount})
   {
      player_msg($source, 'Your nation does not have that many troops to disband,');
      return 0;
   }
   if ($$row{uid} == $SPY{recon}) {
       $query = $SQL->prepare("SELECT recon FROM player WHERE id=?");
       $query->execute($$source{id});
       $recon = $query->fetchrow_hashref();
       if ($$recon{recon} != 0) {
          player_msg($source, 'You must recall your spy before disbanding them');
          return 0;
       }
   }
   $query = $SQL->prepare('UPDATE unit SET amount = amount - ? WHERE id = ?');
   $query->execute($amount, $$row{id});

   $query = $SQL->prepare('UPDATE player SET farmers = farmers + ? WHERE id = ?');
   $query->execute($amount, $$source{id});

   player_msg($source, sprintf('%d %s(s) have been disbanded from your nation\'s military.',
                    $amount, $$row{name}));
   return 1;
}

# cmd_educate
#
# EDUCATE <amount>

sub cmd_educate
{
   my $parv   = $_[0];
   my $source = $_[1];

   my $query;
   my $row;
   
   my $player;
   my $amount = $$parv[1];

   if($amount <= 0 || $amount =~ /[^0-9]/)
   {
      player_msg($source, 'You must specify a valid amount of farmers to educate.');
      return 0;
   }

   $query = $SQL->prepare('SELECT farmers,scientists FROM player WHERE id=?');
   $query->execute($$source{id});
   $player = $query->fetchrow_hashref();

   if($$player{farmers} < $amount)
   {
      player_msg($source, 'Your nation does not possess that many farmers!');
      return 0;
   } 

   if($amount > (sql_landuse($$source{id}, $STYPE{lab}) - $$player{scientists}))
   {
      player_msg($source, 'Your nation\'s labs cannot support that many scientists, build more!');
      return 0;
   }

   $query = $SQL->prepare('UPDATE player ' . 
                          'SET scientists = scientists + ?, farmers = farmers - ? WHERE id=?');
   $query->execute($amount,$amount, $$source{id});

   player_msg($source, sprintf('%d farmers throw down their pitchfork as they are ' . 
                            'educated in your universities. The new scientists ' . 
                            'will greatly help in your nation\'s research.',
                            $amount));
   #education favor alteration
   altfavor($$source{id}, ($amount / sql_population($$source{id})) * $FAVOR{educategive});
   return 1;

}


# cmd_educate
#
# EDUCATE <amount>

sub cmd_establish
{
   my $parv   = $_[0];
   my $source = $_[1];

   my $query;
   my $row;

   if(has_flag($$source{id}, 'established'))
   {
      player_msg($source, 'Your nation is already established.');
      return 0;
   }

   $query = $SQL->prepare('UPDATE player SET government_id=? WHERE id=?');
   $query->execute($GTYPE{dictatorship}, $$source{id});

   set_flag($$source{id}, 'established');

   global_msg(sprintf('In a struggle to control the balance of commerce, %s has been ' . 
                       'established under the control of %s.', 
              sql_getcountry($$source{id}), sql_gettitle($$source{id}) ));
   return 1;
}

sub cmd_events
{
   my $query;
   
   $query = $SQL->prepare("SELECT id FROM events");
   $query->execute();
   $GAME_EVENT = $query->rows();
   do_log(sprintf("GAME EVENTS SET: %s",$GAME_EVENT));

   return 0;
}

#cmd_explore
#
# EXPLORE

sub cmd_explore
{
   my $parv   = $_[0];
   my $source = $_[1];

   my $query;
   my $row;

   my $land;
   my $dice;

   $dice = rand(100);

   if($dice <= 45)
   {
      $land = 0;
   }
   elsif($dice <= 50)
   {
      #5% chance for random event
      hk_event($$source{id});
      return 1;
   }
   elsif($dice <= 90)
   {
      $land = int rand_range(150,400);
   }
   elsif($dice <= 97)
   {
      $land = int rand_range(350,500);
   }
   else 
   {
      $land = int rand_range(500,750);
   }

   player_msg($source, sprintf('Your nation\'s explorers have found and secured %d acres of land.', $land));

   $query = $SQL->prepare('UPDATE player SET land = land + ? WHERE id = ?');
   $query->execute($land, $$source{id});

   return 1;
}

# cmd_fire
#
# FIRE <amount> <factory>

sub cmd_fire #\@hire, \%source
{
   my $parv   = $_[0];
   my $source = $_[1];

   my $query;
   my $row;

   my $player;
   my $amount = $$parv[1];
   my $factory = $$parv[2];

   $query = $SQL->prepare('SELECT structuretype.type,structuretype.size,' .
                          'structure.workers,structure.amount,structure.id ' .
                          'FROM structuretype, structure ' .
                          'WHERE structure.structure_id = structuretype.id AND structuretype.name=? ' .
                          'AND structure.player_id=?');
   $query->execute($factory, $$source{id});

   if(!$query->rows())
   {
      player_msg($source, 'Your employment unions search through their records, but are ' .
                       'unable to find any factories of that type.');
      return 0;
   }

   $row = $query->fetchrow_hashref();

   if($$row{type} != $STYPE{factory})
   {
      player_msg($source, 'You can only fire workers from factories.');
      return 0;
   }

   if($$row{workers} < $amount)
   {
      player_msg($source, 'Your factories do not have that many employees to fire.');
      return 0;
   }

   #good to go, move the workers to farmers
   sql_hire($$source{id}, $$row{id}, -$amount);

   #do a favor alt
   altfavor($$source{id}, ($amount / sql_population($$source{id})) * $FAVOR{hiretake});

   player_msg($source, sprintf("Pink slips are sent out to %d employees instructing them " . 
                            "to take back to the fields.", $amount));

   return 1;
}

sub cmd_formation
{
   my $parv   = $_[0];
   my $source = $_[1];
   my @formation;
   my @formation_id;
   my $unit;
   my $query;
   my $row;
   my $output;
   

   if($$parv[1] eq "clear") {
      #clear existing formation
      $query = $SQL->prepare("DELETE FROM player_formation WHERE player_id=?");
      $query->execute(is_player($$source{nickname}));
      player_msg($source,'Formation unset');
      return;
   }
   @formation = split(/,\s/,$$parv[1]);

   #verify unit types exist and player has research to assign the formation
   foreach $unit (@formation) {
      $query = $SQL->prepare('SELECT id, prereq, wage, name FROM unittype WHERE name=? AND type=1');
      $query->execute($unit);
   
      if(!$query->rows())
      {
         player_msg($source, 'No such unit ' . $unit . ' exists.');
         return 0;
      }

      $row = $query->fetchrow_hashref();

      if($$row{prereq} && !sql_has_research($$source{id}, $$row{prereq}))
      {
         player_msg($source, 'Your nation\'s military does not have enought research on that unit to assign formation.');
         return 0;
      }
      
      #make sure unit row exists in database
      $query = $SQL->prepare("SELECT id FROM unit WHERE unit_id=? AND player_id=?");
      $query->execute($$row{id},$$source{id});

      if(!$query->rows()) {
         $query = $SQL->prepare("INSERT INTO unit SET unit_id=?, amount=0,player_id=?");
         $query->execute($$row{id},$$source{id});
      }
      $output = sprintf("%s%s, ",$output, $$row{id});
   }
   if ($output) {
      #delete existing formation
      $query = $SQL->prepare("DELETE FROM player_formation WHERE player_id=?");
      $query->execute(is_player($$source{nickname}));
      #save and report change
      $output = substr($output,0,-2);
      $query = $SQL->prepare("INSERT INTO player_formation SET player_id=?, formation=?,formation_string=?");
      $query->execute(is_player($$source{nickname}),$output,$$parv[1]);
      player_msg($source,'Formation set to: ' . $$parv[1]);
   } else {
      $query = $SQL->prepare("SELECT formation_string FROM player_formation WHERE player_id=?");
      $query->execute(is_player($$source{nickname}));
      if($query->rows()) {
         $row = $query->fetchrow_hashref();
         player_msg($source,'Current formation: ' . $$row{formation_string});    
      } else {
         player_msg($source,'No formation set');
      }  
   }
}

# cmd_help
#
# HELP <topic>

sub cmd_help #\@parv, \%source
{
   my $parv   = $_[0];
   my $source = $_[1];

   my $query;
   my $row;

   my $mp;
   my $table;
   my @help;
   my $help;
   
   my $command;

   #no parameters? give a listing of help topics
   if(!$$parv[1])
   {
      $table = new Text::ASCIITable;

      $table->setCols(['Topic','Synopsis']);
      $table->setColWidth('Topic', 15, 1);
      $table->setColWidth('Synopsis', 25, 1);

      $query = $SQL->prepare('SELECT name,shorthelp FROM help ORDER BY name');
      $query->execute();

      while($row = $query->fetchrow_hashref())
      {
         $table->addRow($$row{name},$$row{shorthelp});
      } 

      player_msg($source, $table->draw());
      return 1;
   }

   

   #okay, fetch the help topic and display it!

   $query = $SQL->prepare('SELECT syntax,help FROM help WHERE name=?');
   $query->execute($$parv[1]);

   if($query->rows() == 0)
   {
      player_msg($source, 'No help found on that topic.');
      return 0;
   }

   $row = $query->fetchrow_hashref();

   #get the MP if any from the command table
   $mp = 0;
   foreach $command (@CMDS)
   {
      if($$parv[1] =~ /^$$command{cmd}$/i)
      {
         $mp = $$command{mp};
      }
   }

   player_msg($source, sprintf("   Syntax: %s\n", $$row{syntax}));
   player_msg($source, sprintf("   MP: %d\n \n", $mp));

   push @help, (split /\n/ ,$$row{help}); 

   local($Text::Wrap::columns) = 50;
   
   foreach $help (@help)
   {
      $help .= "\n\n";
      player_msg($source, wrap("   ", "", $help));
   }
   return 1;
}

# cmd_hire
#
# HIRE <amount> <factory>

sub cmd_hire #\@hire, \%source
{
   my $parv   = $_[0];
   my $source = $_[1];
  
   my $player;
   my $query;
   my $row;

   my $amount = $$parv[1];
   my $factory = $$parv[2];

   $query = $SQL->prepare('SELECT structuretype.type,structuretype.size,structure.workers, ' .
                          'structure.amount,structure.id ' .
                          'FROM structuretype,structure ' .
                          'WHERE structure.structure_id = structuretype.id AND structuretype.name=? ' .
                          'AND structure.player_id=?');

   $query->execute($factory, $$source{id});

   if(!$query->rows())
   {
      player_msg($source, 'Your employment unions search through their records, but are ' .
                       'unable to find any factories of that type.');
      return 0;
   }

   $row = $query->fetchrow_hashref();

   if($$row{type} != $STYPE{factory})
   {
      player_msg($source, 'You can only hire workers to factories.');
      return 0;
   }

   if((($$row{size} * $$row{amount}) - $$row{workers}) < $amount)
   {
      player_msg($source, 'Your factories cannot hold that many workers. Build more');
      return 0;
   }

   $query = $SQL->prepare('SELECT farmers FROM player WHERE id=?');
   $query->execute($$source{id});
   $player = $query->fetchrow_hashref();

   if($$player{farmers} < $amount)
   {
      player_msg($source, "Your nation does not possess that many farmer's to hire.");
      return 0;
   }

   #good to go, move the farmers to the factories!
   sql_hire($$source{id}, $$row{id}, $amount);

   #do a favor alt
   altfavor($$source{id}, ($amount / sql_population($$source{id})) * 75);

   player_msg($source, sprintf("%d farmers throw down their pitchforks to join your nation's industry.", $amount));

   return 1;
}


# cmd_inbox

sub cmd_inbox {
    #Player to player Mail
    
    #SELECT player.id,mail.from_player, mail.message,mail.read FROM player,mail WHERE player.nick='CrazySpence' AND mail.player_id=player.id;
    my $parv = $_[0];
    my $source = $_[1];
    my $query;
    my $table;
    my $row;
        
    if ($$parv[1] eq "clear") {
        $query = $SQL->prepare("DELETE FROM mail where player_id=?");
        $query->execute($$source{id});
        player_msg($source,"Messages Deleted");
        return;
    }
    if ($$parv[1] eq "all") {
        #show all messages
        $query = $SQL->prepare('SELECT player.id,mail.from_player, mail.message,mail.read FROM player,mail WHERE player.nick=? AND mail.player_id=player.id');
        $query->execute($$source{nickname});
    } else {
        #show unread messages
        $query = $SQL->prepare('SELECT player.id,mail.from_player, mail.message,mail.read FROM player,mail WHERE player.nick=? AND mail.player_id=player.id AND mail.read=0');
        $query->execute($$source{nickname});
    }
    
    $row = $query->fetchrow_hashref();
    if ($row) {
       $table = new Text::ASCIITable;
       $table->setCols(['From','Message']);
       $table->setOptions('headingText', 'Inbox');
       $table->setColWidth('Message', 48, 1);
       do {
           $table->addRow($$row{from_player},$$row{message});
       } while($row = $query->fetchrow_hashref()); 
       player_msg($source,$table->draw());
       $query = $SQL->prepare("UPDATE mail SET mail.read=1 WHERE mail.player_id=?"); #mark unread as read
       $query->execute($$source{id});
    } else {
       player_msg($source,"No mail at this time");
    }
}

# cmd_info
#
# INFO

sub cmd_info
{
    my $source = $_[1];
   
    player_msg($source,dday_version());
    player_msg($source,sprintf("Housekeeping occurs every %d minutes",($GAME_OPTIONS{hk_interval} / 60)));
    player_msg($source,sprintf("Last housekeeping was %d minutes ago",((time % $GAME_OPTIONS{hk_interval}) / 60 )));
    player_msg($source,sprintf("Next housekeeping will occur in %d minutes",(($GAME_OPTIONS{hk_interval} - (time % $GAME_OPTIONS{hk_interval})) / 60 )));
}

# cmd_launch
#
# LAUNCH [target] <type>

sub cmd_launch #\@hire, \%source
{
   my $parv   = $_[0];
   my $source = $_[1];

   my $player;
   my $query;
   my $row;

   my $unit;
   my $target_id;

   if ($$parv[1] eq "all") {
        if (cmd_launch_all($source) == 0) {
             player_msg($source,"No targets available, standing down launch");
             return 0; 
        }	
        player_msg($source,"Launch completed");
        return 0;  
   }
   
   #did we give a target id?
   
   if($$parv[1] =~ /^[0-9]+$/)
   {
      $target_id = $$parv[1];
      $$parv[1] = $$parv[2];
   }
   elsif($$parv[2])
   {
      $$parv[1] = $$parv[1] . ' ' . $$parv[2];
      $query = $SQL->prepare('SELECT space.id,player_id,unit_id FROM space WHERE player_id != ? ORDER by space.id');
	  $query->execute($$source{id});
       
      if (!$query->rows())
      {
           player_msg($source,"No targets available, standing down launch");
           return 0;
      }
      $row = $query->fetchrow_hashref();
      if($$row{unit_id} == 10) {
         $target_id = $$row{id};
      } else {
         player_msg($source,"No targets available, standing down launch");
         return 0;
      }
   }

   #see if we have a launchable unit of this type
   $query = $SQL->prepare('SELECT unittype.name as name, unittype.id as unit_id, unittype.type, unit.id as id ' .
                          'FROM unit, unittype ' . 
                          'WHERE unittype.name = ? AND unit.amount > 0 AND unittype.space = \'true\' ' .
                          'AND unittype.id = unit.unit_id AND unit.player_id = ?');

   $query->execute($$parv[1], $$source{id});
 
   #no  found
   if(!$query->rows())
   {
      player_msg($source, 'Your nation does not possess any space capable units of that type.');
      return 0;
   }
   $unit = $query->fetchrow_hashref();


   
   if($$unit{type} == $UTYPE{shuttle})
   {
      if ($GAME_OPTIONS{shuttle_limit} == 1) {
        $query = $SQL->prepare('SELECT unittype.id, space.id FROM unittype,space WHERE unittype.type = ? AND space.unit_id=unittype.id AND space.player_id=?');
        $query->execute($UTYPE{shuttle},$$source{id});
        if($query->rows()) {
           player_msg($source,'You already have a shuttle in space');
           return 0;
        }
      }
      if ($GAME_OPTIONS{colonist} > 0) {
         $query = $SQL->prepare('SELECT farmers FROM player WHERE id=?');
         $query->execute($$source{id});
         $row = $query->fetchrow_hashref();
         if($$row{farmers} > $GAME_OPTIONS{colonist}) {
              #Send the colonists into space
              $query = $SQL->prepare('UPDATE player SET farmers=? WHERE id=?');
              $query->execute(($$row{farmers} - $GAME_OPTIONS{colonist}),$$source{id});
         } else {
              player_msg($source,'Sorry sir, there is not enough crew to man this mission');
              return 0;
         }
      }
      $target_id = 0;
      #update launched statistic
      $query = $SQL->prepare("UPDATE player_statistics SET launched=(launched + 1) WHERE player_id=?");
      $query->execute($$source{id});
   }
   #check if target is okay to keep
   if($target_id)
   {
      $query = $SQL->prepare('SELECT id FROM space WHERE id=?');
      $query->execute($target_id);
      $target_id = 0 if(!$query->rows());
   }

   #okay, shuttle found, insert into space table and remove from the players units table
   $query = $SQL->prepare('INSERT INTO space SET player_id=?, unit_id=?, target_id=?');
   $query->execute($$source{id}, $$unit{unit_id}, $target_id);

   $query = $SQL->prepare('UPDATE unit SET amount = amount - 1 WHERE id=?');
   $query->execute($$unit{id});

   #make announcements
   player_msg($source, sprintf('You have launched a %s into space.', $$unit{name}));
   global_msg(sprintf('In the far distance a flash of bright light and smoke form over %s.',sql_getcountry($$source{id})));  
   global_msg(sprintf('The Earth trembles as %s launches a %s into space.', sql_gettitle($$source{id}), $$unit{name}));

   return 1;
}

sub cmd_launch_all
{
    my $source = $_[0];
    my $player;
    my $query;
    my $row;
    my $mp;
    my $missiles;
    my $launched = 0;
    my @parv;

	$query = $SQL->prepare('SELECT space.id,player_id,unit_id FROM space ORDER by space.id');
	$query->execute();
	
	if ($query->rows()) {
		$player = $SQL->prepare('SELECT mp,amount,unit.id,unittype.name FROM player,unit,unittype WHERE unit.unit_id = 12 AND unit.player_id = ? AND player.id=? AND unittype.id=12');
		$player->execute($$source{id},$$source{id});
		$player = $player->fetchrow_hashref();
		$mp = $$player{mp}; 
		$missiles = $$player{amount};
		
		if ($missiles <= 0) {
			player_msg($source,"You have nothing to fire at the enemy!");
			return 1;
		}
		
		while($row = $query->fetchrow_hashref()) {
			#1 missile for every shuttle in space, if possible
			if (($$row{player_id} != $$source{id}) && ($$row{unit_id} == 10) && ($mp >= 10) && ($missiles > 0)) {
				#fire the missiles!
				@parv = ("launch",$$row{id},$$player{name});
				cmd_launch(\@parv,$source);
				$launched  = $launched + 1;
				$mp        = $mp - 10;
				$missiles = $missiles - 1;
				sql_mp($$source{id},-10);
			}
		}
	} else {
	   return 0;	
   }
    if ($launched > 0) { 
 	   return 1;
    }
    return 0;
}

# cmd_list
#
# LIST

sub cmd_list #\%source
{
   my $parv   = $_[0];
   my $source = $_[1];

   my $query;
   my $row;
   my $player;
   my $above;
   my $table;
   my $i;
   #setup table
   $table = new Text::ASCIITable;

   $table->setCols(['Player','Land']);
   $table->alignCol('Land', 'right');

   #Get player's land
   $query = $SQL->prepare('SELECT land,nick FROM player WHERE id=? AND active=1');
   $query->execute($$source{id});
   $player = $query->fetchrow_hashref();


   #fetch 5 players above us
   $query = $SQL->prepare('SELECT id,land FROM player WHERE player.land > ? AND player.id != ? AND active=1 ORDER BY player.land DESC');
   $query->execute($$player{land}, $$source{id});

   if($above = $query->rows())
   {
      if($above > 5) {
            
            for ($i = $above ; $i > 5 ; $i--) {
                        $row = $query->fetchrow_hashref();         
            }
            $above = 5;
      }
      while($row = $query->fetchrow_hashref())
      {
         $table->addRow(sql_gettitlecountry($$row{id}), $$row{land}); 
      } 
   }

   $table->addRow(sql_gettitlecountry($$source{id}), $$player{land});

   #fetch X players below, where X would complete the 10
   $above = 5 + (5 - $above);
   $query = $SQL->prepare('SELECT id,land FROM player WHERE player.land <= ? AND player.id != ? AND active=1 ORDER BY player.land DESC LIMIT ?');
   $query->execute($$player{land},$$source{id},$above);

   if($query->rows())
   {
      while($row = $query->fetchrow_hashref())
      {
         $table->addRow(sql_gettitlecountry($$row{id}), $$row{land});
      }
   }

   player_msg($source, $table->draw());
}

# cmd_log
#
# LOG <lines/mask>

sub cmd_log #\@parv, \%source
{
   my $parv   = $_[0];
   my $source = $_[1];

   my $query_text;
   my $query;
   my $query2;
   my $row;

   my @log;

   if($$parv[1] =~ /^[0-9]+$/ || length($$parv[1]) == 0)
   {
      if($$parv[1] > 80 || $$parv[1] < 1)
      {
         $$parv[1] = 80;
      }

      $query_text = sprintf('SELECT time, type, text FROM log ' . 
                            'WHERE player_id=? AND log.read=? ORDER BY time DESC,id DESC LIMIT %d',$$parv[1]);
      $query = $SQL->prepare($query_text);
      $query->execute($$source{id},0);
      
      return if (!$query->rows());
      
      $query2 = $SQL->prepare("UPDATE log SET log.read=? WHERE player_id=? AND log.read=?");
      $query2->execute(1,$$source{id},0);  
   }
   else
   {
      $$parv[1] =~ s/\*+/%/g;
      $$parv[1] =~ s/\?+/_/g;

      $query = $SQL->prepare('SELECT time, type, text FROM log WHERE player_id=? ' . 
                             'AND (text LIKE ? OR type LIKE ?) ORDER BY time DESC,id DESC LIMIT 80' );
      $query->execute($$source{id}, $$parv[1], $$parv[1]);

      return if (!$query->rows());

   }
   
   while($row = $query->fetchrow_hashref())
   {
      unshift @log, $row;
   }

   while($row = shift @log)
   {
      player_msg($source, sprintf('[%s] [%s] %s', $$row{time}, $$row{type}, $$row{text}));
   }
   
   return 1;
}


# cmd_login
#
# LOGIN <PASSWORD>

sub cmd_login #\@parv, \%source 
{
   my $parv   = $_[0];
   my $source = $_[1];

   my $query;
   my $row;

   if(is_registered($$source{nickname}))
   {
      player_msg($source, 'You are already logged in.');
      return;
   }

   $query = $SQL->prepare('SELECT id,active FROM player WHERE nick=? AND password = md5(?)');
   $query->execute($$source{nickname}, $$parv[1]);

   if($query->rows() == 0)
   {
      player_msg($source, 'Incorrect password, or your account doesn\'t exist. Issue the command NEWPLAYER to start one.');
      return;
   }

   $row = $query->fetchrow_hashref();
  
   #Legacy Check for older players to ensure a statistics row exists
   $query = $SQL->prepare("SELECT * FROM player_statistics WHERE player_id=?");
   $query->execute($$row{id});

   if($query->rows() == 0)
   {
      $query = $SQL->prepare("INSERT INTO player_statistics SET player_id=?,killed='0',died='0',launched='0',downed='0',wins='0'");
      $query->execute($$row{id});
   }
  
   $$source{id} = $$row{id};

   if(has_flag($$source{id}, 'admin'))
   {
      $$source{admin} = 1;
   }
   else
   {
      $$source{admin} = 0;
   }

   if ($$row{active} == 0) 
   {
      cmd_newplayer($parv,$source); #newplayer command is set up to handle reactivation of players
   }  else { 
      register_player($source); #put player and connection source into hash
   }
   #irc_dcc($source);

   if(has_flag($$source{id}, 'quest')) {
      #Get state from database for legacy clients
      $query = $SQL->prepare("SELECT x,y FROM quest_state WHERE player_id=?");
      $query->execute($$source{id});
      if($query->rows()) {
         $row = $query->fetchrow_hashref();
         $$source{xcords} = $$row{x};
         $$source{ycords} = $$row{y};
      }
   }
   
   return 1;
}

# cmd_lotto
#
# lotto <1-10>

sub cmd_lotto #\@parv, \%source
{
   #for $1000 player gets entered into a jackpot with their number between 1-10
   #jackpot starts at 10k and increases per 1k played + 5k from the system + autogenerated market profits later on in game
   
   my $luckyNumber = $_[0];
   my $source      = $_[1];
   my $query;
   my $row;
   
  
}

# cmd_password
#
# PASSWORD <NEWPASSWORD>

sub cmd_password #\@parv, \%source
{
   my $parv   = $_[0];
   my $source = $_[1];

   my $query;

   if ($$parv[1]) {
      $query = $SQL->prepare('UPDATE player SET password=md5(?) WHERE id=?');
      $query->execute($$parv[1], $$source{id});

      player_msg($source, "Your password has been changed.");
      sql_add_achievement($$source{id},"They're here to stay!");
      
   } else {
      player_msg($source,"You must enter a password!");
   }
   return 1;
}

sub cmd_logout #\%source
{
  #logout command to remove player safely from Connection pool
  my $source = $_[1];
  my $query;

  if(has_flag($$source{id}, 'quest')) {
     $query = $SQL->prepare("SELECT x,y FROM quest_state WHERE player_id=?");
     $query->execute($$source{id});
     if($query->rows()) {
        $query = $SQL->prepare("UPDATE quest_state SET x=?,y=? WHERE player_id=?");
        $query->execute($$source{xcords},$$source{ycords},$$source{id});
     } else {
        $query = $SQL->prepare("INSERT INTO quest_state SET x=?,y=?,player_id=?");
        $query->execute($$source{xcords},$$source{ycords},$$source{id});
     }
  }
  player_msg($source,"GOODBYE");
  unregister_player($source);
}

sub cmd_mail #\%source, @parv
{
   #Send a message to another player
   my $source = $_[1];
   my $parv   = $_[0];
   my $query;
   my $to;
   
   if ($$parv[1] && $$parv[2]) {
      if($to = is_player($$parv[1])) {
         #printf("%s\n",$to);
         $query = $SQL->prepare("INSERT INTO mail SET from_player=?, player_id=?,message=?");  
         $query->execute($$source{nickname},$to,$$parv[2]);
         if(is_registered($$parv[1])) {
             player_msg(getsource($to),"You have new mail waiting");
         }
         player_msg($source,"Message sent");
      } else {
         player_msg($source,"No such person in this world");
      }
      
   } else {
       player_msg($source,"SYNTAX: MAIL <name> <message>");
   }
}

sub cmd_sendmail #\id, parv
{
   #Send e-mail to player, checks if e-mail address is set then sends message
   my $id = $_[0];
   my $parv   = $_[1];
   my $query;
   my $msg; 
   my $row;   
   
   $query = $SQL->prepare("SELECT email FROM player WHERE id=?");
   $query->execute($id);

   $row = $query->fetchrow_hashref();

   if (!$$row{email}) { #No e-mail set
      return;
   }   

   $msg = MIME::Lite->new(
        From     =>'doomsday@philtopia.com',
        To       =>$$row{email},
        Subject  =>'Doomsday event message',
        Data     => $parv
    );
   $msg->send;
}

sub cmd_setemail
{
   my $source = $_[1];
   my $parv   = $_[0];
   my $email  = $$parv[1];
   my $query;

   if($email =~ m/^[_a-zA-Z0-9-]+(\.[_a-zA-Z0-9-]+)*@[a-zA-Z0-9-]+(\.[a-zA-Z0-9-]+)*\.(([0-9]{1,3})|([a-zA-Z]{2,3})|(aero|coop|info|museum|name))$/) {
      $query = $SQL->prepare("UPDATE player SET email=? WHERE id=?");
      $query->execute($email,$$source{id});    
      player_msg($source,sprintf("E-mail changed to %s",$email));
      return; 
   }
   $query = $SQL->prepare("UPDATE player SET email=NULL WHERE id=?");
   $query->execute($$source{id});
   player_msg($source,"E-mail address unset");
}

#Message of the day function
sub cmd_motd
{
	my $query;
	my $row;
	my $source = $_[1];
	
	$query = $SQL->prepare("SELECT * FROM motd");
	$query->execute();
	
	while ($row = $query->fetchrow_hashref())
	{
	 	player_msg($source,$$row{line});
	}
	
	return 0;
}

# cmd_report
#
# REPORT <TYPE>
my %REPORT_FUNCTIONS = (
        achievement => \&cmd_report_achievement,
        a           => \&cmd_report_achievement,
        building    => \&cmd_report_land,
        general     => \&cmd_report_general,
        gen         => \&cmd_report_general,
        g           => \&cmd_report_general,
        factory     => \&cmd_report_industry,
        industry    => \&cmd_report_industry,
        ind         => \&cmd_report_industry,
        i           => \&cmd_report_industry,
        military    => \&cmd_report_units,
        land        => \&cmd_report_land,
        l           => \&cmd_report_land,
        knowledge   => \&cmd_report_tech,
        research    => \&cmd_report_research,
        r           => \&cmd_report_research,
        structure   => \&cmd_report_land,
        structures  => \&cmd_report_land,
        space       => \&cmd_report_space,
        s           => \&cmd_report_space,    
        technology  => \&cmd_report_tech,
        tech        => \&cmd_report_tech,
        t           => \&cmd_report_tech,
        units       => \&cmd_report_units,
        unit        => \&cmd_report_units,
        u           => \&cmd_report_units,
        market      => \&cmd_report_market,
        m           => \&cmd_report_market,
        mar         => \&cmd_report_market,
        w           => \&cmd_report_winners,
        winners     => \&cmd_report_winners,
        win         => \&cmd_report_winners,
);

sub cmd_report #\@parv, \%source
{
   my $parv   = $_[0];
   my $source = $_[1];
   
   if(exists($REPORT_FUNCTIONS{$$parv[1]}))
   {
      $REPORT_FUNCTIONS{$$parv[1]}($source);
      return 1;
   }
   else
   {
      player_msg($source, 'REPORT ACHIEVEMENT - View Achievements');
      player_msg($source, 'REPORT GENERAL     - General report');
      player_msg($source, 'REPORT INDUSTRY    - Factory/Worker report');
      player_msg($source, 'REPORT LAND        - Structure/building report');
      player_msg($source, 'REPORT MARKET      - Market Report');
      player_msg($source, 'REPORT RESEARCH    - Research tree/allocation report');
      player_msg($source, 'REPORT SPACE       - Report on space units');
      player_msg($source, 'REPORT TECH        - Technology report');
      player_msg($source, 'REPORT UNITS       - Military/unit report');
      player_msg($source, 'REPORT WINNERS     - Show previous game winners');
      return 0;
   } 

   return 0;
}

sub cmd_report_achievement
{
    my $source = $_[0];
	my $query;
	my $row;
	my $table;
	
	$query = $SQL->prepare('SELECT achievement.achievement_id,achievementtype.name,achievementtype.description FROM achievement,achievementtype WHERE achievement.player_id=? AND achievementtype.id=achievement.achievement_id');
	$query->execute($$source{id});
	if(!$query->rows())
	{
		player_msg($source,'You have no achievements');
		return;
	}
	$table = new Text::ASCIITable;
	$table->setOptions('headingText','Achievements');
	$table->setCols(['Name','Description']);
	$table->alignCol('Name','Left');
	$table->setColWidth('Description', 48, 1);
	
	while($row = $query->fetchrow_hashref())
	{
		$table->addRow($$row{name},$$row{description});
	}
	player_msg($source,$table->draw());
   
}

sub cmd_report_general
{
   my $source = $_[0];
   my $query;
   my $row;
   my $table;

   my $landuse; 
   my $favor;
   my $workers;
   my $inbox;
   my $lab_capacity;
   my $population;
   my $protection;
   my $recon;
   
   $inbox = mailbox($source);
   #get generals
   $query = $SQL->prepare('SELECT player.recon,player.nick,player.mp,player.mp_bank,player.money,player.land,player.farmers,player.scientists,player.surrender, player.favor, player.tax, player.hk,government.name FROM player,government WHERE player.id=? AND government.id = player.government_id');
   $query->execute($$source{id});

   $row = $query->fetchrow_hashref();

   #get workers
   $query = $SQL->prepare('SELECT sum(structure.workers) AS workers FROM structure WHERE player_id=?');
   $query->execute($$source{id});
 
   if($query->rows())
   {   
      $query = $query->fetchrow_hashref();
      $workers = $$query{workers};
   }
   $workers = 0 if(!$workers);

   #get lab capacity
   $lab_capacity = sql_landuse($$source{id}, $STYPE{lab});

   #get total population
   $population = sql_population($$source{id});
   
   #how much longer unestablished players have until being thrown into the wild
   $protection = $GAME_OPTIONS{anarch_max}- $$row{hk}; 
   
   #if I'm spying get their name
   $query = $SQL->prepare('SELECT nick FROM player WHERE id=?');
   $query->execute($$row{recon});

   $recon = $query->fetchrow_hashref();
   
   $table = new Text::ASCIITable;
   $table->setCols(['Type','Amount']);
   $table->setOptions('hide_HeadLine', 1);
   $table->setOptions('hide_HeadRow', 1);

   $table->alignCol('Type', 'left');
   $table->alignCol('Amount', 'right');

   if(!has_flag($$source{id}, 'established')) {
      $table->addRow('Established',sprintf("in %s hk's",$protection));
   }
   
   if ($inbox) {
      $table->addRow('New mail!', $inbox);
   }
   
   $table->addRow('MP', sprintf('%d (%d)',$$row{mp}, $$row{mp_bank}));
   $table->addRow('Money', '$' . $$row{money});
   $landuse = sql_landuse($$source{id},0);
   $favor = favor($$source{id});
   if($$row{land} > 0)
   {
      $table->addRow('Land Usage', sprintf('%d/%d (%d%%)',$landuse,$$row{land}, int($landuse/$$row{land} * 100)));
   }
   $table->addRow('Population', $population);
   $table->addRow('Farmers', $$row{farmers});
   $table->addRow('Scientists', sprintf('%d/%d', $$row{scientists}, $lab_capacity) );
   $table->addRow('Workers', sprintf('%d',$workers));
   $table->addRow('Tax', $$row{tax} . '%');
   $table->addRow('Surrender', $$row{surrender} . '%');
   $table->addRow('Favor', sprintf('%.1f',$favor));
   $table->addRow('Government', $$row{name});
   if($$recon{nick}) 
   {
      $table->addRow('Spying',$$recon{nick});
   }
   if(!has_flag($$source{id}, 'established'))
   {
      $table->setOptions('headingText', 'General Report (Not Established)');
   }
   else
   {
      $table->setOptions('headingText', 'General Report (Established)');
   }

   player_msg($source, $table->draw());

   return;
}

sub cmd_report_industry
{
   my $source = $_[0];
   my $query;
   my $query2;
   my $row;
   my $table;

   my $factory;
   my $unit;

   $query = $SQL->prepare('SELECT structuretype.name, structuretype.size, structure.amount, structure.workers, ' .
                          'unittype.name AS productname, unittype.cost AS productcost, structuretype.product ' . 
                          'FROM structuretype, structure, unittype ' .
                          'WHERE structuretype.id = structure.structure_id AND structuretype.type=? ' .
                          'AND structure.player_id=? ' .
                          'AND unittype.id = structuretype.product ' .
                          'AND structure.amount > 0 ' . 
                          'GROUP BY structuretype.name');

   $query->execute($STYPE{factory}, $$source{id});

   if(!$query->rows())
   {
      player_msg($source, 'Your nation has no industry. Build factories.');
      return 0;
   }

   $table = new Text::ASCIITable;
   $table->setCols(['Factory', '#', 'Product',  'Workers', '0-Fav Est', 'Build']);
   $table->setOptions('headingText', 'Industry');
   $table->alignCol('#', 'right');
   $table->alignCol('Workers', 'right');
   $table->alignCol('0-Fav Est', 'right');
   $table->alignCol('Build', 'right');

   while($factory = $query->fetchrow_hashref())
   {
      $query2 = $SQL->prepare('SELECT build FROM unit WHERE unit_id=? AND player_id=?');
      $query2->execute($$factory{product}, $$source{id});

      if($query2->rows())
      {
         $unit = $query2->fetchrow_hashref();
 
         $table->addRow($$factory{name}, $$factory{amount}, $$factory{productname}, 
                     sprintf('%d/%d',$$factory{workers}, $$factory{size} * $$factory{amount}),
                     sprintf('%.2f/HK', $$factory{workers} / $$factory{productcost}),
                     sprintf('%.2f%%', 100 * ($$unit{build}/$$factory{productcost})) );
      }
      else
      {
         $table->addRow($$factory{name}, $$factory{amount}, $$factory{productname},
                     sprintf('%d/%d',$$factory{workers}, $$factory{size} * $$factory{amount}),
                     sprintf('%.2f/HK', $$factory{workers} / $$factory{productcost}),
                     '0%');
      }
   }

   player_msg($source, $table->draw);
}

sub cmd_report_land
{
   my $source = $_[0];
   my $query;
   my $row;
   my $table;

   $query = $SQL->prepare('SELECT (structuretype.size*structure.amount) AS landuse, ' . 
                          'structuretype.name, structure.amount ' .
                          'FROM structuretype, structure ' .
                          'WHERE structuretype.id = structure.structure_id AND structure.player_id=? ' .
                          'AND structure.amount > 0 ' . 
                          'ORDER BY structuretype.name'
                         );
   $query->execute($$source{id});
   
   if(!$query->rows())
   {
      player_msg($source, 'Your land is bare!');
      return;
   }

   #good to go, make a table
   $table = new Text::ASCIITable;

   $table->setCols(['Structure', 'Amount', 'Land Use']);
   $table->setOptions('headingText', 'Structures');
   $table->alignCol('Amount', 'right');
   $table->alignCol('Land Use', 'right');

   while($row = $query->fetchrow_hashref())
   {
      $table->addRow($$row{name}, $$row{amount}, $$row{landuse} . ' acres');
   }
   player_msg($source, $table->draw());
}

sub cmd_report_research
{
   my $source = $_[0];

   my $query;
   my $row;

   my $table;
   my $scientists;

   $table = new Text::ASCIITable;
   
   $table->setCols(['Topic', 'LVL', 'ALC', 'ETA (HKs)']);
   $table->setOptions('headingText', 'Research');
   $table->alignCol('LVL', 'right');
   $table->alignCol('ALC', 'right');
   $table->alignCol('ETA (HKs)', 'right');;

   #get scientist count
   $query = $SQL->prepare('SELECT scientists FROM player WHERE id=?');
   $query->execute($$source{id});
   $row = $query->fetchrow_hashref();
   $scientists = $$row{scientists};

   #get all the research types
   $query = $SQL->prepare('SELECT id,name,cost ' . 
                          'FROM researchtype ' . 
                          'WHERE researchtype.prereq=0 ' . 
                          'ORDER BY researchtype.name');
   $query->execute();

   return if !$query->rows();

   while($row = $query->fetchrow_hashref())
   {
      research_line($source, $row, $table, 0, 0, $scientists);
   }

   player_msg($source, $table->draw());

}

#recursive! 
sub research_line #$source, \%topic, $table, $depth, $last, $scientists
{
   my $source     = $_[0];
   my $topic      = $_[1]; #current level topic (from SQL)
   my $table      = $_[2]; #table class 
   my $depth      = $_[3]; #what depth we're at (for indentation)
   my $last       = $_[4]; #is this the last element?
   my $scientists = $_[5]; #amount of scientists this player has

   my $query;
   my $row;
   
   my $indent;
   my $i;
   my $eta;

   $query = $SQL->prepare('SELECT level,allocation FROM research WHERE player_id=? AND research_id=?');
   $query->execute($$source{id}, $$topic{id});

   #calculate the indent
   $indent = ' ' x ($depth * 3);
   
   if($depth > 0)
   {
      if($last)
      {
         $indent .= '`-';
      }
      else
      {
         $indent .= '|-'; 
      }
   }
   #the player has allocated or researched this topic
   if(!$query->rows())
   {
      $table->addRow($indent . $$topic{name}, '0%', '0%', ' ');
   }
   else
   {
      $row = $query->fetchrow_hashref();

      #get an ETA on when this will be finished
      if(($$row{allocation} > 0) && ($scientists > 0))
      {
         # ETA is the cost divided by the amount of scientists dedicated to the topic
         $eta = ($scientists * $$row{allocation} * .01);

         if($eta > 0)
         {
                   # TOTAL COST    -  LEVEL * COST (WHAT WE'VE ALREADY DONE) == POINTS LEFT
            $eta = ( $$topic{cost} - ($$row{level} * .01 * $$topic{cost}) ) / $eta;

            #round ETA up if it's not an integer
            if($eta >= 1)
            {
               $eta = (int $eta + 1) if (!($eta % (int $eta))); 
            }
            else
            {
               $eta = 1;
            }
         }

  
         #format ETA
         $eta = sprintf('%d HK(s)', $eta);
      }
      else
      {
         $eta = '';
      }

      $table->addRow($indent . $$topic{name}, int($$row{level}) . '%', $$row{allocation} . '%', $eta);
   }

   #if this isn't done yet, don't continue
   return if ($$row{level} < 100);

   #find any topics under this one
   $query = $SQL->prepare('SELECT id,name,cost FROM researchtype WHERE prereq=?');
   $query->execute($$topic{id});

   return if !$query->rows();

   $i = $query->rows();

   while($row = $query->fetchrow_hashref())
   {
         if(--$i == 0)
         {
            research_line($source, $row, $table, $depth + 1, 1, $scientists);
         }
         else
         {
            research_line($source, $row, $table, $depth + 1, 0, $scientists);
         }
   }
}

sub cmd_report_tech
{
   my $source = $_[0];

   my $units_query;
   my $structures_query;

   my $row;
   my $table;
   my $stats;


   $units_query = $SQL->prepare('SELECT unittype.name, unittype.attack, unittype.defense, unittype.wage ' .  
                                'FROM unittype, research ' . 
                                'WHERE ((research.player_id=? AND unittype.prereq=research.research_id ' . 
                                'AND research.level = 100) ' .
                                'OR unittype.prereq = 0) ' .
                                'GROUP BY unittype.id ' .
                                'ORDER BY unittype.name, unittype.type');
   $units_query->execute($$source{id});

   $structures_query = $SQL->prepare('SELECT structuretype.name, structuretype.cost, structuretype.size ' .
                                     'FROM structuretype, research ' .
                                     'WHERE ((research.player_id=? AND structuretype.prereq=research.research_id ' .
                                     'AND research.level = 100) ' .
                                     'OR structuretype.prereq = 0) ' .
                                     'GROUP BY structuretype.id ' .
                                     'ORDER BY structuretype.name, structuretype.type');
   $structures_query->execute($$source{id});

   if(!$units_query->rows() && !$structures_query->rows())
   {
      player_msg($source, 'Your nation does not possess any technology.');
      return;
   }

   $table = new Text::ASCIITable;
   $table->setCols(['Name', 'Stats/Size', 'Cost/Wage']);
   $table->alignCol('Cost/Wage', 'right');
   $table->alignCol('Stats/Size', 'right');
   $table->setOptions('headingText', 'Technology');


   if($structures_query->rows())
   {
      while($row = $structures_query->fetchrow_hashref())
      {
         $table->addRow($$row{name}, $$row{size} . ' acres', sprintf('$%d',$$row{cost}));
      }
   }

   if($units_query->rows())
   {
      $table->addRow(' ', ' ', ' ') if $structures_query->rows();
      while($row = $units_query->fetchrow_hashref())
      {
         $stats = sprintf('(%d, %d)', $$row{attack}, $$row{defense});
         $table->addRow($$row{name}, $stats, sprintf('$%d/month',$$row{wage}));
      }
   }

   player_msg($source, $table->draw());
}

sub cmd_report_space
{
   my $source = $_[0];

   my $query;
   my $query2;
   my $row;

   my $table;
   my $target;
   my $target_text;
   my $range;

   $table = new Text::ASCIITable;
   $table->setCols(['ID', 'Owner', 'Unit', 'Target', 'Stats', 'Range']);

   $query = $SQL->prepare('SELECT unittype.name, unittype.attack, unittype.defense, space.id,space.distance, space.target_id, player.nick ' .
                          'FROM unittype, space, player ' .
                          'WHERE space.unit_id = unittype.id AND player.id = space.player_id ' .
                          'ORDER BY space.distance DESC');
   $query->execute();

   if($query->rows())
   {
      while($row = $query->fetchrow_hashref())
      {

         if($$row{distance} == 0)
         {
            $range = 'ORBIT';
         }
         else
         {
            $range = sprintf('%.2f AU (%d%%)', $$row{distance}, 100 * ($$row{distance} / $GAME_OPTIONS{spacerange}));
         }

         if($$row{target_id})
         {
            $query2 = $SQL->prepare('SELECT player.nick, unittype.name ' . 
                                    'FROM player, unittype, space ' . 
                                    'WHERE space.id=? AND space.unit_id = unittype.id AND space.player_id=player.id');
            $query2->execute($$row{target_id});
            $target = $query2->fetchrow_hashref();

            $target_text = sprintf('%s\'s %s (%d)',$$target{nick}, $$target{name}, $$row{target_id});

            $table->addRow($$row{id}, $$row{nick}, $$row{name}, $target_text, sprintf('(%d,%d)', $$row{attack}, $$row{defense}),$range);
         }
         else
         {
            $table->addRow($$row{id}, $$row{nick}, $$row{name}, ' ', sprintf('(%d,%d)', $$row{attack}, $$row{defense}), $range);
         }
      }
      player_msg($source, $table->draw());
   }
   else
   {
      player_msg($source, 'There are not any known units in space.');
   }
}

sub cmd_report_units
{
   my $source = $_[0];
   my $query;
   my $row;
   my $table;
   my $stats;

   $query = $SQL->prepare('SELECT unittype.name,unittype.wage,unittype.attack,unittype.defense,unit.amount ' .
                          'FROM unittype, unit ' . 
                          'WHERE unittype.id = unit.unit_id AND unit.player_id = ? AND unit.amount > 0 ' . 
                          'ORDER BY unittype.name, unittype.type');
   $query->execute($$source{id});

   if(!$query->rows())
   {
      player_msg($source, 'Your nation does not have any units.');
      return;
   }

   $table = new Text::ASCIITable;
   $table->setCols(['Unit', 'Amount', 'Atk/Def', 'Wage']);
   $table->alignCol('Amount', 'right');
   $table->alignCol('Atk/Def', 'right');
   $table->alignCol('Wage', 'right');

   while($row = $query->fetchrow_hashref())
   {
      $stats = sprintf('(%d,%d)', $$row{attack}, $$row{defense});
      $table->addRow($$row{name}, $$row{amount}, $stats, sprintf('$%d/month',$$row{wage}));
   }
   player_msg($source, $table->draw());
}

sub cmd_report_market
{
     # Hail to CrazySpence
     my $source = $_[0];
     my $query;
     my $row;
     my $table;
     
     $query = $SQL->prepare('SELECT market.id, market.player_id, market.unit_id, market.sell, market.amount, unittype.name, (market.sell * market.amount) AS totalcost FROM market,unittype WHERE unittype.id = market.unit_id');
     $query->execute();
     if(!$query->rows())
     {
          player_msg($source,'The market is bare');
          return;
     }
     
     $table = new Text::ASCIITable;
     $table->setOptions('headingText','Market');
     $table->setCols(['ID','Product','Amount','Cost(each)','Total']);
     $table->alignCol('Cost(each)','right');
     $table->alignCol('Total','right');
     while($row = $query->fetchrow_hashref())
     {
          $table->addRow($$row{id},$$row{name},$$row{amount},sprintf('$%d',$$row{sell}),sprintf('$%d',$$row{totalcost}));
     }
     player_msg($source, $table->draw());
} 

sub cmd_report_winners
{
	my $source = $_[0];
	my $query;
	my $row;
	my $table;
	
	$query = $SQL->prepare('SELECT * FROM HallOfFame');
	$query->execute();
	if(!$query->rows())
	{
		player_msg($source,'There are no winners');
		return;
	}
	$table = new Text::ASCIITable;
	$table->setOptions('headingText','Hall Of Fame');
	$table->setCols(['#','Player','Country','HKs','Date']);
	$table->alignCol('#','right');
	$table->alignCol('HKs','right');
	
	while($row = $query->fetchrow_hashref())
	{
		$table->addRow($$row{id},$$row{player},$$row{country},$$row{hks},$$row{date});
	}
	player_msg($source,$table->draw());
}

sub cmd_sell 
{
     #hail to CrazySpence
     my $parv   = $_[0];
     my $source = $_[1];
     my $query;
     my $row;
     my $selling;
     my $amount;
     my $price;
     my $pid;
     my $uid;
     
     if($$parv[4]) {
          $selling = sprintf("%s %s",$$parv[1],$$parv[2]);
          $amount = $$parv[3];
          $price = $$parv[4];
     } else {
          $selling = $$parv[1];
          $amount = $$parv[2];
          $price = $$parv[3];
     }
     $amount =~ /^[\d]+$/; 
     $price =~ /^[\d]+$/;
     if($amount <= 0 || $price <= 0)
     {
          player_msg($source, 'You must specify positive numerical values');
          return 0;
     } 
     $query = $SQL->prepare('SELECT unit.amount, unittype.train,unittype.cost, unittype.id AS uid, player.id FROM unit, unittype, player WHERE unittype.name=? AND unit.player_id=? AND unit.unit_id=unittype.id');
     $query->execute($selling,$$source{id});
     if(!$query->rows()) {
          player_msg($source,'You do not have any units of that type');
          return 0;
     }
     $row = $query->fetchrow_hashref();
     if ($$row{train} eq'true') {
	      player_msg($source,'You cannot sell trained units');
	      return 0; 
     }
     if($$row{amount} < $amount) {
          player_msg($source,'You do not have that many to sell');
          return 0;
     }
     if($price < $$row{cost}) {
	      player_msg($source,'Corporate regulators forbid you to sell that item for less than half of its retail value');
	      return 0;
     }
     
     #the basic error checks are ok lets add to the market
     $query = $SQL->prepare('INSERT INTO market (player_id, unit_id, sell,amount) VALUES (?,?,?,?) ');
     $query->execute($$source{id},$$row{uid},$price,$amount);
     #remove the units from the player
     $query = $SQL->prepare('UPDATE unit SET unit.amount=(unit.amount - ?) WHERE unit.player_id=? AND unit.unit_id=?');
     $query->execute($amount,$$source{id},$$row{uid});
     #ok all done
     player_msg($source,'An ad has been posted in the market');
     return 1;
}

sub cmd_shutdown
{
   #toggle shutdown after games end
   my $source = $_[1];

   if ($SHUTDOWN == 0) {
      $SHUTDOWN = 1;
      player_msg($source,"Game will shut down after completion");
   } else {
      $SHUTDOWN = 0;
      player_msg($source,"Shut down cancelled");
   }   
   return 0;
}

sub cmd_recall
{
   #Recall spies from their tour of duty
   my $source = $_[1];
   my $query;
   my $recon;     
   $query = $SQL->prepare('SELECT recon FROM player WHERE id=?');
   $query->execute($$source{id});
   $recon = $query->fetchrow_hashref(); 
   if ($$recon{recon} != 0) {
      #recall Recon Spies
      $query = $SQL->prepare('UPDATE player SET recon=0 WHERE id=?');
      $query->execute($$source{id});
      player_msg($source,"Your spy has returned home");
      return 1;
   }
   player_msg($source,"You have no reconnaissance agents in the field");

   return 0;
}


sub cmd_recon
{
   my $parv   = $_[0];
   my $source = $_[1];

   my $query;
   my $row;

   my $spy;
   my $target;
   my $structure;
   my $table;
  
   $query = $SQL->prepare('SELECT player.recon,unit.id, unittype.name FROM player,unit, unittype ' . 
                          'WHERE unittype.id = unit.unit_id AND unit.player_id = ? AND player.id = ? AND unittype.id = ? ' . 
                          'AND unit.amount > 0');
   $query->execute($$source{id},$$source{id}, $SPY{recon});

   if(!$query->rows())
   {
      player_msg($source, 'Your nation does not have any spys!');
      return 0;
   }

   $spy = $query->fetchrow_hashref();

   $query = $SQL->prepare('SELECT id,nick,recon FROM player WHERE nick=? AND active=1');
   $query->execute($$parv[1]);

   if(!$query->rows())
   {
      player_msg($source, 'No player by that name exists in this world.');
      return 0; 
   }
   
   $target = $query->fetchrow_hashref();
   if($$spy{recon} == 0) {
	  #Player has not deployed a Recon spy yet, deploy and update value
      $$spy{recon} = $$target{id}; 
   }   

   if($$target{id} != $$spy{recon}) {
       #player already deployed a recon spy and tried to spy elsewhere
       player_msg($source,"You must recall your spy before they can be reassigned");
       return 0;	 
   } 
 
   $$spy{title} = sql_gettitle($$source{id});
   #okay now we have a target, lets do a roll to see if the spy succeeds
   if(rand(4) < 1)
   {
      player_msg($source, 'Your spy has been caught and executed!');
      player_msg(getsource($$target{id}), sprintf('You have caught and executed a %s from %s!', $$spy{name}, $$spy{title}));
      sql_log($$target{id}, 'DEFENSE', sprintf('You have caught and executed a %s from %s!', $$spy{name}, $$spy{title}));
 
      $query = $SQL->prepare('UPDATE unit SET amount = amount - 1 WHERE id=?');
      $query->execute($$spy{id});
      
      if(antibully($$source{id},$$target{id})) {
         sql_add_retaliation($$target{id}, $$source{id}); #add an attack to the defenders retaliation table as this player is outside of their range     
      }

      return 1;
   }
   $query = $SQL->prepare('SELECT structure.id,structure.structure_id,structure.amount,structuretype.name FROM structure,structuretype WHERE structure.player_id =? AND structure.amount > 0 AND structuretype.id = structure.structure_id');
   $query->execute($$target{id}); 

   if(!$query->rows())
   {
      player_msg($source, sprintf('Your spy has reported that %s does not have any structures.', sql_gettitle($$target{id})));
      return 1;
   }

   $table = new Text::ASCIITable;
   $table->setCols(['Structure','Bomb ID',]);
   $table->alignCol('Bomb ID', 'right');
   $table->setOptions('headingText', sprintf('Reconnaissance Report (%s)', sql_gettitle($$target{id})));

   while($structure = $query->fetchrow_hashref())
   {
      if(rand(2) < 1)
      {
         $table->addRow($$structure{name},$$structure{id});
      }
      else
      {
         $$structure{id} =~ s/[0-9]/\?/g;
         $table->addRow($$structure{name},$$structure{id});
      }
   }
   
   #Mail the report to the player
   $query = $SQL->prepare("INSERT INTO mail SET from_player=?, player_id=?,message=?");  
   $query->execute("The Spy",$$source{id},$table->draw());
   
   #update recon value
   $query = $SQL->prepare('UPDATE player SET recon = ? WHERE id = ?');
   $query->execute($$target{id},$$source{id});     	 
   player_msg($source,"You have new mail waiting");
   
   return 1; 
}

sub cmd_spy
{
   my $parv   = $_[0];
   my $source = $_[1];

   my $query;
   my $row;

   my $spy;
   my $target;
   my $unit;
   my $table;
  
   $query = $SQL->prepare('SELECT unit.id, unittype.name FROM unit, unittype ' . 
                          'WHERE unittype.id = unit.unit_id AND unit.player_id = ? AND unittype.id = ? ' . 
                          'AND unit.amount > 0');
   $query->execute($$source{id}, $SPY{spy});

   if(!$query->rows())
   {
      player_msg($source, 'Your nation does not have any spys!');
      return 0;
   }

   $spy = $query->fetchrow_hashref();

   $query = $SQL->prepare('SELECT id,nick FROM player WHERE nick=? AND active=1');
   $query->execute($$parv[1]);

   if(!$query->rows())
   {
      player_msg($source, 'No player by that name exists in this world.');
      return 0; 
   }
   
   $target = $query->fetchrow_hashref();
   $$target{title} = sql_gettitle($$source{id});
   #okay now we have a target, lets do a roll to see if the spy succeeds
   if(rand(4) < 1)
   {
      player_msg($source, 'Your spy has been caught and executed!');
      player_msg(getsource($$target{id}), sprintf('You have caught and executed a %s from %s!', $$spy{name}, $$target{title}));
      sql_log($$target{id}, 'DEFENSE', sprintf('You have caught and executed a %s from %s!', $$spy{name}, $$target{title}));
 
      $query = $SQL->prepare('UPDATE unit SET amount = amount - 1 WHERE id=?');
      $query->execute($$spy{id});
      
      if(antibully($$source{id},$$target{id})) {
         sql_add_retaliation($$target{id}, $$source{id}); #add an attack to the defenders retaliation table as this player is outside of their range     
      }

      return 1;
  }

   $query = $SQL->prepare('SELECT unittype.name, unit.amount ' . 
                          'FROM unit, unittype ' . 
                          'WHERE unittype.id = unit.unit_id AND unit.amount > 0 AND unit.player_id = ?');
   $query->execute($$target{id}); 

   if(!$query->rows())
   {
      player_msg($source, sprintf('Your spy has reported that %s does not have any units.', sql_gettitle($$target{id})));
      return 1;
   }

   $table = new Text::ASCIITable;
   $table->setCols(['Type', 'Amount']);
   $table->alignCol('Amount', 'right');
   $table->setOptions('headingText', sprintf('Intelligence Report (%s)', sql_gettitle($$source{id})));

   while($unit = $query->fetchrow_hashref())
   {
      if(rand(2) < 1)
      {
         $table->addRow($$unit{name},  $$unit{amount});
      }
      else
      {
         $$unit{amount} =~ s/[0-9]/\?/g;
         $table->addRow($$unit{name}, $$unit{amount});
      }
   }
   player_msg($source, $table->draw());
   return 1;
}



# cmd_surrender
#
# SURRENDER

sub cmd_surrender
{
   my $parv   = $_[0];
   my $source = $_[1];

   my $query;
   my $row;

   my $percentage = $$parv[1];

   if(has_flag($$source{id}, 'surrender'))
   { 
      player_msg($source, 'You may only change your surrender once every housekeeping.');
      return 0;
   }

   if($percentage =~ /^[\d]+$/ && $percentage <= 100 && $percentage >= 10)
   {
      $query = $SQL->prepare('UPDATE player SET surrender=? WHERE id=?');
      $query->execute($percentage, $$source{id});
      player_msg($source, sprintf('Your surrender level is now %d%%.', $percentage));

      set_flag($$source{id}, 'surrender');
      return 1;
   }
   else
   {
      player_msg($source, 'You must specify a valid percentage');
      return 0;
   } 

   return 0;
}

# cmd_tax
#
# TAX <percentage>

sub cmd_tax
{
   my $parv   = $_[0];
   my $source = $_[1];

   my $query;
   my $row;

   my $percentage = $$parv[1];

   if($percentage =~ /^[\d]+$/ && $percentage <= 100 && $percentage >= 0)
   {  
      if ($percentage > 50) {
	     player_msg($source,"International law forbids taxation above 50%");
	     return 0;
      }
      $query = $SQL->prepare('UPDATE player SET tax=? WHERE id=?');
      $query->execute($percentage, $$source{id});
      player_msg($source, sprintf('Your nation\'s tax is now %d%%.', $percentage));
      return 1;
   }
   else
   {  
      player_msg($source, 'You must specify a valid percentage');
      return 0;
   }
}



# cmd_train
#
# TRAIN <amount> <type>

sub cmd_train
{
   my $parv   = $_[0];
   my $source = $_[1];

   my $query;
   my $row;

   my $amount = $$parv[1];
   my $type = $$parv[2];

   my $unittype;

   int $amount;
   if($amount < 0)
   {
      player_msg($source, 'You must specify a positive amount');
      return 0;
   }  

   #first get the unit type and check if it actually exists!
   $query = $SQL->prepare('SELECT id, prereq, wage, name FROM unittype WHERE name=? AND train=\'true\'');
   $query->execute($type);
   
   if(!$query->rows())
   {
      player_msg($source, 'No such method of training exists.');
      return 0;
   }

   $unittype = $query->fetchrow_hashref();

   if($$unittype{prereq} && !sql_has_research($$source{id}, $$unittype{prereq}))
   {
      player_msg($source, 'Your nation\'s marine corp does not have information on that method of training.');
      return 0;
   }

   #check to see if player has enough farmers
   $query = $SQL->prepare('SELECT money,farmers FROM player WHERE id=?');
   $query->execute($$source{id});
   $row = $query->fetchrow_hashref(); 

   if($$row{farmers} < $amount)
   {
      player_msg($source, 'Your nation does not possess enough farmers for that.');
      return 0;
   }

   #check to see if they can afford it
   if($amount * $$unittype{wage} > $$row{money})
   {
      player_msg($source, sprintf('Your nation cannot afford to pay the starting wage of $%d ' . 
                               'required to train these troops.', $amount * $$unittype{wage}));
      return 0;
   }

   #okay, all looks well, lets give them the units
   sql_unit($$source{id}, $$unittype{id}, $amount);

   #subtract the farmers
   $query = $SQL->prepare('UPDATE player SET farmers = farmers - ? WHERE id=?');
   $query->execute($amount, $$source{id});

   player_msg($source, sprintf('Your drill sergaents have trained %d %s(s). These new troops will ' .  
                            'cost your nation $%d/month.',
                            $amount, $$unittype{name}, $amount * $$unittype{wage})); 

   sql_money($$source{id}, -($amount * $$unittype{wage}));
   return 1;
}

###########################################################################################
#                              HOUSEKEEPING FUNCTIONS                                     #
###########################################################################################

sub hk_schedule()
{
   my $time;

   $time = time + ($GAME_OPTIONS{hk_interval} - (time % $GAME_OPTIONS{hk_interval}));

   #set a timer to start at the next hour point
   $HK_TIMER = Event->timer(at=>$time, interval=>$GAME_OPTIONS{hk_interval}, hard=>1, cb=>\&do_housekeeping);
}

sub ten_schedule()
{
   my $time;
   
   $time = time + (600 - (time % 600));
   $TEN_TIMER =  Event->timer(at=>$time, interval=>600, hard=>1, cb=>\&do_tenminute);
}

sub do_tenminute
{

   my @present;
   my $sec;

   my $query;
   my $row;

   $query = $SQL->prepare('SELECT id FROM player WHERE active=1');
   $query->execute();

   return if(!$query->rows()); #no players!

   ten_session(); #Clean up stale sessions from database
   while($row = $query->fetchrow_hashref())
   {
      ten_session_source($$row{id}); #Check for stale session source and clean
      ten_spacemove($$row{id});
      ten_spaceintercept($$row{id});
      ten_mp($$row{id});
      ten_expire_retaliation($$row{id});
      if(!has_flag($$row{id},'ai'))
      {
         ten_achievement($$row{id});
      }
   }

   #select the AI
   $query = $SQL->prepare('SELECT id FROM player WHERE FIND_IN_SET(?, flags) > 0 AND active=1');
   $query->execute('ai');
   if ($query->rows()) {
      #we have AI
	  while($row = $query->fetchrow_hashref())
   	  {
	     do_ai_ten($$row{id});
	  }
   }
   #Why is this here? because when multiple shuttles are tied for the race the one
   #with the lowest player id won. the way i changed it will now cause the lowest
   #space ID to win - CrazySpence
   ten_spaceoutofrange();
   
   #asteroid movement
   #asteroid will have a player id of 0 so do a spacemove for player_id 0
   ten_spacemove(0);

   #Check asteroid endgame
   ten_asteroid();
}

sub ten_achievement
{
   my $player_id = $_[0];
   my $query;
   my $player_data;
   my $player_stat;
   my $achievement;

   #Get Player data
   $query = $SQL->prepare("SELECT land,farmers,money FROM player WHERE id=?");
   $query->execute($player_id);

   $player_data = $query->fetchrow_hashref();

   #Get Player Statistics
   $query = $SQL->prepare("SELECT * FROM player_statistics WHERE player_id=?");
   $query->execute($player_id);
   
   $player_stat = $query->fetchrow_hashref();

   #compare with achievements 
   $query = $SQL->prepare("SELECT * FROM achievementtype");
   $query->execute();   

   while($achievement = $query->fetchrow_hashref())
   {
      if($$achievement{wins} != -1) {
         if(($$achievement{farmers} <= $$player_data{farmers}) && ($$achievement{land} <= $$player_data{land}) && ($$achievement{money} <= $$player_data{money}) && ($$achievement{killed} <= $$player_stat{killed}) && ($$achievement{died} <= $$player_stat{died}) && ($$achievement{launched} <= $$player_stat{launched}) && ($$achievement{downed} <= $$player_stat{downed}) && ($$achievement{wins} <= $$player_stat{wins}) && ($$achievement{bomb_structure} <= $$player_stat{bomb_structure}) && ($$achievement{bomb_civillian} <= $$player_stat{bomb_civillian}) && ($$achievement{civillian_lost} <= $$player_stat{civillian_lost}) && ($$achievement{quest_complete} <= $$player_stat{quest_complete}) && ($$achievement{quest_pk} <= $$player_stat{quest_pk}))
         {
            sql_add_achievement($player_id,$$achievement{name});
         }
      }
   }     
}

sub ten_session
{
   #Clean up idle sessions
   my $query;
   
   $query = $SQL->prepare("DELETE FROM sessions WHERE (time_to_sec(NOW()) - time_to_sec(time)) > 3600");
   $query->execute();
}

sub ten_session_source
{
   #Clean up sources tied to expired sessions
   my $player_id = $_[0];
   my $query;
   my $row;
   my $source;

   if($source = getsource($player_id)) {
      if($$source{sess}) {
         if(sql_session_nick($$source{nickname}) == 0) {
            if(has_flag($$source{id}, 'quest')) {
               $query = $SQL->prepare("SELECT x,y FROM quest_state WHERE player_id=?");
               $query->execute($$source{id});
               if($query->rows()) {
                  $query = $SQL->prepare("UPDATE quest_state SET x=?,y=? WHERE player_id=?");
                  $query->execute($$source{xcords},$$source{ycords},$$source{id});
               } else {
                  $query = $SQL->prepare("INSERT INTO quest_state SET x=?,y=?,player_id=?");
                  $query->execute($$source{xcords},$$source{ycords},$$source{id});
               }
            }
            unregister_player($source);
         }
      }
   }
}

sub ten_spacemove
{
   my $player_id = $_[0];
   my $query;
   my $query2;
   my $row;

   my $distance;

   $query = $SQL->prepare('SELECT unittype.speed, space.distance, space.id ' . 
                          'FROM unittype,space ' . 
                          'WHERE space.player_id = ? AND space.unit_id = unittype.id');
   $query->execute($player_id);

   if($query->rows())
   {
      while($row = $query->fetchrow_hashref())
      {
         $distance = $$row{distance} + $$row{speed};
         $query2 = $SQL->prepare('UPDATE space SET distance=? WHERE id=?');
         $query2->execute($distance, $$row{id});
      }
   } 
}

sub ten_spaceintercept()
{
   my $player_id = $_[0];
   my $query;
   my $query2;
   my $row;

   my $missile;
   my $target;

   my $dice;
   my $counter;

   #Get all projectiles with a target
   $query = $SQL->prepare('SELECT unittype.name, unittype.attack, space.distance, space.id, space.target_id, ' .
                          'unittype.speed ' . 
                          'FROM unittype,space ' .
                          'WHERE space.player_id = ? AND space.unit_id = unittype.id AND space.target_id > 0');

   $query->execute($player_id);

   if($query->rows())
   {
      while($missile = $query->fetchrow_hashref())
      {
         $query2 = $SQL->prepare('SELECT unittype.name, unittype.defense, space.distance, space.player_id, ' .
                                 'unittype.speed ' . 
                                 'FROM unittype, space ' . 
                                 'WHERE space.id = ? AND space.unit_id = unittype.id');

         $query2->execute($$missile{target_id});
         return if(!$query2->rows());
         $target = $query2->fetchrow_hashref();

         #prevent same speed objects from colliding within same launch window
         next if($$missile{speed} <= $$target{speed});

         #interception
         if($$missile{distance} >= $$target{distance})
         {
            global_msg(sprintf('%s\'s %s (%d) barrels down on an intercept with %s\'s %s (%d).',
                               sql_gettitle($player_id), $$missile{name}, $$missile{id}, sql_gettitle($$target{player_id}),
                               $$target{name}, $$missile{target_id}));


            $counter = $$missile{attack} + $$target{defense};
            $dice = rand(1);

            if($dice <= ($$missile{attack} / $counter))
            {
               if(sql_has_research($$target{player_id},23)) { #23 is for evasive manuevers, some day make this more dynamic
                  if((rand(1)) <= .25) {
                     global_msg('The shuttle captain barks an order at his helmsmen "Eject Chaffe pod and engage evasive pattern delta!!"');
                     global_msg('The missile takes the bait and explodes as it slams into the pod, the captain breathes a sigh of relief');
                     return;
                  } else {
                     #remove target
                     $query2 = $SQL->prepare('DELETE FROM space WHERE id=? OR target_id=?');
                     $query2->execute($$missile{target_id}, $$missile{target_id});

                     global_msg('The shuttle captain casually states an order at his helmsmen "List lazily to the left please"');
                     global_msg(sprintf('In an immense explosion, %s\'s %s (%d) collides with %s\'s %s (%d). ' .
                                   'Little more than scattered pieces of the %s remain.',
                               sql_gettitle($player_id), $$missile{name}, $$missile{id}, sql_gettitle($$target{player_id}),
                               $$target{name}, $$missile{target_id}, $$target{name}));
                     #Updated downed Statistic
                     $query = $SQL->prepare("UPDATE player_statistics SET downed=(downed + 1) WHERE player_id=?");
                     $query->execute($player_id);
                     return;
                  }
               } else {
                  #remove target
                  $query2 = $SQL->prepare('DELETE FROM space WHERE id=? OR target_id=?');
                  $query2->execute($$missile{target_id}, $$missile{target_id});


                  global_msg(sprintf('In an immense explosion, %s\'s %s (%d) collides with %s\'s %s (%d). ' .
                                   'Little more than scattered pieces of the %s remain.',
                               sql_gettitle($player_id), $$missile{name}, $$missile{id}, sql_gettitle($$target{player_id}),
                               $$target{name}, $$missile{target_id}, $$target{name}));
                  #Updated downed Statistic
                  $query = $SQL->prepare("UPDATE player_statistics SET downed=(downed + 1) WHERE player_id=?");
                  $query->execute($player_id);
                  return;
               }
            }
            else
            {

               global_msg(sprintf('%s\'s %s (%d) narrowly misses %s\'s %s (%d).',
                               sql_gettitle($player_id), $$missile{name}, $$missile{id}, sql_gettitle($$target{player_id}),
                               $$target{name}, $$missile{target_id}));


            } 

            #destroy missile
            $query2 = $SQL->prepare('DELETE FROM space WHERE id=? OR target_id=?');
            $query2->execute($$missile{id}, $$missile{id});
         } 
      }
   }
}

sub ten_spaceoutofrange
{
   #my $player_id = $_[0]; No longer needed, see do_tenminute  - CrazySpence
   my $query;
   my $query2;
   my $row;

   my $distance;

   $query = $SQL->prepare('SELECT space.distance, space.id, space.player_id, unittype.type, player.nick, unittype.name ' .
                          'FROM unittype,space, player ' .
                          'WHERE space.unit_id = unittype.id AND player.id = space.player_id ORDER BY space.id');
   $query->execute();

   if($query->rows())
   {
      while($row = $query->fetchrow_hashref())
      {
         if($$row{distance} > $GAME_OPTIONS{spacerange})
         {
            if($$row{type} == $UTYPE{shuttle})
            {
               global_msg(sprintf('%s\'s %s (%d) has reached the outer boundries of Earth\'s solar system and passes out of range.',
                           $$row{nick}, $$row{name}, $$row{id}));
               #update win statistic
               $query = $SQL->prepare("UPDATE player_statistics SET wins=(wins + 1) WHERE player_id=?");
               $query->execute($$row{player_id});
               
               endgame($$row{player_id});
               return;
            }
            $query2 = $SQL->prepare('DELETE FROM space WHERE id=? OR target_id=?');
            $query2->execute($$row{id}, $$row{id});
         }
      }
   }
}

sub ten_asteroid
{
   my $query;
   my $row;

   #No other incoming id's with id 0 exist at the momnent. if I ever change that this query will need to be more specific
   $query = $SQL->prepare('SELECT distance FROM space WHERE player_id=0');
   $query->execute();

   if($query->rows())
   {
      $row = $query->fetchrow_hashref();
      if($$row{distance} <= 0)
      {
         endgame(0);
         return;
      }
   }
}

sub do_ai_ten
{
	#hail to the king baby
	#This sub is all about taking down AND LAUNCHING shuttles, i don't want AI's to fire off as many missles as possible at hk, I want them to fire off 1 every 10 min so
	#if they have the mp and missiles they will shoot 6 per hour - King Phil the CrazySpence
	
	my $id = $_[0];
	my $query;
	my $playerquery;
	my $row;
	my $player;
	my $mp;
	my $missiles;
	
	if(has_flag($id,'established')) {
		$query = $SQL->prepare('SELECT space.id,player_id,unit_id FROM space ORDER by space.id');
		$query->execute();
		
		if ($query->rows()) {
			$playerquery = $SQL->prepare('SELECT mp,amount,unit.id,unittype.name FROM player,unit,unittype WHERE unit.unit_id = 12 AND unit.player_id = ? AND player.id=? AND unittype.id=12');
			$playerquery->execute($id,$id);
			$player = $playerquery->fetchrow_hashref();
			$mp = $$player{mp};
			$missiles = $$player{amount};
			
			while($row = $query->fetchrow_hashref()) {
				#1 missile for every shuttle in space, if possible
				if (($$row{player_id} != $id) && ($$row{unit_id} == 10) && ($mp > 10) && ($missiles > 0)) {
					#fire the missiles!
					ai_launch($id,$$row{id},$$player{id},12,$$player{name});
					$mp        = $mp - 10;
					$missiles = $missiles - 1;
					sql_mp($id,-10);
				}
			}
		}
		$query = $SQL->prepare('SELECT unit.id,unittype.name,amount,mp FROM unit,player,unittype WHERE unit_id=10 AND unittype.id=10 AND player_id=? AND player.id=?');
		$query->execute($id,$id);
		if ($query->rows()) {
			#Houston we are go
			$row = $query->fetchrow_hashref();
			if ($$row{mp} >= 10 && $$row{amount} > 0) {
				ai_launch($id,0,$$row{id},10,$$row{name});
				sql_mp($id,-10);
			}
		}
	}
	
}
sub ai_launch
{
	my $id = $_[0];
	my $target = $_[1];
	my $uid = $_[2];
	my $unit = $_[3];
	my $name = $_[4];
	my $query;
	
	$query = $SQL->prepare('INSERT INTO space SET player_id=?, unit_id=?, target_id=?');
	$query->execute($id, $unit, $target);

	$query = $SQL->prepare('UPDATE unit SET amount = amount - 1 WHERE id=?');
	$query->execute($uid);
				
	#make announcements
	global_msg(sprintf('In the far distance a flash of bright light and smoke form over %s.',sql_getcountry($id)));  
	global_msg(sprintf('The Earth trembles as %s launches a %s into space.', sql_gettitle($id),$name));
}

sub ten_mp
{
   my $player_id = $_[0];
   my $query;
   my $row;
   
   my $mp;
   my $bank;
   
   $query = $SQL->prepare('SELECT mp, mp_bank FROM player WHERE id=?');
   $query->execute($player_id);
   $row = $query->fetchrow_hashref();
   
   $mp = $$row{mp};
   $bank = $$row{mp_bank};

   if ($mp < $GAME_OPTIONS{mp_max} && $bank > 0){
        $query = $SQL->prepare('UPDATE player SET mp = mp + 1, mp_bank = mp_bank - 1 WHERE id=?');
        $query->execute($player_id);     
   }

}
sub do_housekeeping 
{
   my @present;
   my $sec;

   my $query;
   my $row;

   global_msg('The dust settles for a brief moment...');

   $query = $SQL->prepare('SELECT id,recon,took_quest FROM player WHERE active=1');
   $query->execute();

   return if(!$query->rows()); #no players!

   while($row = $query->fetchrow_hashref())
   {
      #Evil check
      if(favor($$row{id}) < -98.99) {
	      #you are too evil to live
	      sql_evildead($$row{id});
      
      } else {
         #The else was added because after adding static accounts a dead player still got their reset data HK'd if the died because of evildead
         hk_tax($$row{id});
         hk_population($$row{id});
         hk_production($$row{id});     
         hk_research($$row{id});
         hk_wage($$row{id});
         hk_surrender($$row{id});
         hk_mp($$row{id});
         hk_count($$row{id});
         if ($$row{recon} != 0) {
            hk_recon($$row{id});
         }
         if ($$row{took_quest} != 0) {
            if(!has_flag($$row{id},'quest'))    {
               hk_clearquest($$row{id});
            }    
         }
         if(has_flag($$row{id},'ai'))    {
            do_ai($$row{id});
         }
         if (rand(1) < .05) {
            #random event
            hk_event($$row{id});
         } 
         
      }
   }
   hk_free_market();
   $query = $SQL->prepare('SELECT unittype.id, ROUND(space.distance / (unittype.speed * -1) / 144) AS doomsday FROM unittype, space WHERE unittype.name=\'Asteroid\' AND space.unit_id=unittype.id');
   $query->execute();

   if ($query->rows()) {
      $row = $query->fetchrow_hashref();
      global_msg(sprintf("Taxes collected and wages paid, a month has passed. There are less than %s days until impact",($$row{doomsday} + 1)));
   } else {
      global_msg('Taxes collected and wages paid, a month has passed. Go on great nations and continue to conquer.');
   }
}

sub ten_expire_retaliation
{
   #Retaliation expires over time, it used to be by the hk but that was allowing lager players to monopolize. Now it expires over 10 min, so 3 attacks from a newb would expire in 30 minutes allowing a chance for revenge but not drawing it out forever.
   my $player_id = $_[0];
   my $query;
   my $row;
   my $update;   
 	
   $query = $SQL->prepare('SELECT player_id,attacker_id,attacks,attacked FROM retaliation WHERE player_id=?');
   $query->execute($player_id);   

   if (!$query->rows())	{ return; }
   
   while ($row = $query->fetchrow_hashref())
   {
      if ($$row{attacked} > $$row{attacks})
      {
	      $update = $SQL->prepare('UPDATE retaliation SET attacked=(attacked-1) WHERE player_id=? AND attacker_id=?');
	      $update->execute($$row{player_id},$$row{attacker_id}); 
      }	
   }
}

sub hk_clearquest
{
   my $query;
   my $player_id = $_[0];

   $query = $SQL->prepare('UPDATE player SET took_quest=0 WHERE id=?');
   $query->execute($player_id);
}

sub hk_event
{
   #Hoorah a random event has been requested!
   my $player_id = $_[0];
   my $event = int(rand($GAME_EVENT) + 1);
   my $query;
   my $row;
   my $structure;
   my $research;
   my $unit;

   $query = $SQL->prepare("SELECT * FROM events WHERE id=?");
   $query->execute($event);

   if(!$query->rows()) { return; } 

   $row = $query->fetchrow_hashref();

   if ($$row{farmers} != 0) {
      $query = $SQL->prepare("UPDATE player SET farmers = farmers + ? WHERE id =?");
      $query->execute($$row{farmers},$player_id);
   }

   if ($$row{scientists} != 0) {
      $query = $SQL->prepare("UPDATE player SET scientists = scientists + ? WHERE id =?");
      $query->execute($$row{scientists},$player_id);
   }

   if ($$row{money} != 0) {
      $query = $SQL->prepare("UPDATE player SET money = money + ? WHERE id =?");
      $query->execute($$row{money},$player_id);
   }

   if ($$row{structure} != 0) {
      $query = $SQL->prepare("SELECT structure.id,structuretype.size FROM structure,structuretype WHERE structure.player_id=? AND structure.structure_id=? AND structuretype.id = ?");   
      $query->execute($player_id,$$row{structure},$$row{structure});
      if ($query->rows()) {
          $structure = $query->fetchrow_hashref();
          if ($$row{workers} != 0) {
             $query = $SQL->prepare("UPDATE structure SET amount = amount + 1,workers = workers + ? WHERE id=?");
             $query->execute($$row{workers},$$structure{id});
          } else {
             $query = $SQL->prepare("UPDATE structure SET amount = amount + 1 WHERE id=?");
             $query->execute($$structure{id});
          }
          #The following query increases the nation land by the size of the structure because you are discovering this outside your nation.
          $query = $SQL->prepare("UPDATE player SET land = land + ? WHERE id=?");
          $query->execute($$structure{size},$player_id);
      } else {
          $query = $SQL->prepare("SELECT size FROM structuretype WHERE id=?");
          $query->execute($$row{structure});
          $structure = $query->fetchrow_hashref();
          if ($$row{workers} != 0) {
             $query = $SQL->prepare("INSERT INTO structure SET structure_id=?,player_id=?,amount=1,workers=?");
             $query->execute($$row{structure},$player_id,$$row{workers});  
          } else {
             $query = $SQL->prepare("INSERT INTO structure SET structure_id=?,player_id=?,amount=1,workers=0");
             $query->execute($$row{structure},$player_id);
          }
          #The following query increases the nation land by the size of the structure because you are discovering this outside your nation.
          $query = $SQL->prepare("UPDATE player SET land = land + ? WHERE id=?");
          $query->execute($$structure{size},$player_id);

      }
   }

   if ($$row{unit} != 0) {
      $query = $SQL->prepare("SELECT id FROM unit WHERE player_id=? AND unit_id=?");
      $query->execute($player_id,$$row{unit});
      if($query->rows()) {
         $unit = $query->fetchrow_hashref();
         $query = $SQL->prepare("UPDATE unit SET amount = amount + ? WHERE id=?");
         $query->execute((int(rand(15) + 1)), $$unit{id});
      } else {
         $query = $SQL->prepare("INSERT INTO unit SET player_id=?,unit_id=?,amount=?");
         $query->execute($player_id,$$row{unit},(int(rand(15) + 1)));
      }
   }

   if ($$row{research} != 0) {
       $query = $SQL->prepare("SELECT id FROM research WHERE player_id=? AND research_id=?");
       $query->execute($player_id,$$row{research});
       if ($query->rows()) {
          $research = $query->fetchrow_hashref();
          $query = $SQL->prepare("UPDATE research SET allocation=0,level=100 WHERE id=?");
          $query->execute($$research{id});   
       } else {
          $query = $SQL->prepare("INSERT INTO research SET player_id=?,research_id=?,allocation=0,level=100");
          $query->execute($player_id,$$row{research});
       }
   }

   player_msg(getsource($player_id),$$row{message});   
   sql_log($player_id,'EVENT',sprintf("%s",$$row{message}));

   #make sure everything is balanced
   sql_balance_workers($player_id);
   sql_balance_scientists($player_id);
   sql_balance_player($player_id);    

   return;
}
sub hk_recon
{
   #Recon actions at HK
   my $player_id = $_[0];
   my $query;
   my $structure;
   my $spy;
   my $table;

   
   $query = $SQL->prepare("SELECT player.id,player.nick,player.recon,unittype.name FROM player,unittype WHERE player.id=? AND unittype.id=?");
   $query->execute($player_id, $SPY{recon});  

   $spy = $query->fetchrow_hashref();
   
   $$spy{title} = sql_gettitle($player_id);
   #okay now we have a target, lets do a roll to see if the spy succeeds
   if(rand(4) < 1)
   {
      player_msg(getsource($player_id), 'Your spy has been caught and executed!');
      sql_log(getsource($player_id),'DEFENSE', 'Your spy has been caught and executed!');
      player_msg(getsource($$spy{recon}), sprintf('You have caught and executed a %s from %s!', $$spy{name}, $$spy{title}));
      sql_log($$spy{recon}, 'DEFENSE', sprintf('You have caught and executed a %s from %s!', $$spy{name}, $$spy{title}));
 
      $query = $SQL->prepare('UPDATE unit,player SET unit.amount = unit.amount - 1,recon = 0 WHERE unit.unit_id=? AND unit.player_id=? AND player.id=?');
      $query->execute($SPY{recon},$$spy{id},$$spy{id});

      return 1;
   }
   $query = $SQL->prepare('SELECT structure.id,structure.structure_id,structure.amount,structuretype.name FROM structure,structuretype WHERE structure.player_id =? AND structure.amount > 0 AND structuretype.id = structure.structure_id');
   $query->execute($$spy{recon}); 

   if(!$query->rows())
   {
      player_msg(getsource($player_id), sprintf('Your spy has reported that %s does not have any structures.', sql_gettitle($$spy{recon})));
      return 1;
   }

   $table = new Text::ASCIITable;
   $table->setCols(['Structure','Bomb ID',]);
   $table->alignCol('Bomb ID', 'right');
   $table->setOptions('headingText', sprintf('Reconnaissance Report (%s)', sql_gettitle($$spy{recon})));

   while($structure = $query->fetchrow_hashref())
   {
      if(rand(2) < 1)
      {
         $table->addRow($$structure{name},$$structure{id});
      }
      else
      {
         $$structure{id} =~ s/[0-9]/\?/g;
         $table->addRow($$structure{name},$$structure{id});
      }
   }
   
   $query = $SQL->prepare("INSERT INTO mail SET from_player=?, player_id=?,message=?");  
   $query->execute("The Spy",$player_id,$table->draw());
   if(is_registered($$spy{nick})) {
      player_msg(getsource($player_id),"You have new mail waiting");
   }
}

sub hk_tax
{
   my $player_id = $_[0];

   my $income;
   my $income_tax;
   my $favor_alt;

   my $query;
   my $row;
   
   $query = $SQL->prepare('SELECT farmers, tax FROM player WHERE id=?');
   $query->execute($player_id);
   $row = $query->fetchrow_hashref();

   #do favor hit for tax level
   if($$row{tax} != 7)
   {
      if($$row{tax} < 7)
      {
         $favor_alt = 10 * (7 - $$row{tax});
      }
      else
      {
         $favor_alt = -1 * ((($$row{tax} - 7) + 2) ** 2);
      }
      altfavor($player_id, $favor_alt);
   }
   #calculate tax
   $income = 100 * rand_range(.95,1);

   $income_tax = $income * $$row{farmers} * $$row{tax} * hk_taxbonus($player_id);
   $income_tax += $income_tax * pfavor($player_id);
   $income_tax = int $income_tax;
 
   return if ($income_tax <= 0);

   sql_log($player_id, 'GENERAL', sprintf('Your farming industry has produced $%d in taxes.', $income_tax)); 

   $query = $SQL->prepare('UPDATE player SET money = money + ? WHERE id=?');
   $query->execute($income_tax, $player_id);

}

sub hk_taxbonus()
{
     my $id = $_[0];
     my $query;
     my $row;
     
     $query = $SQL->prepare('SELECT player.farmers,unit.amount FROM player,unit WHERE unit.unit_id=? AND unit.player_id=? and player.id=?');
     $query->execute("15",$id,$id);
     if ($row = $query->fetchrow_hashref()) {
          return if ($$row{farmers} == 0);
          if ($$row{amount} > $$row{farmers}) {
               $$row{amount} = $$row{farmers};
          }
          
          $query = $SQL->prepare('UPDATE unit SET amount = amount - ? WHERE player_id=? AND unit_id=?');
          $query->execute($$row{amount},$id,"15",);
          return (($$row{amount} / $$row{farmers}) * $GAME_OPTIONS{tax_bonus} + .01 ) #modified bonus
     }
     
     return 0.01; #default tax bonus
}

sub hk_population
{
   my $player_id = $_[0];
   
   my $query;
   my $row;

   my $babies;
   my $dead;
   my $population;

   my $population_multiplier = $GAME_OPTIONS{land_ratio}; #Urban planning gets you 2 people per acre

   $query = $SQL->prepare('SELECT research.id FROM research,researchtype WHERE researchtype.name=\'Urban Planning\' AND research.research_id=researchtype.id AND research.player_id=? AND research.level=100');
   $query->execute($player_id);
   if($query->rows()) {
      $population_multiplier = $population_multiplier * 2;   
   } 

   $query = $SQL->prepare('SELECT farmers,land FROM player WHERE id=?');
   $query->execute($player_id);
   $row = $query->fetchrow_hashref();

   $population = sql_population($player_id);

   #if we're over pop, some farmers die to balance it out   
   if(($$row{land} * $population_multiplier) <= $population)
   {
      $dead = int($$row{farmers} * rand_range($GAME_OPTIONS{popgrowth_min}, $GAME_OPTIONS{popgrowth_max}));

      sql_log($player_id, 'GENERAL', sprintf('%d farmers have died this month.', $dead));
      $query = $SQL->prepare('UPDATE player SET farmers = farmers - ? WHERE id=?');
      $query->execute($dead, $player_id);
      #put dead farmers into the lottery
      hk_population_lottery($dead);
      return;
   }

   #$babies = int($$row{farmers} * rand_range($GAME_OPTIONS{popgrowth_min}, $GAME_OPTIONS{popgrowth_max}));
   $babies = int($$row{farmers} * hk_babybonus($player_id));
   $babies += $babies * pfavor($player_id);
   $babies = int $babies;
 
   if($babies > 0)
   {
      sql_log($player_id, 'GENERAL', sprintf('Your farmers (and wives) have produced %d babies!', $babies));
      $query = $SQL->prepare('UPDATE player SET farmers = farmers + ? WHERE id=?');
      $query->execute($babies, $player_id);
   }
}

sub hk_population_lottery
{
   my $farmers = $_[0];
   my $query;
   my $row;
   
   $query = $SQL->prepare("SELECT farmers FROM lottery WHERE winner= ''");
   $query->execute();
   
   if ($query->rows()) {
      $query = $SQL->prepare("UPDATE lottery SET farmers = farmers + ? WHERE winner = ''");
      $query->execute($farmers);
   } else {
      $query = $SQL->prepare("INSERT INTO lottery (farmers) VALUES (?) ");
      $query->execute($farmers);
   }
   return;
}

sub hk_babybonus
{
    my $player_id = $_[0];
    my $query;
    my $row;
    
    $query = $SQL->prepare('SELECT player.farmers,unit.amount FROM player,unit WHERE unit.unit_id=? AND unit.player_id=? and player.id=?');
    $query->execute("16",$player_id,$player_id);
    
    if($row = $query->fetchrow_hashref()) {
          return if ($$row{farmers} == 0);
          if ($$row{amount} > $$row{farmers}) {
               $$row{amount} = $$row{farmers};
          }
          $query = $SQL->prepare('UPDATE unit SET amount = amount - ? WHERE player_id=? AND unit_id=?');
          $query->execute($$row{amount},$player_id,"16",);   
          return (($$row{amount} / $$row{farmers}) * $GAME_OPTIONS{baby_bonus} + rand_range($GAME_OPTIONS{popgrowth_min}, $GAME_OPTIONS{popgrowth_max}));
    }
    return (rand_range($GAME_OPTIONS{popgrowth_min}, $GAME_OPTIONS{popgrowth_max}));
}

sub hk_research
{
   my $player_id = $_[0];

   my $query;
   my $query2;
   my $row;
 
   my $scientists;
   my $growth;

   $query = $SQL->prepare('SELECT scientists FROM player WHERE id=?');
   $query->execute($player_id);
   $scientists = $query->fetchrow_hashref();

   $query = $SQL->prepare('SELECT player.country, research.id, research.level, research.allocation, research.level, ' . 
                          'researchtype.name, researchtype.cost ' . 
                          'FROM player, researchtype, research ' . 
                          'WHERE researchtype.id = research.research_id ' . 
                          'AND research.player_id = ? ' . 
                          'AND player.id = ?' .
                          'AND research.allocation > 0 ');

   return if(!$query->execute($player_id,$player_id));

   while($row = $query->fetchrow_hashref())
   {
      $growth = 100 * (($$scientists{scientists} * ($$row{allocation} * .01)) / $$row{cost});
      $growth *= rand_range(.9, 1); #randomize it a bit! INSERT FAVOR HERE PLZ!
      $growth +=  $growth * pfavor($player_id);

      next if ($growth <= 0);

      sql_log($player_id, 'RESEARCH', sprintf('Your scientists have pushed forward %.2f percent ' . 
                                              'in the area of \'%s\'.'
                                              ,$growth, $$row{name}));

      $$row{level} += $growth;
      
      #done researching this topic!
      if($$row{level} >= 100)
      {
         $$row{level} = 100;
         $$row{allocation} = 0;
         if($$row{name} eq "40 hour work week") {
              global_msg(sprintf("The workforce of %s cheers as the government writes into law the 40 hour work week!",$$row{country}));
         }
      }

      $query2 = $SQL->prepare('UPDATE research SET level=?, allocation=? WHERE id=?');
      $query2->execute($$row{level}, $$row{allocation}, $$row{id});
   } 
}

sub hk_production
{
   my $player_id = $_[0];

   my $query;

   my $factories;
   my $factory;

   my $unit;
   my $unittype;

   my $production;
   my $units_built;
   my $leftover_production;
    
   #get a list of all factories with workers that this player owns
   my $query; 

   $factories = $SQL->prepare('SELECT structuretype.name, structuretype.product, ' . 
                          'structure.amount, structure.workers ' . 
                          'FROM structuretype, structure ' .
                          'WHERE structure.structure_id = structuretype.id ' . 
                          'AND structure.player_id = ? ' . 
                          'AND structure.amount > 0 ' . 
                          'AND structure.workers > 0 ' . 
                          'AND structuretype.type = ?');
   $factories->execute($player_id, $STYPE{factory});

   #no factories with workers?
   return if (!$factories->rows());

   while($factory = $factories->fetchrow_hashref())
   {
      $query = $SQL->prepare('SELECT name, cost FROM unittype WHERE unittype.id = ?');
      $query->execute($$factory{product});
      $unittype = $query->fetchrow_hashref();

      return if $$unittype{cost} <= 0;

      $query = $SQL->prepare('SELECT id, build FROM unit WHERE player_id=? AND unit_id=?');
      $query->execute($player_id, $$factory{product});     

      #calculate the production value, units built, and leftover production
      $production = $$factory{workers} * hk_factorybonus($player_id);
      $production += $production * pfavor($player_id);

      #A percentage of all factory production from all players contributes to the free market
      hk_free_market_production($production,$unittype,$$factory{product});
      
      #there is no unit table? lets make one!
      if(!$query->rows())
      {
         $units_built = int($production / $$unittype{cost});
         if ($$unittype{cost} >= 1) {
            $leftover_production = $production % $$unittype{cost};
         } else {
            $leftover_production = $production % 1;
         }
         $query = $SQL->prepare('INSERT INTO unit SET player_id=?, unit_id=?, amount=?, build=?');
         $query->execute($player_id, $$factory{product}, $units_built, $leftover_production);   
      }
      else
      {
         $unit = $query->fetchrow_hashref();
         $production += $$unit{build};

         $units_built = int($production / $$unittype{cost});
         if ($$unittype{cost} >=1) {
            $leftover_production = $production % $$unittype{cost};
         } else {
            $leftover_production = $production % 1;
         }
         $query = $SQL->prepare('UPDATE unit SET amount = amount + ?, build=? WHERE id=?');
         $query->execute($units_built, $leftover_production, $$unit{id});
      }

      if($units_built)
      {
         sql_log($player_id, 'PRODUCTION', sprintf('Your factories have produced %d %s(s).', 
                             $units_built, $$unittype{name}));
      }

   }
}

sub hk_free_market_production
{
   #This functions goal is to produce units to purchase in the market based on
   #the number of factories in game and a preset %
   #Example: at 25% 4 player jeep factories creates 1 free market jeep
   
   my $production = $_[0];
   my $unittype   = $_[1];
   my $product    = $_[2];
   my $query;
   my $row;
   my $units_built;
   my $unit;
   my $leftover_production;
   
   $query = $SQL->prepare('SELECT id, build FROM unit WHERE player_id=0 AND unit_id=?');
   $query->execute($product);  
   
   $production = $production * 0.25;
   
    if(!$query->rows())
      {
         $units_built = int($production / $$unittype{cost});
         if ($$unittype{cost} >= 1) {
            $leftover_production = $production % $$unittype{cost};
         } else {
            $leftover_production = $production % 1;
         }
         $query = $SQL->prepare('INSERT INTO unit SET player_id=0, unit_id=?, amount=?, build=?');
         $query->execute($product, $units_built, $leftover_production);   
      }
      else
      {
         $unit = $query->fetchrow_hashref();
         $production += $$unit{build};

         $units_built = int($production / $$unittype{cost});
         if ($$unittype{cost} >=1) {
            $leftover_production = $production % $$unittype{cost};
         } else {
            $leftover_production = $production % 1;
         }
         $query = $SQL->prepare('UPDATE unit SET amount = amount + ?, build=? WHERE id=?');
         $query->execute($units_built, $leftover_production, $$unit{id});
      }
   
}

sub hk_factorybonus
{
   my $player_id =$_[0];
   my $query;
   my $row;
   
   $query = $SQL->prepare('select level from research where research_id=? and player_id=? and level=?');
   $query->execute("18",$player_id,"100");
   if($row = $query->fetchrow_hashref()){
        return (rand_range(.95,1) + $GAME_OPTIONS{factory_bonus});
   }
   return rand_range(.95,1);
}

sub hk_free_market
{
   my $query;
   my $row;
   my $market_query;
   my $units;
   my $id;
      #this query selects all ready units from player id 0 for integrating into the market
    $query = $SQL->prepare("SELECT unit.id,unit.amount,unit.unit_id,unittype.cost FROM unit,unittype WHERE unit.player_id='0' AND unittype.id=unit.unit_id AND unit.amount > 0");
    $query->execute();
    if ($query->rows()) {
       #add units to market
       while ($row = $query->fetchrow_hashref()) {
          $id = $$row{id};
          #select market units if they exist and add to them
          $market_query = $SQL->prepare("SELECT id,player_id,unit_id FROM market WHERE player_id=0 AND unit_id=?");
          $market_query->execute($$row{unit_id});
          if ($market_query->rows()) {
             #add to existing AI market
             $units = $$row{amount};
             $row = $market_query->fetchrow_hashref();
             $market_query = $SQL->prepare("UPDATE market SET amount = amount + ? WHERE id=?");
             $market_query->execute($units,$$row{id});
          } else {
             #Create new entry into market at base price
             $market_query = $SQL->prepare("INSERT INTO market SET player_id = 0, unit_id = ?,sell = ?, amount = ? ");
             if ($$row{cost} < 1) {
                $$row{cost} = 1;
             }
             $market_query->execute($$row{unit_id},($$row{cost} * 2 ),$$row{amount});
          }
          $market_query = $SQL->prepare("DELETE FROM unit WHERE id=?");
          $market_query->execute($id);
       }
   } 
   return;
}

sub hk_wage
{
   my $player_id = $_[0];

   my $query;
   my $row;
 
   my @troops;
   my $troop;
   
   my $player;

   my $wages;
   my $payment;
   my $left;
   my $x;


   $query = $SQL->prepare('SELECT unittype.wage, unit.id, unit.amount FROM unittype, unit ' . 
                          'WHERE unittype.id = unit.unit_id ' . 
                          'AND unit.player_id = ? ' .
                          'AND unittype.wage > 0 ' . 
                          'ORDER BY (unittype.attack + unittype.defense) DESC');
   $query->execute($player_id);

   while($row = $query->fetchrow_hashref())
   {
      push @troops, $row;
   }

   #get cash
   $query = $SQL->prepare('SELECT money FROM player WHERE id=?');
   $query->execute($player_id);
   $player = $query->fetchrow_hashref();

   #determine cost 
   foreach $troop (@troops)
   {
      $wages += $$troop{wage} * $$troop{amount};
   }

   return if $wages <= 0;

   $payment = $wages;

   if($wages > $$player{money})
   {
 
      foreach $troop (@troops)
      {

         $x = ($payment - $$player{money}) / $$troop{wage};

         #if x < 1 that means that we only need 1 of these units to complete!
         $x = 1 if $x < 1;

         #can't have fractional troops can we
         $x = int($x);
         
         #we need one more than this just to make sure we break under
         $x++;

         #all troops of this type gone!
         if($x >= $$troop{amount})
         {
            $payment -= $$troop{amount} * $$troop{wage};
            $left += $$troop{amount};
            $$troop{amount} = 0;
         }
         else
         {
            $payment -= $x * $$troop{wage};
            $left += $x;
            $$troop{amount} -= $x;
            last;
         }
        
      }
   }


   if($payment == $wages)
   {
      sql_log($player_id, 'GENERAL', sprintf('You have paid your troops $%d in wages.',$wages));
   }
   else
   {
      sql_log($player_id, 'GENERAL', sprintf('You could only afford to pay $%d of $%d in wages.',
                                      $payment, $wages));
      sql_log($player_id, 'GENERAL', sprintf('%d unpaid troops have abandoned your cause.',$left));


      foreach $troop (@troops)
      {
         $query = $SQL->prepare('UPDATE unit SET amount = ? WHERE id=?');
         $query->execute($$troop{amount}, $$troop{id});
      }

      $query = $SQL->prepare('UPDATE player SET farmers = farmers + ? WHERE id=?');
      $query->execute($left, $player_id);

      #do favor hit
      altfavor($player_id, ($left / sql_population($player_id)) * $FAVOR{nowage});
   }

   sql_money($player_id, -$payment);
}

sub hk_mp
{
   my $player_id = $_[0];
   my $query;
   my $row;
   
   my $mp;
   my $bank;
   
   $query = $SQL->prepare('SELECT mp, mp_bank FROM player WHERE id=?');
   $query->execute($player_id);
   $row = $query->fetchrow_hashref();
   
   $mp = $$row{mp};
   $bank = $$row{mp_bank};
   
   #do regular growth
   if(($mp + $GAME_OPTIONS{mp_growth}) <= $GAME_OPTIONS{mp_max})
   {
      $mp += $GAME_OPTIONS{mp_growth};
   }  
   else
   {
      $bank += $mp + $GAME_OPTIONS{mp_growth} - $GAME_OPTIONS{mp_max};
      $mp = $GAME_OPTIONS{mp_max};
   }

   #if we're still down, and have some bank, lets roll the bank into the regular 
   #this is my addition to eriks bulk mp, the bank is now bulked too - CrazySpence
   if($mp < $GAME_OPTIONS{mp_max} && $bank > 0)
   {
      if($bank >= $GAME_OPTIONS{bank_allocatemax}) {
            if(($mp + $GAME_OPTIONS{bank_allocatemax}) <= $GAME_OPTIONS{mp_max}) {
                 $mp += $GAME_OPTIONS{bank_allocatemax};
                 $bank -= $GAME_OPTIONS{bank_allocatemax};      
            } else {
                 $mp = $GAME_OPTIONS{mp_max};
                 $bank = $GAME_OPTIONS{bank_allocatemax} - ($GAME_OPTIONS{bank_allocatemax} + $mp - $GAME_OPTIONS{mp_max});
            }
      } else {
            if(($mp + $bank) <= $GAME_OPTIONS{mp_max}) {
                 $mp += $bank;
                 $bank = 0;
            } else {
                  $mp = $GAME_OPTIONS{mp_max};
                  $bank = $bank - ($bank + $mp - $GAME_OPTIONS{mp_max});     
            }
      }
  
   }

   $bank = $GAME_OPTIONS{mp_bankmax} if ($bank > $GAME_OPTIONS{mp_bankmax});

   $query = $SQL->prepare('UPDATE player SET mp = ?, mp_bank = ? WHERE id = ?');
   $query->execute($mp, $bank, $player_id);

   return;
}


sub hk_surrender
{
   my $player_id = $_[0];

   rem_flag($player_id, 'surrender');
}

sub hk_count
{
     #Hail CrazySpence
     #This function adds to the hk value in the player table
     #if it reaches or somehow gets higher than anarch_max establishing is forced
     my $id = $_[0];
     my $count;
     my $query;
     my $row;
     my $total;
     
     $query = $SQL->prepare('SELECT hk,government_id from player WHERE id=?');
     $query->execute($id);
     $row = $query->fetchrow_hashref();
     
     $query = $SQL->prepare('UPDATE player SET hk=(hk + 1) where id=?');
     $query->execute($id); #keep adding hk values for the hall of fame

     if($$row{government_id} != 1) {
          return;
     }
     if($$row{hk} >= $GAME_OPTIONS{anarch_max}) {
          if(has_flag($id, 'established')) {
               return;
          }
          $query = $SQL->prepare('UPDATE player SET government_id=? WHERE id=?');
          $query->execute($GTYPE{dictatorship}, $id);

          set_flag($id, 'established');

          global_msg(sprintf('In a struggle to control the balance of commerce, %s has been ' . 
                       'established under the control of %s.', 
              sql_getcountry($id), sql_gettitle($id) ));     
          return;
     }
}


sub do_ai
{
	#Hail to the king baby
	my $id = $_[0];
	my @ai;
	my $population;
	my $row;
	my $query;
	my $level;
	my $treecomplete = 0;
	my $amount = 0; 
	
	#set up AI variables
	if (has_flag($id,'medium')) {
		@ai = @AIMEDIUM;
	} elsif (has_flag($id,'hard')) {
		@ai = @AIHARD;
	} else {
		@ai = @AIEASY;
	}
	# First, make sure population is not going to overflow
	$query = $SQL->prepare('SELECT mp,land from player where id = ?');
	$query->execute($id);
	$population = sql_population($id);
	
	$row = $query->fetchrow_hashref();
	if (($population / $$row{land} * 100) > 95) {
		while ($$row{mp} >= 8 && ($population / $$row{land} * 100) > 95) {
			ai_explore($id);
			sql_mp($id,-8);
			$query = $SQL->prepare('SELECT mp,land from player where id = ?');
			$query->execute($id);
			$row = $query->fetchrow_hashref();
		}
	}
	
	#follow tech tree
	$query = $SQL->prepare('SELECT research_id FROM research WHERE allocation=100 AND player_id=?');
	$query->execute($id);
	if (!$query->rows()) {
		#No allocation, lets get on this biznatch!
		foreach $level (@ai) {
			if ($level == -1) {
				#techtree finished, this var makes sure no more labs are made and current are bulldozed
				$treecomplete = 1;
				last;
			}
			if ($level == 0) {
				last;
			}
			$query = $SQL->prepare('SELECT research_id FROM research WHERE level=100 AND research_id=? AND player_id=?');
			$query->execute($level,$id);
			if (!$query->rows()) {
				#no tech, allocate!
				$query = $SQL->prepare('INSERT INTO research SET allocation=?, player_id=?, research_id=?, level=0');
      				$query->execute(100, $id,$level);
				sql_mp($id,-1);
				last;
			}
		}
	}
	
	#balance scientists if less than labs
	if($treecomplete == 0) {
		$query = $SQL->prepare('SELECT scientists,farmers,mp,size, amount FROM player,structuretype,structure WHERE structuretype.id = 1 AND player.id = ? AND player_id = ?');
		$query->execute($id,$id);
		$row = $query->fetchrow_hashref();
		if(($$row{size} * $$row{amount} > $$row{scientists}) && ($$row{farmers} > (1000 + ($$row{size} * $$row{amount} - $$row{scientists}))) && ($$row{mp} >= 5)) {
			#fix the nerds lapse we are having
			$amount = $$row{size} * $$row{amount} - $$row{scientists};
			$query = $SQL->prepare('UPDATE player SET scientists = scientists + ?, farmers = farmers - ? WHERE id=?');
			$query->execute($amount,$amount, $id);
 			altfavor($id, ($amount / sql_population($id)) * $FAVOR{educategive});
			sql_mp($id,-5);
		}
	
		#Make sure a certain percentage of land is occupied by labs and scientists currently 20%, we will see how it works out

		$query = $SQL->prepare('SELECT land,money,mp,farmers,scientists from player where id = ?');
		$query->execute($id);
		$row = $query->fetchrow_hashref();
	
		if((($$row{scientists} / $$row{land} * 100) < 20 ) && ($$row{farmers} > 1000) && ( $$row{land} - sql_landuse($id) > 100)) {
			while (($$row{mp} >= 8) && ($$row{money} > 5000) && (($$row{scientists} / $$row{land} * 100) < 20) && ($$row{farmers} > 1000) && ($$row{land} - sql_landuse($id) > 100)) {
				#build type 1 lab, educate, take money and mp build is 3mp educate is 5 which equals 8!
				sql_build($id, 1, 1); 
  		        	sql_money($id, -5000);
				sql_mp($id,-8);
				$query = $SQL->prepare('UPDATE player ' . 
                          	'SET scientists = scientists + ?, farmers = farmers - ? WHERE id=?');
				$query->execute(100,100, $id);
 				altfavor($id, (100 / sql_population($id)) * $FAVOR{educategive});
				$query = $SQL->prepare('SELECT land,money,mp,farmers,scientists from player where id = ?');
				$query->execute($id);
				$row = $query->fetchrow_hashref();
			}
		}
	} else {
		#if the tech tree is done what the hell do we need these useless nerds for
		$query = $SQL->prepare('SELECT mp,amount,structure.id AS struc_id,structuretype.id,cost FROM player,structure,structuretype WHERE type=1 AND structure_id=structuretype.id AND player_id=?;');
		$query->execute($id);
		$row = $query->fetchrow_hashref();
  		if (($$row{amount} * 3) > $$row{mp}) {
			$$row{amount} =  $$row{mp} / 3;
			int($$row{amount});
		}
		$query = $SQL->prepare('UPDATE structure SET amount = amount - ? WHERE id=?');
  		$query->execute($$row{amount},$$row{struc_id});
  		sql_money($id, $$row{cost} / 2);
  		sql_balance_scientists($id);
	        sql_mp($id,-($$row{amount} * 3));
	}
	#balance workers if less than factories
	$query = $SQL->prepare('SELECT farmers,mp,structuretype.id,structure.id AS struc_id,structure_id,amount,size,(amount * size - workers) AS needed FROM structuretype,structure,player WHERE type = 2 AND structure_id=structuretype.id and player_id = ? AND player.id=?');
	$query->execute($id,$id);
	while ($row = $query->fetchrow_hashref()) {
		if(($$row{needed} > 0) && (($$row{farmers} - $$row{needed}) > 1000) && ($$row{mp} >= 3)) {
			#we're short workers and have the farmers
			sql_hire($id, $$row{struc_id}, $$row{needed});
   			#do a favor alt
   			$$row{farmers} = $$row{farmers} - $$row{needed};
			$$row{mp} = $$row{mp} - 3;
			altfavor($id, ($$row{needed} / sql_population($id)) * 75);
			sql_mp($id,-3);
		}
	}
	
	#build factories! w00t! This query will select the best technology available and build it this way in the early part of the game they'll build jeep factories later on they will build hummers and so on, even possibley a shuttle
	$query = $SQL->prepare('SELECT farmers,land,money,mp,research_id, structuretype.id, structuretype.size,structuretype.cost FROM player,research,structuretype WHERE player_id = ? AND prereq = research_id AND player.id = ? AND type = 2 AND research.level = 100 ORDER BY id DESC');
	$query->execute($id,$id);
	if ($query->rows()) {
		#Guess what this means?!!! We have the technology! All your base are belong to us!
		$row = $query->fetchrow_hashref();
		if (($$row{land} - $$row{size} > 1000) && ($$row{farmers} - $$row{size} > 1000 ) && ($$row{money} - $$row{cost} > 0 ) && ( $$row{mp} >= 6 ) && ($$row{land} - sql_landuse($id) > $$row{size})) {
			#Rome may have been built in a day but this factory will be built in about a 10th of a second
			sql_build($id, $$row{id}, 1); 
  		        #Bye bye money!
			sql_money($id, -($$row{cost}));
			#You're Hired!
   			$query = $SQL->prepare('SELECT structure.id FROM structure WHERE structure_id = ? and player_id=?');
			$query->execute($$row{id},$id);
			$amount = $$row{size};
			$row = $query->fetchrow_hashref();
			sql_hire($id, $$row{id}, $amount);
   			#do a favor alt
   			altfavor($id, ($amount / sql_population($id)) * 75);
			sql_mp($id,-6);
		}
	}

	#only check certain things if we are established!
	if(has_flag($id, 'established')) {
		$amount = 0;
		#Now we need some defenses, 5% of farmers, not population because farmers make the cash example:  5% 2k farmers is 100
		$query = $SQL->prepare('SELECT player.money,player.mp,player.farmers,unittype.id,unittype.wage,unittype.train,unittype.prereq,research.research_id,research.player_id,research.level FROM player,unittype,research WHERE unittype.train = ? AND research.research_id = prereq and research.player_id = ? AND player.id = ? AND research.level = 100 ORDER BY unittype.id DESC');
		$query->execute('true',$id,$id);
		if($query->rows()) {
			#We have the technology
		        $row = $query->fetchrow_hashref();
			if ($$row{mp} >= 3) {
				if ((($$row{farmers} * 0.05) * $$row{wage} * ai_unit_cost($id) * 12) < $$row{money}) {
					#5% is sustainable for 1 day, go with it
					$amount = ($$row{farmers} * 0.05);
				} elsif ((($$row{farmers} * 0.04) * $$row{wage} * ai_unit_cost($id) * 12) < $$row{money}) {
					#4%
				        $amount = ($$row{farmers} * 0.04);
				} elsif ((($$row{farmers} * 0.03) * $$row{wage} * ai_unit_cost($id) * 12) < $$row{money}) {
					#3%
					$amount = ($$row{farmers} * 0.03);
				} elsif ((($$row{farmers} * 0.02) * $$row{wage} * ai_unit_cost($id) * 12) < $$row{money}) {
					#2%
					$amount = ($$row{farmers} * 0.03);
				} elsif ((($$row{farmers} * 0.01) * $$row{wage} * ai_unit_cost($id) * 12) < $$row{money}) {
					#1%
					$amount = ($$row{farmers} * 0.01);
				}
				if ($amount > 0) {
					#Train the units!
					sql_unit($id, $$row{id}, $amount);
					#bye bye farmers! on that bus!
					$query = $SQL->prepare('UPDATE player SET farmers = farmers - ? WHERE id=?');
   					$query->execute($amount, $id);
					#pay the man jesus!
					sql_money($id, -($amount * $$row{wage}));
					#and finally, minus mp
					sql_mp($id,-3);
				}
			}
		}
		
	}
}

sub ai_unit_cost
{
	#this is part of the checking of whether we should hire more troops, it returns the monthly cost of the current contingent of units
	my $query;
	my $row;
	my $id = $_[0];
	my $total = 0;
	
	$query = $SQL->prepare('SELECT unittype.wage, unit.amount,(unit.amount * unittype.wage) AS total FROM unittype,unit WHERE unittype.train = ? AND unit.unit_id = unittype.id AND unit.player_id = ?');
	$query->execute('true',$id);
        while ($row = $query->fetchrow_hashref()) {
		$total = $total + $$row{total};
	}
	return $total;
}

sub ai_explore
{
   my $id   = $_[0];
   
   my $query;
   my $row;

   my $land;
   my $dice;

   $dice = rand(100);

   if($dice <= 50)
   {
      $land = 0;
   }
   elsif($dice <= 90)
   {
      $land = int rand_range(150,400);
   }
   elsif($dice <= 97)
   {
      $land = int rand_range(350,500);
   }
   else 
   {
      $land = int rand_range(500,750);
   }
  
   $query = $SQL->prepare('UPDATE player SET land = land + ? WHERE id = ?');
   $query->execute($land, $id);

   return 1;
}

sub do_ai_attack {
	#Hail to the king baby
	
	#I was not pointlessly rewriting alot of the attack code just for AI that would be wasteful, even thought he main AI function is
	# essentially hacked up versions of their human commands, this was not the way to go for attack because attack is so huge
	# so basically the AI use the human attack command, if a player attacks an AI and loses or draws the game ends up here and
	# a dice roll decides if the enemy should pay for their decision
	my $id = $_[0];
	my $enemy = $_[1];
	my @parv =  ('attack',$enemy);
	my $query;
	my $row;
	my $dice = int(rand 10 + 1);
	my %source;
	
	$query = $SQL->prepare('SELECT id,nick,land FROM player WHERE nick=?');
	$query->execute($enemy);
	$row = $query->fetchrow_hashref();
	
	#bully check
	if (bully($id,$$row{id},0)) {
		return 0;
	}
	
	$source{id} = $id;
	$query = $SQL->prepare('SELECT mp FROM player WHERE id=?');
	$query->execute($id);
	$row = $query->fetchrow_hashref();
	
	#mp check
	if ($$row{mp} < 25) {
		return 1;
	}
	
	#dice variables, based on AI difficulty, defaults to easy at the bottom which has 30% chance of strike back, hard has 70% chance, medium 50%...ish
	if(has_flag($id,'hard') && $dice >= 3) {
		cmd_attack(\@parv,\%source);
		sql_mp($id,-25);
	} elsif(has_flag($id,'medium') && $dice >= 5) {
		cmd_attack(\@parv,\%source);
		sql_mp($id,-25);
	} elsif ($dice >= 7) {
		cmd_attack(\@parv,\%source);
		sql_mp($id,-25);
	}
}

###########################################################################################
#                                HELPER FUNCTIONS                                         #
###########################################################################################

sub is_player #nickname
{
     #Does this player exist function, returns id
     my $nick  = $_[0];
     my $query;
     my $row;
     
     if ($nick) {
        $query = $SQL->prepare("SELECT player.id FROM player WHERE player.nick=? AND active=1");
        $query->execute($nick);
     
        $row = $query->fetchrow_hashref();
        if($row) {
           return $$row{id};
        }
     }
     return 0;
     
}

sub sql_bomb()
{
   my $source = $_[0];
   my $attacker_id = $_[1];
   my $defender_id = $_[2];
   my $dice;
   my $casualties;
   my $bomber_amount = sql_hasbombers($attacker_id);
   my $i;  
   my $query;
  
   if($bomber_amount > 5) { $bomber_amount = 5; } #as hilarious as letting someone with 50 bombers anihilate someone would be, I must think of balance!
   for($i = 0 ; $i < $bomber_amount ; $i++) {
      $dice = rand(1);
      if ($dice > .6 && $dice < .7) {
         $casualties = sql_bombcitizens($defender_id);
         player_msg(getsource($defender_id),"A Catastrophe!!! Bombs have struck a civilian town!");
         player_msg(getsource($defender_id),sprintf("There are %s reported dead at the site of the bombing",$casualties));
         player_msg($source,"Your pilots report successfully decimating a civilian town");
         global_msg(sprintf("The bombs begin to fall over %s",sql_getcountry($defender_id)));
         global_msg(sprintf("The people of %s are going about their lives completely unaware of what is coming....",sql_getcountry($defender_id)));
         global_msg("Suddenly everyone is engulfed in flames as the bombs strike a small town, those who survived this brutal strike live in fear forever.");  
         sql_log($defender_id,'DEFENSE',sprintf("A civilian town was bombed! %s farmers were killed",$casualties))
      } elsif ($dice > .7) {
         $casualties = sql_bombstructure($defender_id);
         if ($casualties > 0) {
            $casualties--;
            player_msg(getsource($defender_id),"Bombs strike and destroy one of your factories...");
            player_msg(getsource($defender_id),sprintf("%s workers are unaccounted for and presumed lost",$casualties));
            player_msg(getsource($defender_id),"Unemployed, the survivors emerge from the rubble to return to the fields");
            player_msg($source,"Your pilots report the successful bombing of an enemy structure!");
            global_msg(sprintf("%s's bomber flies over %s and begins to rain hell down upon it",sql_getcountry($attacker_id),sql_getcountry($defender_id)));
            global_msg(sprintf("The bombs explode fiercely and a building comes crashing down!"));
            sql_balance_workers($defender_id);
            sql_balance_scientists($defender_id);
            sql_log($defender_id,'DEFENSE',sprintf("A structure was bombed and destroyed! %s casualties reported",$casualties));
            #stats update
            $query = $SQL->prepare("UPDATE player_statistics SET bomb_structure = (bomb_structure + 1) WHERE player_id=?");
            $query->execute($attacker_id);
         }
         #stats update
         $query = $SQL->prepare("UPDATE player_statistics SET bomb_civillian = (bomb_civillian + ?) WHERE player_id=?");
         $query->execute($casualties,$attacker_id);
      } else {
        global_msg(sprintf("Thunder and lighting shakes the plane from side to side as they pass over %s",sql_getcountry($defender_id)));
        global_msg(sprintf("The plane is unable to lay down its fury today and returns to %s to refuel",sql_getcountry($attacker_id)));
      }
      
   }
}

sub sql_bomb_id() 
{
    #specific structure bombing
    my $source = $_[0];
    my $attacker_id = $_[1];
    my $defender_id = $_[2];
    my $bomb_id = $_[3];
    my $query;
    my $dice;
    my $row;
    my $casualties;
    my $bomber_amount = sql_hasbombers($attacker_id);
    my $i;

    if($bomber_amount > 5) { $bomber_amount = 5; } #as hilarious as letting someone with 50 bombers anihilate someone would be, I must think of balance!
    for($i = 0 ; $i < $bomber_amount ; $i++) {
       $dice = rand(1);
	if ($dice > .4) {
	   #Getting data for work casualties
          $query = $SQL->prepare('SELECT amount,workers FROM structure WHERE id=?');
          $query->execute($bomb_id);
          $row = $query->fetchrow_hashref();
          #calculate number of workers killed
          if ($$row{workers} > 0) {
             $casualties = int(($$row{workers} / $$row{amount}) * rand(.75));
          } else {
             $casualties = 0;
          }
          $query = $SQL->prepare('UPDATE structure SET amount = amount - 1, workers = workers - ? WHERE id=? ');
	   $query->execute($casualties,$bomb_id);
          #stats update
          $query = $SQL->prepare("UPDATE player_statistics SET bomb_civillian = (bomb_civillian + ?), bomb_structure=(bomb_structure + 1) WHERE player_id=?");
          $query->execute($casualties,$attacker_id);
          #output
          player_msg(getsource($defender_id),"Bombs strike and destroy one of your factories...");
          player_msg(getsource($defender_id),sprintf("%s workers are unaccounted for and presumed lost",$casualties));
          player_msg(getsource($defender_id),"Unemployed, the survivors emerge from the rubble to return to the fields");
          player_msg($source,"Your pilots report the successful bombing of an enemy structure!");
          global_msg(sprintf("%s's bomber flies over %s and begins to rain hell down upon it",sql_getcountry($attacker_id),sql_getcountry($defender_id)));
          global_msg(sprintf("The bombs explode fiercely and a building comes crashing down!"));
          sql_balance_workers($defender_id);
          sql_balance_scientists($defender_id);
          sql_log($defender_id,'DEFENSE',sprintf("A structure was bombed and destroyed! %s casualties reported.",$casualties));
	      if(($$row{amount} - 1)	== 0) { return; } #No negative numbers please!
	   } else {
	      global_msg(sprintf("Thunder and lighting shakes the plane from side to side as they pass over %s",sql_getcountry($defender_id)));
          global_msg(sprintf("The plane is unable to lay down its fury today and returns to %s to refuel",sql_getcountry($attacker_id)));
       }
    }
}

sub sql_bombcitizens()
{
   my $player_id = $_[0];
   my $query;
   my $row;
   my $killed;
   
   $query = $SQL->prepare("SELECT farmers FROM player WHERE id=?");
   $query->execute($player_id);
   
   if ($row = $query->fetchrow_hashref()) {
      $killed = int($$row{farmers} * rand_range(0.05, 0.1 ));
      $query = $SQL->prepare("UPDATE player SET farmers=? WHERE id=?");
      $query->execute(($$row{farmers} - $killed),$player_id);

      $query = $SQL->prepare("UPDATE player_statistics SET civillian_lost = (civillian_lost + ?) WHERE player_id=?");
      $query->execute($killed,$player_id);
      return $killed;
   }
   return 0;
}

sub sql_bombstructure()
{
   #After losing the air battle if any bombers are left and they succeed in hitting a target select a building and remove it
   my $player_id = $_[0];
   my $query;
   my $row;
   my $total_structures;
   my $counter;
   my $dice;
   my @structures;
   my $structure;
   my $i;
   my $casualties;   

   $query = $SQL->prepare('SELECT structuretype.size, structure.amount, structure.id, structure.workers ' . 
                          'FROM structuretype, structure ' . 
                          'WHERE structuretype.id = structure.structure_id ' . 
                          'AND structure.player_id=? AND structuretype.size > 0 AND structure.amount > 0');

   $query->execute($player_id);

   #store each structure in @structures array
   while($row = $query->fetchrow_hashref())
   {
      push @structures, $row;
      $total_structures += $$row{amount};
   }
   
   if ($total_structures == 0) {
      return 0;
   }
   
   $counter = 0;
   $dice = rand(1); 

   #choose a random structure
   for($i = 0; $i < @structures; $i++)
   {
      $structure = $structures[$i];
      last if((($counter += $$structure{amount}) / $total_structures) >= $dice);
   }

   #calculate number of workers killed
   if($$structure{workers} > 0) {
      $casualties = int(($$structure{workers} / $$structure{amount}) * rand(.75));
      $$structure{workers} = $$structure{workers} - $casualties;
   } else {
      $casualties = 0;
   }
   $$structure{amount}--;
   $total_structures--;
   
   foreach $structure (@structures)
   {
      $query = $SQL->prepare('UPDATE structure SET amount = ? ,workers = ? WHERE id=?');
      $query->execute($$structure{amount}, $$structure{workers},$$structure{id});
   }
   
   $query = $SQL->prepare("UPDATE player_statistics SET civillian_lost = (civillian_lost + ?) WHERE player_id=?");
   $query->execute($casualties,$player_id);
   return (1 + $casualties);
}

sub sql_airforce()
{
   my $id = $_[0];
   my $query;
   my $row;
   my $table = new Text::ASCIITable;

   my $unit;
   my $switch = 0;

   $query = $SQL->prepare('SELECT unittype.name, unittype.attack, unittype.defense, ' . 
                          'unit.amount FROM unittype, unit ' . 
                          'WHERE unittype.id = unit.unit_id AND unit.player_id=? ' . 
                          'AND unittype.type = ? AND unit.amount > 0 ' . 
                          'ORDER BY unittype.attack, unittype.defense DESC');
   $query->execute($id, $UTYPE{air});

   return if(!$query->rows());
 
   $table->setCols(['Type', 'Amount', 'Stats']);

   while($row = $query->fetchrow_hashref())
   {
        $table->addRow($$row{name}, $$row{amount}, sprintf('(%d, %d)', $$row{attack}, $$row{defense}));
   }

   return $table->draw();
}

sub sql_hasbombers()
{
   my $player_id = $_[0];
   
   my $query;
   my $row; 
   
   $query = $SQL->prepare("SELECT unittype.id, unit.amount FROM unittype,unit WHERE unittype.name='bomber' AND unit.unit_id=unittype.id AND unit.player_id=?");
   $query->execute($player_id);
   
   if ($row = $query->fetchrow_hashref()) {
      return $$row{amount};
   }
   
   return 0;
}

sub sql_population
{

   my $player_id = $_[0];
  
   my $query;
   my $row;

   my $population;

   $query = $SQL->prepare('SELECT farmers,scientists FROM player WHERE id=?');
   $query->execute($player_id);
   $row = $query->fetchrow_hashref();

   $population += $$row{farmers} + $$row{scientists};

   $query = $SQL->prepare('SELECT sum(structure.workers) AS workers FROM structure WHERE player_id=?');
   $query->execute($player_id);
   $row = $query->fetchrow_hashref();
   
   $population += $$row{workers};

   $query = $SQL->prepare('SELECT sum(unit.amount) AS troops FROM unit, unittype ' .  
                          'WHERE unit.player_id=? AND unit.unit_id = unittype.id AND unittype.train=\'true\'');
   $query->execute($player_id);
   $row = $query->fetchrow_hashref();
   $population += $$row{troops};

   return $population;
}

sub sql_has_research()#$player_id, $research_id
{
   my $player_id = $_[0];
   my $research_id = $_[1];

   my $query;
   my $row;

   return 1 if $research_id == 0;

   $query = $SQL->prepare('SELECT level FROM research WHERE research_id=? AND player_id=?');
   $query->execute($research_id, $player_id);

   return 0 if(!$query->rows());
   
   $row = $query->fetchrow_hashref();

   return 1 if($$row{level} == 100);

   return 0;
}

sub sql_landuse  #$player_id, $type
{
   my $player_id = $_[0];
   my $type = $_[1];

   my $query;
   my $row;

   if($type)
   {
      $query = $SQL->prepare('SELECT sum(structuretype.size * structure.amount) AS landuse ' .
                             'FROM structuretype, structure ' .
                             'WHERE structure.structure_id = structuretype.id AND structure.player_id=? ' .
                             'AND structuretype.type = ?'
                             );
      $query->execute($player_id, $type);
   }
   else
   {
      $query = $SQL->prepare('SELECT sum(structuretype.size * structure.amount) AS landuse ' .
                             'FROM structuretype, structure ' .
                             'WHERE structure.structure_id = structuretype.id AND structure.player_id=?' 
                             );
      $query->execute($player_id);
   }

   return 0 if !$query->rows();

   $row = $query->fetchrow_hashref();

   return $$row{landuse};
}

sub sql_build() #$player_id, $structure, $amount
{
   my $player_id = $_[0];
   my $structure = $_[1];
   my $amount = $_[2];

   my $query;
   my $row;

   #check if structure row already exists
   $query = $SQL->prepare('SELECT id ' .
                          'FROM structure ' .
                          'WHERE structure_id=? AND player_id=?');
   $query->execute($structure, $player_id);
 
   if($query->rows())
   {
      $row = $query->fetchrow_hashref();
      $query = $SQL->prepare('UPDATE structure SET amount = amount + ? WHERE structure.id = ?');
      $query->execute($amount, $$row{id});
   } 
   else
   {
      $query = $SQL->prepare('INSERT INTO structure SET player_id=?, structure_id=?, amount=?');
      $query->execute($player_id, $structure, $amount);
   }
}

sub sql_money #$player_id, $change
{
   my $player_id = $_[0];
   my $change = $_[1];

   my $query;
  
   $query = $SQL->prepare('UPDATE player SET money = money + ? WHERE player.id = ?');
   $query->execute($change, $player_id);
}

sub sql_mp #$player_id, $change
{
   my $player_id = $_[0];
   my $change = $_[1];

   my $query;

   $query = $SQL->prepare('UPDATE player SET mp = mp + ? WHERE id=?');
   $query->execute($change, $player_id);
}

sub sql_hire #$player_id, $building id, $amount
{
   my $player_id = $_[0];
   my $building = $_[1];
   my $amount = $_[2];

   my $query;

   $query = $SQL->prepare('UPDATE structure SET workers = workers + ? WHERE id=? AND player_id=?');
   $query->execute($amount, $building, $player_id);

   $query = $SQL->prepare('UPDATE player SET farmers = farmers - ? WHERE id=?');
   $query->execute($amount, $player_id);
}

sub sql_unit #$player_id, $type, $amount
{
 
   my $player_id = $_[0];
   my $type = $_[1];
   my $amount = $_[2];

   my $query;
   my $row;

   $query = $SQL->prepare('SELECT id FROM unit WHERE unit_id=? AND player_id=?');
   $query->execute($type, $player_id);
   
   if($query->rows())
   {
      $row = $query->fetchrow_hashref();
      $query = $SQL->prepare('UPDATE unit SET amount = amount + ? WHERE id=?');
      $query->execute($amount, $$row{id});
   }
   else
   {
      $query = $SQL->prepare('INSERT INTO unit SET amount=?, player_id=?, unit_id=?');
      $query->execute($amount, $player_id, $type);
   }
}

sub sql_log #$player_id, $text
{
   my $player_id = $_[0];
   my $type = $_[1];
   my $text = $_[2];

   my $query;

   $query = $SQL->prepare('INSERT INTO log SET player_id=?, type=?, text=?, time=NOW()');
   $query->execute($player_id, $type, $text);
}

sub sql_military()
{
   my $id = $_[0];
   my $query;
   my $row;
   my $table = new Text::ASCIITable;

   my $unit;
   my $switch = 0;

   $query = $SQL->prepare('SELECT unittype.name, unittype.attack, unittype.defense, ' . 
                          'unit.amount FROM unittype, unit ' . 
                          'WHERE unittype.id = unit.unit_id AND unit.player_id=? ' . 
                          'AND unittype.type = ? AND unit.amount > 0 ' . 
                          'ORDER BY unittype.attack, unittype.defense DESC');
   $query->execute($id, $UTYPE{ground});

   return if(!$query->rows());
 
   $table->setCols(['Type', 'Amount', 'Stats']);

   while($row = $query->fetchrow_hashref())
   {
        $table->addRow($$row{name}, $$row{amount}, sprintf('(%d, %d)', $$row{attack}, $$row{defense}));
   }

   return $table->draw();
}

sub sql_pillage
{
   my $source = $_[0]; #attacker source
   my $attacker_id = $_[1];
   my $defender_id = $_[2];
   my $defender_surrender = $_[3]; #This value can be modified in the case of retaliation
   my $defenderland;
   my $query;
   my $row;

   my $structures_lost;

   $query = $SQL->prepare('SELECT money, land, farmers, scientists FROM player WHERE id=?');
   $query->execute($defender_id);


   $row = $query->fetchrow_hashref();
   $defenderland = $$row{land};
   
   #take between 65-100% of surrender amount 
   $$row{money}      = int ($$row{money}      * $defender_surrender * rand_range(.65,1));
   $$row{land}       = int ($$row{land}       * $defender_surrender * rand_range(.65,1));
   $$row{farmers}    = int ($$row{farmers}    * $defender_surrender * rand_range(.65,1));
   $$row{scientists} = int ($$row{scientists} * $defender_surrender * rand_range(.65,1));

      
   #take from defender
    
   $query = $SQL->prepare('UPDATE player SET money = money - ?, scientists = scientists - ?, ' . 
                             'farmers = farmers - ?, land = land - ? ' . 
                             'WHERE id=?');
   $query->execute($$row{money}, $$row{scientists}, $$row{farmers}, $$row{land}, $defender_id);
   
   #give to attacker
   $query = $SQL->prepare('UPDATE player SET money = money + ?, scientists = scientists + ?, ' . 
                          'farmers = farmers + ?, land = land + ? ' .
                          'WHERE id=?');
   $query->execute($$row{money}, $$row{scientists}, $$row{farmers}, $$row{land}, $attacker_id);

   #announce it
   sql_log($defender_id, 'DEFENSE', sprintf('Your loses include $%d, %d land, %d farmers and %d scientists.',
                         $$row{money}, $$row{land}, $$row{farmers}, $$row{scientists}));
   player_msg($source, sprintf('In your victory you pillage $%d, capture %d land, liberate %d farmers ' . 
                            'and win the hearts of %d scientists.', 
                          $$row{money}, $$row{land}, $$row{farmers}, $$row{scientists}));

   #balance out the structures
   if(($structures_lost = sql_balance_structures($defender_id)) > 0)
   {
      player_msg($source, sprintf('You have destroyed %d enemy structures!', $structures_lost));
      sql_log($defender_id, 'DEFENSE', sprintf('You have lost %d structures!', $structures_lost));
   }

   sql_balance_workers($defender_id);
   sql_balance_scientists($defender_id);
   sql_balance_scientists($attacker_id);
   #checks to see if this kills you - moved by CrazySpence twice!
   if(($defenderland - $$row{land}) < $GAME_OPTIONS{minland})
   {
      sql_death($attacker_id, $defender_id);
   }
}


sub sql_balance_player ()
{
   #The events sub system could cause a player to go into negative farmers, scientists or Money this function will set any negative values to 0
   my $player_id = $_[0];

   my $query;
   my $row;

   $query = $SQL->prepare("SELECT farmers,money,scientists FROM player WHERE id=?");
   $query->execute($player_id);

   $row = $query->fetchrow_hashref();
   
   if ($$row{money} < 0) {
      $query = $SQL->prepare("UPDATE player SET money=0 WHERE id=?");
      $query->execute($player_id);
   }
   if ($$row{farmers} < 0) {
      $query = $SQL->prepare("UPDATE player SET farmers=0 WHERE id=?");
      $query->execute($player_id);
   }
   if ($$row{scientists} < 0) {
      $query = $SQL->prepare("UPDATE player SET scientists=0 WHERE id=?");
      $query->execute($player_id);
   }
}

sub sql_balance_structures ()
{
   my $player_id = $_[0];

   my $query;
   my $row;
   
   my $total_land;
   my $total_land_use;
   my $total_structures;

   my @structures;
   my $structure;

   my $dice;
   my $counter;
   my $i; 
   my $lost;


   #get their total land
   $query = $SQL->prepare('SELECT land FROM player WHERE id=?');
   $query->execute($player_id);
   $row = $query->fetchrow_hashref();
   $total_land = $$row{land};

   #get their land use
   $total_land_use = sql_landuse($player_id, 0);

   #check if land use is greater than total land
   if($total_land_use <= $total_land)
   {
      #no balancing needed
      return 0;
   }

   #okay at this point we need to balance structures now, so lets get a list
   #of all structures this player has

   $query = $SQL->prepare('SELECT structuretype.size, structure.amount, structure.id ' . 
                          'FROM structuretype, structure ' . 
                          'WHERE structuretype.id = structure.structure_id ' . 
                          'AND structure.player_id=? AND structuretype.size > 0 AND structure.amount > 0');

   $query->execute($player_id);

   #store each structure in @structures array
   while($row = $query->fetchrow_hashref())
   {
      push @structures, $row;
      $total_structures += $$row{amount};
   }

   while($total_land_use >= $total_land && $total_structures > 0)
   {
      $counter = 0;
      $dice = rand(1); 

      #choose a random structure
      for($i = 0; $i < @structures; $i++)
      {
         $structure = $structures[$i];
         last if((($counter += $$structure{amount}) / $total_structures) >= $dice);
      }

      $total_land_use -= $$structure{size};
      $$structure{amount}--;
      $total_structures--;
      $lost++; 
   }

   foreach $structure (@structures)
   {
      $query = $SQL->prepare('UPDATE structure SET amount = ? WHERE id=?');
      $query->execute($$structure{amount}, $$structure{id});
   }

   return $lost;   
}

sub sql_balance_workers
{
   my $player_id = $_[0];

   my $query;
   my $query2;
   my $row;

   my $workers;
   my $capacity;

   $query = $SQL->prepare('SELECT structuretype.size, structure.amount, structure.id, structure.workers ' .
                          'FROM structuretype, structure ' .
                          'WHERE structuretype.id = structure.structure_id AND structure.player_id=?');

   $query->execute($player_id);

   while($row = $query->fetchrow_hashref())
   {
      $workers = $$row{workers};
      $capacity = $$row{size} * $$row{amount};

      if($workers > $capacity)
      {
         $query2 = $SQL->prepare('UPDATE structure SET workers=? WHERE id=?');
         $query2->execute($capacity, $$row{id});

         $query2 = $SQL->prepare('UPDATE player SET farmers = farmers + ? WHERE id=?');
         $query2->execute($workers - $capacity, $player_id);

         #same favor alt as firing
        altfavor($player_id, ($workers / sql_population($player_id)) * $FAVOR{hiretake});
      }
   }
}

sub sql_balance_scientists
{
   my $player_id = $_[0];

   my $query;
   my $row;

   my $capacity;

   $capacity = sql_landuse($player_id, $STYPE{lab});

   $query = $SQL->prepare('SELECT scientists FROM player WHERE id=?');
   $query->execute($player_id);
   $row = $query->fetchrow_hashref();

   if($$row{scientists} > $capacity)
   {
      $query = $SQL->prepare('UPDATE player SET scientists=?, farmers = farmers + ? WHERE id=?');
      $query->execute($capacity, $$row{scientists} - $capacity, $player_id);
      
      #same favor alt as educate
      altfavor($player_id, ((($$row{scientists} - $capacity) / sql_population($player_id)) * $FAVOR{educatetake}) );
   }
}

sub sql_death ()
{
   my $attacker_id = $_[0];
   my $defender_id = $_[1];

   my $attacker_source = getsource($attacker_id);
   my $defender_source = getsource($defender_id);

   my $query;

   global_msg(sprintf('The forces of %s are able to quickly scout and secure ' . 
                       'the remaining soil of %s.', 
                      sql_gettitle($attacker_id), sql_gettitlecountry($defender_id)));

   global_msg(sprintf('The nation of %s, commanded by %s, has fallen.', 
                       sql_getcountry($defender_id), sql_gettitle($defender_id)));

   if($defender_source) {
      player_msg($defender_source, 'Your nation has fallen. Issue the command \'NEWPLAYER\' to start a new player.');
      unregister_player($defender_id);  
   }
   sql_add_achievement($defender_id,"He's dead Jim");
   sql_delete($defender_id); 
}

sub sql_evildead
{
	#When someoen gets -99 favour the next hk they end up here
	
	my $player = $_[0];
	my $source;
	my $query;
	my $evildead;
	
	$query = $SQL->prepare('SELECT nick FROM player WHERE id=?');
       $query->execute($player);
       $evildead = $query->fetchrow_hashref();
	global_msg(sprintf('The nation of %s has become weary of %s and their evil ways...',sql_getcountry($player),sql_gettitle($player)));
	global_msg('A group of freedom fighters sneaks into the bed chambers and beheads the evil Tyrant!');
	global_msg(sprintf('The nation of %s, commanded by %s, has fallen.',sql_getcountry($player), sql_gettitle($player)));
	if($source = getsource($player)) {
        player_msg($source, 'Your nation has fallen. Issue the command \'NEWPLAYER\' to start a new player.');
		unregister_player($player);
      }
      sql_add_achievement($player,"Citizen uprising");
      sql_delete($player);
}

sub sql_delete
{
   my $player_id = $_[0];
   
   my $query;

   $query = $SQL->prepare('DELETE FROM log WHERE player_id=?');
   $query->execute($player_id);

   $query = $SQL->prepare('DELETE FROM unit WHERE player_id=?');
   $query->execute($player_id);

   $query = $SQL->prepare('DELETE FROM structure WHERE player_id=?');
   $query->execute($player_id);

   $query = $SQL->prepare('DELETE FROM research WHERE player_id=?');
   $query->execute($player_id);

   $query = $SQL->prepare('DELETE FROM space WHERE player_id=?');
   $query->execute($player_id);

   $query = $SQL->prepare('DELETE FROM market WHERE player_id=?');
   $query->execute($player_id);

   $query = $SQL->prepare('DELETE FROM mail WHERE player_id=?');
   $query->execute($player_id);

   $query = $SQL->prepare('DELETE FROM sessions WHERE nick=?');
   $query->execute(sql_getnick($player_id));

   #Now that accounts are static instead of deleteing set to inactive and restore default values
   $query = $SQL->prepare('UPDATE player set active=0, land=1100, farmers=1000, money=15000, tax=7, surrender=20, scientists=0,favor=0,government_id=1,hk=0,mp=75,mp_bank=0,took_quest=0 WHERE id=?');
   $query->execute($player_id);
   
   #reset per round stats, leave Game/Quest wins
   if(!has_flag($player_id,"ai"))
   {
      $query = $SQL->prepare('UPDATE player_statistics SET killed=0,died=0,launched=0,downed=0,bomb_structure=0,bomb_civillian=0,civillian_lost=0,quest_pk=0,quest_complete=0 WHERE player_id=?');
      $query->execute($player_id);
   }
   rem_flag($player_id,'established');
   rem_flag($player_id,'quest');
   rem_flag($player_id,'surrender');
   set_flag($player_id,'unstablished');

}

sub sql_add_retaliation
{
   #add player to the defenders retaliation table
   my $defender = $_[0]; #the player
   my $attacker = $_[1];
   my $query;
   my $row;

   $query = $SQL->prepare('SELECT attacks FROM retaliation WHERE player_id=? AND attacker_id=?');
   $query->execute($defender,$attacker);

   if(!$query->rows()) {
      $query = $SQL->prepare('INSERT INTO retaliation SET player_id=?, attacker_id=?, attacked=1,attacks=0');
      $query->execute($defender,$attacker);
   } else {
      $query = $SQL->prepare('UPDATE retaliation SET attacked=(attacked + 1) WHERE player_id=? AND attacker_id=?');
      $query->execute($defender,$attacker);
   }
}

sub sql_retaliation
{
   #check if there are any retaliations against the defender
   my $defender = $_[1];
   my $attacker = $_[0]; #the player
   my $query;
   my $row;

   $query = $SQL->prepare('SELECT attacked, attacks FROM retaliation WHERE player_id=? AND attacker_id=?');
   $query->execute($attacker,$defender);

   if (!$query->rows()) { return 0; }
   
   $row = $query->fetchrow_hashref();
   if($$row{attacked} - $$row{attacks} > 0) { return 1; }
   
   return 0; 
}

sub sql_retaliated
{
   my $defender = $_[1];
   my $attacker = $_[0]; #the player
   my $query;
   
   $query = $SQL->prepare('UPDATE retaliation SET attacks=(attacks + 1) WHERE player_id=? AND attacker_id=?');
   $query->execute($attacker,$defender);
   #sprintf('UPDATE retaliation SET attacks=(attacks + 1) WHERE player_id=%s AND attacker_id=%s',$attacker,$defender);
   return;	
}

sub sql_has_achievement #$player, $achievement
{
   my $player =      $_[0];
   my $achievement = $_[1];
   my $query;

   $query = $SQL->prepare('SELECT achievementtype.id, achievement.player_id FROM achievementtype,achievement WHERE achievementtype.name=? AND achievement.achievement_id=achievementtype.id AND achievement.player_id=?');
   $query->execute($achievement,$player);

   if($query->rows()) {
      return 1;
   }
   
   return 0;
}

sub sql_add_achievement #$player, $achievement
{
   my $player = $_[0];
   my $achievement = $_[1];
   my $query;
   my $row;
   my $achievement_id;

   if(sql_has_achievement($player,$achievement)) {
      return;
   }
   
   #get the ID from the name (I do this by names incase the row id's were evr to change)
   $query = $SQL->prepare("SELECT id FROM achievementtype WHERE name=?");
   $query->execute($achievement);

   if(!$query->rows()) {
      return;
   }
   
   $row = $query->fetchrow_hashref();
   $achievement_id = $$row{id};
   
   #Add to achievement table
   $query = $SQL->prepare("INSERT INTO achievement SET player_id=?, achievement_id=?");
   $query->execute($player,$achievement_id);

   global_msg(sprintf("%s of %s has gained the \"%s\" achievement!",sql_gettitle($player),sql_getcountry($player),$achievement));
   sql_log($player,'ACHIEVEMENT',$achievement);
   return;
}

sub has_flag 
{
   my $player_id = $_[0];
   my $flag = $_[1];

   my $query;
   my $row;

   $query = $SQL->prepare('SELECT id FROM player WHERE id=? AND FIND_IN_SET(?, flags) > 0');
   $query->execute($player_id, $flag);

   return 0 if(!($row=$query->fetchrow_hashref()));

   if($$row{id})
   {
      return 1;
   }
   else
   {
      return 0;
   }
}

sub set_flag
{
   my $player_id = $_[0];
   my $flag = $_[1];

   my $query;

   return if(has_flag($player_id, $flag));

   $query = $SQL->prepare('UPDATE player SET flags=CONCAT(flags, ?) WHERE id=?');
   $query->execute(sprintf(',%s',$flag), $player_id);
}

sub rem_flag
{
   my $player_id = $_[0];
   my $flag = $_[1];
   my $query;

   $query = $SQL->prepare('UPDATE player SET flags=replace(flags, ?, "") WHERE id=?');
   $query->execute($flag, $player_id);
}

sub sql_gettitle
{
   my $player_id = $_[0];
   
   my $query;
   my $row;

   $query = $SQL->prepare('SELECT government.title, player.nick FROM government, player ' . 
                          'WHERE government.id = player.government_id AND player.id=?');
   $query->execute($player_id);
   $row = $query->fetchrow_hashref();

   return sprintf('%s %s', $$row{title}, $$row{nick});
}

sub sql_getnick
{
   my $player_id = $_[0];

   my $query;
   my $row;

   $query = $SQL->prepare('SELECT nick FROM player WHERE id=?');
   $query->execute($player_id);
   $row = $query->fetchrow_hashref();

   return $$row{nick};
}


sub sql_getcountry
{
   my $player_id = $_[0];

   my $query;
   my $row;

   $query = $SQL->prepare('SELECT country FROM player WHERE id=?');

   $query->execute($player_id);
   $row = $query->fetchrow_hashref();

   return sprintf($$row{country});
}

sub sql_gettitlecountry
{
   my $player_id = $_[0];

   return sprintf('%s of %s', sql_gettitle($player_id), sql_getcountry($player_id));
}

sub sql_global
{
    my $query;
    my $row;
    my @results;
    
    $query = $SQL->prepare("SELECT text FROM log WHERE type='GLOBAL' ORDER BY time DESC, id ASC LIMIT 10");
    $query->execute();
    
    if ($query->rows()) {
         while ($row = $query->fetchrow_hashref()){
             push @results, $$row{text};     
         }
    }
    return @results;
}

sub sql_session
{
   #Check for session in Database if it exists the session is legit
   my $session = $_[0];
   my $query;
   my $row;
   my $id;

   $query = $SQL->prepare("SELECT nick FROM sessions WHERE sessid=?");
   $query->execute($session);
   
   if($query->rows()) 
   {
      $row = $query->fetchrow_hashref();
      $id = is_player($$row{nick});
      #Legacy Check for older players to ensure a statistics row exists
      $query = $SQL->prepare("SELECT * FROM player_statistics WHERE player_id=?");
      $query->execute($id);

      if(!$query->rows())
      {
         $query = $SQL->prepare("INSERT INTO player_statistics SET player_id=?,killed='0',died='0',launched='0',downed='0',wins='0'");
         $query->execute($id);
      }

      return $$row{nick};
   }
   return;
}

sub sql_session_nick
{
   #Check for session in Database if it exists the session is legit
   my $session = $_[0];
   my $query;
   my $row;
   my $id;

   $query = $SQL->prepare("SELECT sessid FROM sessions WHERE nick=?");
   $query->execute($session);
 
   if($query->rows()) 
   {
      $row = $query->fetchrow_hashref();
      return $$row{sessid};
   }
   return 0;
}


sub sql_global_sessionlog
{
   my $data = $_[0];
   my $query;
   my $insert;
   my $row;

   $query = $SQL->prepare("SELECT DISTINCT nickname FROM session_log");
   $query->execute();

   if(!$query->rows()) {
      return;
   }
   while ($row = $query->fetchrow_hashref())
   {
      $insert = $SQL->prepare("INSERT INTO session_log SET nickname=?,data=?");
      $insert->execute($$row{nickname},sprintf("Doomsday: %s\n",$data));
   }
}

sub sql_sessionlog
{
   #add outgoing text to a session database
   my $nickname = $_[0];
   my $data     = $_[1];
   my $query;

   $query = $SQL->prepare("INSERT INTO session_log SET nickname=?, data=?");
   $query->execute($nickname,$data);
}

sub sql_quest_state
{
   my $source = $_[0];
   my $query;
   my $row;

   if(has_flag($$source{id}, 'quest')) {
      #Get state from database for legacy clients
      $query = $SQL->prepare("SELECT x,y FROM quest_state WHERE player_id=?");
      $query->execute($$source{id});
      if($query->rows()) {
         $row = $query->fetchrow_hashref();
         $$source{xcords} = $$row{x};
         $$source{ycords} = $$row{y};
      }
   }
}

sub rand_range()
{
   my $min = $_[0];
   my $max = $_[1];

   return rand($max - $min) + $min;
}

sub mailbox()
{
   my $source = $_[0];
   my $query;
   my $row;
   my $mail;
   
   $query = $SQL->prepare("SELECT count(mail.read) AS inbox FROM mail WHERE player_id=? AND mail.read=?");
   $query->execute($$source{id},"0");
   
   if($query->rows())
   {   
      $row = $query->fetchrow_hashref();
      $mail = $$row{inbox};
      return $mail;
   }
   
   return 0;
}

#####################################################################################
#                                  FAVOR FUNCTIONS                                  #
#####################################################################################

sub altfavor
{
   my $player_id = $_[0];
   my $amount = $_[1] * $FAVOR{base};

   my $query;
   my $favor;
   my $row;

   #convert to 0-10,000
   $query = $SQL->prepare('SELECT favor FROM player WHERE id=?');
   $query->execute($player_id);
   $row = $query->fetchrow_hashref();

   $favor = $$row{favor};

   if(abs($favor) >= 25)
   {
      $favor += $amount / (abs($favor) ** $FAVOR{weight});
   }
   else
   {
      $favor += $amount / (25 ** $FAVOR{weight});
   }

   $favor = 100 if($favor > 100);
   $favor = -100 if($favor < -100);

   $query = $SQL->prepare('UPDATE player SET favor=? WHERE id=? AND active=1'); #added the active part to stop post mortem favour changes
   $query->execute($favor, $player_id);
}

sub favor
{
   my $player_id = $_[0];

   my $query;
   my $row;

   $query = $SQL->prepare('SELECT favor, government_id FROM player WHERE id=?');
   $query->execute($player_id);
   
   $row = $query->fetchrow_hashref();

   if($$row{government_id} == $GTYPE{anarchy})
   {
      return -50;
   }
   else
   {
      return $$row{favor};
   }
   return 0; #*shrugs* gotta return something
}

sub pfavor
{
   my $player_id = $_[0];
 
   return favor($player_id) * .01;
}


# bully
#
# Determine if attacker is a bully of defender.
#
# If third argument is true, give attacker a favor
# hit.

sub bully
{
   my %attacker;
   my %defender;

  $attacker{id} = $_[0];
  $defender{id} = $_[1];
   my $favor    = $_[2];

   my $query;
   my $row;
   my $relsize;

   #fetch information on attacker
   $query = $SQL->prepare('SELECT land FROM player WHERE id=?');
   $query->execute($attacker{id});
   $row = $query->fetchrow_hashref();

   $attacker{land} = $$row{land};

   #fetch information on defender
   $query = $SQL->prepare('SELECT land FROM player WHERE id=?');
   $query->execute($defender{id});
   $row = $query->fetchrow_hashref();

   $defender{land} = $$row{land};

   if($attacker{land} <= $defender{land})
   {
      return 0;
   }

   if(abs($attacker{land} - $defender{land}) < $GAME_OPTIONS{bullysep})
   {
      return 0;
   }
 
   #calculate attacker's relative size to defender, it should be > 1
   $relsize = $attacker{land} / $defender{land};

   #if attacker is bully x > defender, it's considered a bully
   if($relsize >= $GAME_OPTIONS{bully})
   {
      if($favor == 1)
      {
         if (!sql_retaliation($attacker{id},$defender{id})) {
            $favor = $FAVOR{bully} * $relsize;
            $favor = $FAVOR{bullymax} if abs($favor) > abs($FAVOR{bullymax});
            altfavor($attacker{id}, $favor);
         }
      }

      return 1;
   }

   return 0;
}

# antibully
#
# Determine if defender gains favor by attacking attacker
#
# If third argument is true, give attacker a favor
# increase.

sub antibully
{
   my %attacker;
   my %defender;

  $attacker{id} = $_[0];
  $defender{id} = $_[1];
   my $favor    = $_[2];

   my $query;
   my $row;
   my $relsize;

   #fetch information on attacker
   $query = $SQL->prepare('SELECT land FROM player WHERE id=?');
   $query->execute($attacker{id});
   $row = $query->fetchrow_hashref();

   $attacker{land} = $$row{land};

   #fetch information on defender
   $query = $SQL->prepare('SELECT land FROM player WHERE id=?');
   $query->execute($defender{id});
   $row = $query->fetchrow_hashref();

   $defender{land} = $$row{land};

   if($attacker{land} >= $defender{land})
   {
      return 0;
   }

   if(abs($attacker{land} - $defender{land}) < $GAME_OPTIONS{bullysep})
   {
      return 0;
   }

   #calculate attacker's relative size to defender, it should be > 1
   $relsize = $defender{land} / $attacker{land};

   #if attacker is bully x > defender, it's considered a bully
   if($relsize >= $GAME_OPTIONS{antibully})
   {
      if($favor == 1)
      {
         $favor = $FAVOR{antibully} * $relsize;
         $favor = $FAVOR{antibullymax} if abs($favor) > abs($FAVOR{antibullymax});
         altfavor($attacker{id}, $favor);
      }

      return 1;
   }

   return 0;
}

sub endgame
{
   my $winner = $_[0];
   my $fame;

   my $query;
   my $query2; #nested query
   my $row;
   my $source; #take care of anyone connected

   global_msg(sprintf('In unprecedented glory, a large meteor strikes the Earth, incinerating all life ' .  
                       'and blanketing the planet in infernal darkness.'));
   if ($winner != 0) {
      global_msg(sprintf('%s has escaped Doomsday!', sql_gettitlecountry($winner)));
   }
   
   if ($winner != 0) {
      #Hall of Fame for the winner
      $query = $SQL->prepare('SELECT hk,nick,country FROM player WHERE id=?');
      $query->execute($winner);
      $fame = $query->fetchrow_hashref();

      $query = $SQL->prepare('INSERT INTO HallOfFame SET player=?,country=?,hks=?,date=NOW()');
      $query->execute($$fame{nick},$$fame{country},$$fame{hk});
   } else {
      #Asteroid wins
      $query = $SQL->prepare('INSERT INTO HallOfFame SET player=?,country=?,hks=0,date=NOW()');
      $query->execute('Asteroid','Space');
   }
   #read session log clean up
   $query = $SQL->prepare('DELETE FROM session_log WHERE session_log.read=1');
   $query->execute();

   #inactive player session log cleanup, technically for this to happen a player would have to not play for an entire round
   #These session logs create a lot of overhead on the DB and it is important to clean up
   $query = $SQL->prepare('SELECT nick FROM player WHERE active=0');
   $query->execute();

   if($query->rows()) {
      while($row = $query->fetchrow_hashref()) {
         $query2 = $SQL->prepare('DELETE FROM session_log WHERE nickname=?');
         $query2->execute($$row{nick});
      }   
   }

   #unregister all players
   $query = $SQL->prepare('SELECT id FROM player WHERE active=1');
   $query->execute();

   while($row = $query->fetchrow_hashref())
   {
      if($$row{id} != $winner) {
         cmd_sendmail($$row{id},sprintf("%s has escaped Doomsday!\n\n--Doomsday", sql_gettitlecountry($winner)));
      } else {
         cmd_sendmail($$row{id},sprintf("You have escaped Doomsday!\n\n--Doomsday"));
      }
      sql_delete($$row{id});
      if($source = getsource($$row{id})) {
         unregister_player($source);
      }
   }
   
   #Clear the log
   $query = $SQL->prepare('DELETE FROM log WHERE player_id > 0');
   $query->execute();

   #Clear the market
   $query = $SQL->prepare('DELETE FROM market');
   $query->execute();
   
   #Clear space
   $query = $SQL->prepare('DELETE FROM space');
   $query->execute();

   #Clear sessions but leave session log (so player can see who won upon sign in)
   $query = $SQL->prepare('DELETE FROM sessions');
   $query->execute();
 
   #Clear formation table
   $query = $SQL->prepare('DELETE FROM player_formation');
   $query->execute();

   #Clear spying
   $query = $SQL->prepare('UPDATE player SET recon=0, infiltrate=0');
   $query->execute();

   if ($SHUTDOWN == 1) {
      global_msg("Game set to shut down after completion by admin...");
      exit;
   }
   
   #If not shutdown reload variables and set up the game
   dd_game_setup(); 
}

return 1;
