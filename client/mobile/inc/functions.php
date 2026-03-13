<?php

function chan_auth() {
    require "inc/defs.php";
    $db = mysqli_connect($sqlhost, $sqluser, $sqlpass, $sqldb);

    $faqsessid = '';
    if (isset($_COOKIE["sess"])) {
        $faqsessid = mysqli_real_escape_string($db, $_COOKIE["sess"]);
    }

    if ($faqsessid) {
        $mysql_res = mysqli_query($db, "SELECT nick FROM sessions WHERE sessid='$faqsessid'")
            or die("mysql_error: " . mysqli_error($db));

        if (mysqli_num_rows($mysql_res)) {
            $mysql_row = mysqli_fetch_row($mysql_res);
            $nick = $mysql_row[0];

            mysqli_query($db, "UPDATE sessions SET time=NOW() WHERE sessid='$faqsessid'");

            $sql = "SELECT user FROM profile WHERE user='$nick'";
            $result = mysqli_query($db, $sql);
            if (!$row = mysqli_fetch_row($result)) {
                /* User is logged in but not in profile table — add them */
                $sql = "SELECT id FROM player WHERE nick='$nick'";
                $result = mysqli_query($db, $sql);
                $row = mysqli_fetch_row($result);
                $format = "%s: %s<br/>";
                $player_id = $row[0];
                $sql = "INSERT INTO profile (player_id,user,format,header,footer) VALUES ('$player_id','$nick','$format','$defaultheader','$defaultfooter')";
                mysqli_query($db, $sql);
                $sql = "INSERT INTO player_sidebar (player_nick,command,Description) VALUES ('$nick','help','Command menu')";
                mysqli_query($db, $sql);
                $sql = "INSERT INTO player_sidebar (player_nick,command,Description) VALUES ('$nick','r g','General')";
                mysqli_query($db, $sql);
                $sql = "INSERT INTO player_sidebar (player_nick,command,Description) VALUES ('$nick','r r','Research')";
                mysqli_query($db, $sql);
            }

            mysqli_close($db);
            return $nick;
        }
    }

    mysqli_close($db);
    return null;
}

function getSQLpassword($username) {
    require "inc/defs.php";
    $db = mysqli_connect($sqlhost, $sqluser, $sqlpass, $sqldb);
    $sql = sprintf("SELECT password FROM player WHERE nick='%s'", mysqli_real_escape_string($db, $username));
    $result = mysqli_query($db, $sql);
    if ($result) {
        $row = mysqli_fetch_array($result);
        $password = $row["password"];
        mysqli_close($db);
        return $password;
    }
    mysqli_close($db);
    return 0;
}

function auth($username, $password) {
    if (strcmp(md5($password), getSQLpassword($username)) == 0) {
        require "inc/defs.php";
        $db = mysqli_connect($sqlhost, $sqluser, $sqlpass, $sqldb);
        $session = md5(sprintf("%s%s%s", time(), $username, $password));
        setcookie("sess", $session, time() + (60 * 60 * 24 * 365), "/", ".philtopia.com");

        $safe_user = mysqli_real_escape_string($db, $username);
        $sql = "INSERT INTO sessions (sessid,nick,time) VALUES ('$session','$safe_user',NOW())";
        mysqli_query($db, $sql);

        $sql = "SELECT active FROM player WHERE nick='$safe_user'";
        $result = mysqli_query($db, $sql);
        $row = mysqli_fetch_array($result);
        if ($row['active'] == 0) {
            mysqli_query($db, "UPDATE player SET active='1' WHERE nick='$safe_user'");
        }

        // IP tracking
        $safe_ip = mysqli_real_escape_string($db, $_SERVER['REMOTE_ADDR']);
        $sql = "INSERT INTO address_log (nick,ip,date) VALUES ('$safe_user','$safe_ip',NOW())";
        mysqli_query($db, $sql);

        mysqli_close($db);
        header("Location: " . $_SERVER["PHP_SELF"]);
        return 1;
    }
    return 0;
}

function doomsday_command($text) {
    if (!($user = chan_auth()))
        return;
    require "inc/defs.php";
    if (!$text)
        $text = "motd";

    $fp = fsockopen($ddurl, $ddport, $errno, $errstr, 10);
    if (!$fp) {
        echo "Could not connect to Doomsday server";
        return;
    }
    $buffer = sprintf("SESS %s %s\n", $_COOKIE["sess"], $text);
    fwrite($fp, $buffer);
    echo "<div id='home-text' class='home-text' style='overflow: scroll;'><pre>";
    while (($buffer = fgets($fp))) {
        $buffer = str_replace(sprintf("PLAYER %s ", $user), "", $buffer);
        $buffer = str_replace("GLOBAL", "Doomsday: ", $buffer);
        echo htmlspecialchars($buffer);
    }
    echo "</pre></div>";
    fclose($fp);
}

function doomsday_sessionlog() {
    if (!($user = chan_auth()))
        return;

    require "inc/defs.php";
    $db = mysqli_connect($sqlhost, $sqluser, $sqlpass, $sqldb);
    $safe_user = mysqli_real_escape_string($db, $user);

    mysqli_query($db, "UPDATE session_log SET session_log.read=1 WHERE nickname='$safe_user'");
    $result = mysqli_query($db, "SELECT data FROM session_log WHERE nickname='$safe_user' ORDER BY id ASC");
    echo "<pre>";
    while ($row = mysqli_fetch_array($result)) {
        echo htmlspecialchars($row["data"]);
    }
    echo "</pre>";
    mysqli_close($db);
}

function non_css_browser() {
    global $non_css_var;
    return $non_css_var;
}

function blitzed_title($text) {
    if (non_css_browser()) {
        echo "<p align='left'><b>$text</b></p>\n";
    } else {
        echo "<h1 class='location'>$text</h1>\n";
    }
}

function showglobal($limit) {
    require "inc/defs.php";
    $db = mysqli_connect($sqlhost, $sqluser, $sqlpass, $sqldb);
    $safe_limit = (int)$limit;
    echo "<div style=\"text-align:left;\">\n";
    $sql = "SELECT time,text FROM log WHERE type = 'global' ORDER BY id DESC LIMIT $safe_limit";
    $result = mysqli_query($db, $sql);
    if ($result) {
        echo "<pre>";
        while ($row = mysqli_fetch_array($result)) {
            echo htmlspecialchars($row["time"]) . " " . htmlspecialchars($row["text"]) . "\n";
        }
        echo "</pre>";
    }
    echo "</div>";
    mysqli_close($db);
}
