<?php

function chan_auth() {
    Require "inc/defs.php";
    $db = mysqli_connect($sqlhost,$sqluser,$sqlpass,$sqldb);
    /* login stuff starts here */

    $valid = 0;
    $faqsessid = mysqli_real_escape_string($db,$_COOKIE[sess]);

    if ($faqsessid) {
        // They have a session ID.
        $mysql_res = mysqli_query($db,"SELECT nick FROM sessions " .
	             "WHERE sessid='$faqsessid'")
	or die("mysql_error: " . mysqli_error());

        if (mysqli_num_rows($mysql_res)) {
            $mysql_row = mysqli_fetch_row($mysql_res);
            // They are who they say they are!  Store their nick in
            // $nick, don't forget you'll probably need to do
            // "global $nick" to use it inside any other functions
            // later.
            $nick = $mysql_row[0];

            // Update the time so that it counts from their last page view
            mysqli_query($db,"UPDATE sessions SET time=NOW() WHERE sessid='$faqsessid'");
            $sql = "SELECT user FROM profile WHERE user='$nick'";
            $result = mysqli_query($db,$sql);
            if (!$row = mysqli_fetch_row($result)) {
                /* someone who isn't in the database is logged in so add them to the database */
                $sql = "SELECT id FROM player WHERE nick='$nick'";
                $result = mysqli_query($db,$sql);
                $row = mysqli_fetch_row($result);
                $format = "%s: %s<br/>";
                $player_id = $row[0];
                $sql = "INSERT INTO profile (player_id,user,format,header,footer) VALUES ('$player_id','$nick','$format','$defaultheader','$defaultfooter')";
                mysqli_query($db,$sql);
                $sql = "INSERT INTO player_sidebar (player_nick,command,Description) VALUES ('$nick','help','Command menu')";
                mysqli_query($db,$sql);
                $sql = "INSERT INTO player_sidebar (player_nick,command,Description) VALUES ('$nick','r g','General')";
                mysqli_query($db,$sql);
                $sql = "INSERT INTO player_sidebar (player_nick,command,Description) VALUES ('$nick','r r','Research')";
                mysqli_query($db,$sql);
            }
                                 
            mysqli_close($db);
            return $nick;
        }
    }
}

function getSQLpassword($username) {
     Require "inc/defs.php";
     $db = mysqli_connect($sqlhost,$sqluser,$sqlpass,$sqldb);  
     $sql = sprintf("SELECT password FROM player WHERE nick='%s'",$username);
     $result = mysqli_query($db,$sql);
     if ($result) {
          $row = mysqli_fetch_array($result);
          $password = $row["password"];
          return $password;
     }
     mysqli_close($db);
     return 0;
}

function auth($username,$password) {
     if (strcmp(md5($password),getSQLpassword($username)) == 0) {
          Require "inc/defs.php";
          $db = mysqli_connect($sqlhost,$sqluser,$sqlpass,$sqldb);
          $session = md5(sprintf("%s%s%s",time(),$username,$password));
          setcookie("sess",$session,time() + (60 * 60 * 24 * 365), "/", ".philtopia.com");
          $sql = "INSERT INTO sessions (sessid,nick,time) VALUES ('$session','$username',NOW())";
          $result = mysqli_query($db,$sql);
          $sql = "SELECT active FROM player WHERE nick='$username'";
          $result = mysqli_query($db,$sql);
          $row = mysqli_fetch_array($result);
          if($row['active'] == 0) {
               $sql = "UPDATE player SET active='1' WHERE nick='$username'";
               mysqli_query($db,$sql);
          }
          
          //IP track
          $sql = sprintf("INSERT INTO address_log (nick,ip,date) VALUES ('%s','%s',NOW())",$username,$_SERVER['REMOTE_ADDR']);
	  mysqli_query($db,$sql);
	  mysqli_close($db);
          header("Location: " . $_SERVER["PHP_SELF"]);
          return 1;
                 
     } else
        return 0;
}

function doomsday_command($text) {
   if(!($user = chan_auth()))
      return;
   Require "inc/defs.php";
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

   Require "inc/defs.php";
   $db = mysqli_connect($sqlhost,$sqluser,$sqlpass,$sqldb); 
   $sql = "UPDATE session_log SET session_log.read=1 WHERE nickname='$user'"; //Readit!
   $result = mysqli_query($db,$sql);
   $sql = "SELECT data FROM session_log WHERE nickname='$user' ORDER BY id ASC";
   $result = mysqli_query($db,$sql);
   echo "<pre>";
   while ($row = mysqli_fetch_array($result))
   {
        echo htmlspecialchars($row["data"]);
   }
   echo "</pre>";
   mysqli_close($db);
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
     Require "inc/defs.php";
     $db = mysqli_connect($sqlhost,$sqluser,$sqlpass,$sqldb);
     echo "<div style=\"text-align:left;\">\n";
     $sql = "SELECT time,text FROM log WHERE type = 'global' ORDER BY id DESC LIMIT $limit";
     $result = mysqli_query($db,$sql);
     if ($result) 
     {
          echo "<pre>";
          while($row = mysqli_fetch_array($result))
          {
               echo $row["time"] . " " . $row["text"] . "\n";
          }
          echo "</pre>";
     }
     echo "</div>";
     mysqli_close($db);
}




