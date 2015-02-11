<div style="text-align:center; color:yellow; background-color:black;">
<?php
   /* Doomsday web Client 0.25 by Phil "CrazySpence" Spencer" 2007 
      
      This is the first ever stand alone Doomsday client and was created
      as an example as to how simple writing a client can be.
      
      This client is not persistant, it sends a login, a command and then a logout
      after recieving any data from the commands and displays it to the client.
      
      I will be writing a persistant client next that will be runnable from ones 
      desktop and eventually a hub client that handles multiple players at one time
      
      basically this is how it works
      
      Client sets SINGLE command to receive notification after the 
      response per command is over via:
 
      CLIENT SET SINGLE\n     
 
      Client send to server: DATA nickname command\n
      Server to client: PLAYER nickname response\n 
      **response will in most cases be many lines
      Server sends <END/> when response is over 

      Game messages: GLOBAL message\n
      **Global messages are game wide events like a newplayer joining or someone 
        attacking another player or even worse someone launching the escape shuttle
        
      At present the game server sends you preformatted data eventually there will be
      two types of data modes, RAW and FORMAT. Raw will just send specific data which
      the client will be responsible for handling while FORMAT will be the current method        
            
   */
   
   //settings
   $url       = "localhost";
   $port      = "10001";
   //globals
   $user      = $_POST["user"];
   $pass      = $_POST["pass"];
   $cmd       = $_POST["cmd"];
   $newplayer = $_POST["newplayer"];
  
   if($user && $pass) {
      $fp = fsockopen($url,$port,$errno,$errstr, 10);
      stream_set_timeout($fp, 1);
      if (!$fp) {
          echo "Could not connect to Doomsday server";
          return;
      }
      fwrite($fp,"CLIENT SET SINGLE\n");
      fgets($fp);
      stream_set_timeout($fp, 5);
      if($newplayer) {
           if ($user) {
                $command = sprintf("DATA %s newplayer\n",$user);
                fwrite($fp,$command);
                ?>
                <pre>
                <?php
                echo "\n";
                while($buffer = fgets($fp)) {
                   $buffer = str_replace(sprintf("PLAYER %s",$user),"",$buffer);
                   $buffer = wordwrap($buffer,255,"\n");
                   if ($buffer == " <END/>\n")
                      break;
                   echo $buffer;
                }
                $command = sprintf("DATA %s password %s\n",$user,$pass);
                fwrite($fp,$command);
                $buffer = fgets($fp);
                echo $buffer;
                ?>
                </pre>
                <?php
                echo "\n";
                $command = sprintf("DATA %s LOGOUT\n",$user);
                fwrite($fp,$command);
                fclose($fp);
                showform();
                return;
          }
      }
      $login = sprintf("DATA %s LOGIN %s\n",$user,$pass);
      if ($cmd)
          $command = sprintf("DATA %s %s\n",$user,$cmd );
      else
          $command = sprintf("DATA %s motd\n",$user);
      fwrite($fp,$login);  
      $buffer = fgets($fp);
      if ($buffer == (sprintf("PLAYER %s WELCOME\n",$user))) {
          ?>
          <p>
          <?php
          fgets($fp); //there is a <END/> after welcome we don't want it
          if ($command){
             fwrite($fp,$command);
             echo "<pre>\n";
             while ($buffer) {
               $buffer = fgets($fp);
               $buffer = str_replace(sprintf("PLAYER %s",$user),"",$buffer);
               $buffer = wordwrap($buffer,255,"\n");
               if ($buffer == " <END/>\n") 
                   break;
               echo $buffer;
             
            }
             echo "</pre>\n";
          }
          $command = sprintf("DATA %s LOGOUT\n",$user);
          fwrite($fp,$command);
          fclose($fp);
          ?>
          <form method="post" name="ingame" action="<?php echo $PHP_SELF ?>">
          <fieldset>
          <input name="cmd" type=text value="" />
          <input name="user" type=hidden value="<?php echo $user ?>"/>
          <input name="pass" type=hidden value="<?php echo $pass ?>"/>
          <input type="submit" name=submit value="Command"/>
          </fieldset>
          </form>
          <?php
      } else {
          echo "<pre>\n" . $buffer . "</pre>\n";
          fclose($fp);
          showform();
      }
   } else {
        showform();
        showglobal($url,$port,$errno,$errstr);
          
   }
?>
</div>
<script language="JavaScript">
<!--

document.ingame.cmd.focus();

//-->
</script>

<?php
function showglobal($url,$port,$errno,$errstr) {
     echo "<div style=\"text-align:left;\">\n";
     $fp = fsockopen($url,$port,$errno,$errstr, 10);
      stream_set_timeout($fp, 5);
      if (!$fp) {
          echo "Could not connect to Doomsday server\n<br/>\n";
          return;
      }
      fwrite($fp,"CLIENT GLOBAL\n");
      echo "<pre>\n";
      while($buffer = fgets($fp)) {

          $buffer = str_replace("SERVER","&lt;Doomsday&gt;",$buffer);
          $buffer = str_replace("\'","'",$buffer);
          $buffer = wordwrap($buffer,83,"\n");
          if ($buffer == "&lt;Doomsday&gt; <END/>\n") 
               break;
          echo $buffer;
      }
      echo "</pre>\n";
      fclose($fp);
      echo "</div>\n<div style=\"text-align:center\">\n";
}
function showform() {
?>
<form method="post" target="widget1-frame" action="<?php echo $PHP_SELF ?>">
<fieldset>
Username: <input name="user" type="text" value=""/>
Password: <input name="pass" type="password" value=""/>
<input type="submit" name="submit" value="login"/>
<br/>
<br/>
<input name="newplayer" type="submit" value="New Player"/>
</fieldset>
</form>
<?php
}
?>
