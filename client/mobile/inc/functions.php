<?php

function chan_auth() {
    Require "inc/defs.inc";
    $db = mysql_connect($sqlhost,$sqluser,$sqlpass);
    mysql_select_db($sqldb,$db);
    /* login stuff starts here */

    $valid = 0;
    $faqsessid = mysql_escape_string($_COOKIE[sess]);

    if ($faqsessid) {
        // They have a session ID.
        $mysql_res = mysql_query("SELECT nick FROM sessions " .
	             "WHERE sessid='$faqsessid'")
	or die("mysql_error: " . mysql_error());

        if (mysql_num_rows($mysql_res)) {
            $mysql_row = mysql_fetch_row($mysql_res);
            // They are who they say they are!  Store their nick in
            // $nick, don't forget you'll probably need to do
            // "global $nick" to use it inside any other functions
            // later.
            $nick = $mysql_row[0];

            // Update the time so that it counts from their last page view
            mysql_query("UPDATE sessions SET time=NOW() WHERE sessid='$faqsessid'");
            $sql = "SELECT user FROM profile WHERE user='$nick'";
            $result = mysql_query($sql);
            if (!$row = mysql_fetch_row($result)) {
                /* someone who isn't in the database is logged in so add them to the database */
                $sql = "SELECT id FROM player WHERE nick='$nick'";
                $result = mysql_query($sql);
                $row = mysql_fetch_row($result);
                $format = "%s: %s<br/>";
                $player_id = $row[0];
                $sql = "INSERT INTO profile (player_id,user,format,header,footer) VALUES ('$player_id','$nick','$format','$defaultheader','$defaultfooter')";
                mysql_query($sql);
                $sql = "INSERT INTO player_sidebar (player_nick,command,Description) VALUES ('$nick','help','Command menu')";
                mysql_query($sql);
                $sql = "INSERT INTO player_sidebar (player_nick,command,Description) VALUES ('$nick','r g','General')";
                mysql_query($sql);
                $sql = "INSERT INTO player_sidebar (player_nick,command,Description) VALUES ('$nick','r r','Research')";
                mysql_query($sql);
            }
                                 
            mysql_close($db);
            return $nick;
        }
    }
}

function getSQLpassword($username) {
     Require "inc/defs.inc";
     $db = mysql_connect($sqlhost,$sqluser,$sqlpass);
     mysql_select_db($sqldb,$db);   
     $sql = sprintf("SELECT password FROM player WHERE nick='%s'",$username);
     $result = mysql_query($sql);
     if ($result) {
          $row = mysql_fetch_array($result);
          $password = $row["password"];
          return $password;
     }
     return 0;
}

function auth($username,$password) {
     if (strcmp(md5($password),getSQLpassword($username)) == 0) {
          Require "inc/defs.inc";
          $db = mysql_connect($sqlhost,$sqluser,$sqlpass);
          mysql_select_db($sqldb,$db);   
          $session = md5(sprintf("%s%s%s",time(),$username,$password));
          setcookie("sess",$session,time() + (60 * 60 * 24 * 365), "/", ".philtopia.com");
          $sql = "INSERT INTO sessions (sessid,nick,time) VALUES ('$session','$username',NOW())";
          $result = mysql_query($sql);
          $sql = "SELECT active FROM player WHERE nick='$username'";
          $result = mysql_query($sql);
          $row = mysql_fetch_array($result);
          if($row['active'] == 0) {
               $sql = "UPDATE player SET active='1' WHERE nick='$username'";
               mysql_query($sql);
          }
          
          //IP track
          $sql = sprintf("INSERT INTO address_log (nick,ip,date) VALUES ('%s','%s',NOW())",$username,$_SERVER['REMOTE_ADDR']);
          mysql_query($sql);
          header("Location: " . $_SERVER["PHP_SELF"]);
          return 1;
                 
     } else
        return 0;
}

function doomsday_command($text) {
   if(!($user = chan_auth()))
      return;
   Require "inc/defs.inc";
   if(!$text)
        $text = "motd";
   
   $fp = fsockopen($ddurl,$ddport,$errno,$errstr, 10);
   //stream_set_timeout($fp, 5);
   if (!$fp) {
      echo "Could not connect to Doomsday server";
      return;
   }
   $buffer = sprintf("SESS %s %s\n",$_COOKIE[sess],$text);
   fwrite($fp,$buffer);
   echo "<div id='home-text' class='home-text' style='overflow: scroll;'><pre>"; //The class and style allow the pre block to move independant of the buttons
   while (($buffer = fgets($fp))) {
      $buffer = str_replace(sprintf("PLAYER %s ",$user),"",$buffer);
      $buffer = str_replace("GLOBAL","Doomsday: ",$buffer);
      echo htmlspecialchars($buffer);
   } 
   echo "</pre></div>";
   return;
}

function doomsday_sessionlog() {
   if (!($user = chan_auth()))
        return;

   Require "inc/defs.inc";
   $db = mysql_connect($sqlhost,$sqluser,$sqlpass);
   mysql_select_db($sqldb,$db); 
   $sql = "UPDATE session_log SET session_log.read=1 WHERE nickname='$user'"; //Readit!
   $result = mysql_query($sql);
   $sql = "SELECT data FROM session_log WHERE nickname='$user' ORDER BY id ASC";
   $result = mysql_query($sql);
   echo "<pre>";
   while ($row = mysql_fetch_array($result))
   {
        echo htmlspecialchars($row["data"]);
   }
   echo "</pre>";
}

function non_css_browser() { global $non_css_var; return $non_css_var; }

function blitzed_title($text) {
    if(non_css_browser()) {
       echo "<p align='left'><b>$text</b></p>\n";
    } else {
       echo "<h1 class='location'>$text</h1>\n";
    }
}

function showglobal($limit) {
     Require "inc/defs.inc";
     $db = mysql_connect($sqlhost,$sqluser,$sqlpass);
     mysql_select_db($sqldb,$db);
     echo "<div style=\"text-align:left;\">\n";
     $sql = "SELECT time,text FROM log WHERE type = 'global' ORDER BY id DESC LIMIT $limit";
     $result = mysql_query($sql);
     if ($result) 
     {
          echo "<pre>";
          while($row = mysql_fetch_array($result))
          {
               echo $row["time"] . " " . $row["text"] . "\n";
          }
          echo "</pre>";
     }
     echo "</div>";
}




