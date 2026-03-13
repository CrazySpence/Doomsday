<?php
include_once('inc/functions.php');
include_once('inc/defs.php');

if (isset($_POST['auth'])) {
    $username = $_POST['username'];
    $password = $_POST['password'];
    if (auth($username, $password) == 0)
        $drawlogin = 1;
} elseif (!chan_auth()) {
    $drawlogin = 1;
}

if (isset($_GET['login'])) {
    if (!chan_auth()) {
        $drawlogin = 1;
    }
}

if (isset($_GET['logout'])) {
    if ($nick = chan_auth()) {
        doomsday_command("logout");
        $db = mysqli_connect($sqlhost, $sqluser, $sqlpass, $sqldb);
        $safe_nick = mysqli_real_escape_string($db, $nick);
        mysqli_query($db, "DELETE FROM sessions WHERE nick='$safe_nick'");
        mysqli_query($db, "DELETE FROM session_log WHERE nickname='$safe_nick'");
        mysqli_close($db);
        header("Location: " . $_SERVER["PHP_SELF"]);
        exit;
    }
}
?>
<!DOCTYPE html>
<html>
<head>
<meta name="viewport" content="width=device-width, initial-scale=1">
<link rel="stylesheet" href="https://code.jquery.com/mobile/1.4.5/jquery.mobile-1.4.5.min.css">
<script src="https://code.jquery.com/jquery-1.11.3.min.js"></script>
<script src="https://code.jquery.com/mobile/1.4.5/jquery.mobile-1.4.5.min.js"></script>
</head>
<body>
<div data-role="page" data-theme="b">
    <div data-role="header" class="ui-content">
<?php
if (isset($_GET['game']) && !isset($drawlogin)) {
    ?><a href="?gamelog=1" class="ui-btn ui-corner-all ui-shadow ui-icon-eye ui-btn-icon-left">Log</a><?php
} elseif (!isset($drawlogin)) {
    ?><a href="?game=1" class="ui-btn ui-corner-all ui-shadow ui-icon-home ui-btn-icon-left">Game</a><?php
}
?>
        <h1>Doomsday</h1>
<?php
if (!isset($drawlogin)) {
    if (isset($_GET['gamelog'])) {
        ?><a href="?game=1&amp;clear=1" class="ui-btn ui-corner-all ui-shadow ui-icon-delete ui-btn-icon-left">Clear</a><?php
    } else {
        ?><a href="?menu=1" class="ui-btn ui-corner-all ui-shadow ui-icon-gear ui-btn-icon-left">Menu</a><?php
    }
}
?>
    </div>

    <div data-role="main" class="ui-content">
<?php

if (!isset($_GET["startitem"]) || $_GET["startitem"] == 0) {

    echo "<div id='home-text' class='home-text' style='overflow: scroll;'>";

    if (isset($_POST["newplayer"])) {
        $user = $_POST["username"];
        $fp = fsockopen($ddurl, $ddport, $errno, $errstr, 10);
        stream_set_timeout($fp, 5);
        if (!$fp) {
            echo "Could not connect to Doomsday server";
        } else {
            fwrite($fp, "CLIENT SET SINGLE\n");
            fgets($fp);
            if ($user) {
                $command = sprintf("DATA %s newplayer\n", $user);
                fwrite($fp, $command);
                echo "<pre>\n";
                while ($buffer = fgets($fp)) {
                    $buffer = str_replace(sprintf("PLAYER %s", $user), "", $buffer);
                    $buffer = str_replace("GLOBAL", "", $buffer);
                    $buffer = wordwrap($buffer, 255, "\n");
                    if (trim($buffer) == "<END/>")
                        break;
                    echo htmlspecialchars($buffer);
                }
                echo "</pre>\n";
                $command = sprintf("DATA %s LOGOUT\n", $user);
                fwrite($fp, $command);
                fclose($fp);
            }
        }
        $drawlogin = 1;
    }

    if (isset($_POST['new_login'])) {
        ?>
        Welcome to Doomsday. Fill out the name of your intended player (no spaces) and click "Create Character".
        You will then see some text relating to the creation of your user and a password which you should then log in with.
        Make sure to write down or change your password shortly after logging in and have fun.
        <br/><br/>
        <form method="POST" action="">
            <label for="username">Player name:</label>
            <input type="text" id="username" name="username" value=""/>
            <br/>
            <input type="submit" id="newplayer" name="newplayer" value="Create Character"/>
        </form>
        <?php
    } elseif (isset($drawlogin)) {
        ?>
        <form method="POST" action="<?php echo htmlspecialchars($_SERVER["PHP_SELF"]); ?>">
            <label for="username">Username:</label>
            <input type="text" id="username" name="username" value="<?php echo htmlspecialchars($_POST['username'] ?? ''); ?>"/>
            <br/>
            <label for="password">Password:</label>
            <input type="password" id="password" name="password" value=""/>
            <br/>
            <input type="submit" id="auth" name="auth" value="Log in"/>
            <input type="submit" id="new_login" name="new_login" value="New Player?"/>
        </form>
        <div id='home-text' class='home-text' style='overflow: scroll;'>
        <?php
        showglobal(20);
        echo "</div>\n";

    } elseif (isset($_GET['game'])) {
        if (isset($_GET['clear'])) {
            if ($nick = chan_auth()) {
                $db = mysqli_connect($sqlhost, $sqluser, $sqlpass, $sqldb);
                $safe_nick = mysqli_real_escape_string($db, $nick);
                mysqli_query($db, "DELETE FROM session_log WHERE nickname='$safe_nick' AND session_log.read='1'");
                mysqli_close($db);
            }
        }

        $formcommand = '';
        if (isset($_POST["command"]))       { $formcommand = $_POST["command"]; }
        if (isset($_GET["command"]))        { $formcommand = $_GET["command"]; }
        if (isset($_POST["commandbutton"])) { $formcommand = $_POST["commandbutton"]; }
        if ($formcommand === '' && !isset($_GET['clear'])) {
            $formcommand = "motd";
        }

        doomsday_command($formcommand);
        ?>
        <form method="POST" id="ingame" name="ingame" action="?game=1">
            <input type="text" id="command" name="command" value="" autofocus/>
            <input type="submit" id="submit" name="submit" value="Command"/>
            <?php
            if ($formcommand !== '') {
                printf('<input type="submit" id="commandbutton" name="commandbutton" value="%s"/>',
                    htmlspecialchars($formcommand));
            }
            ?>
        </form>
        <?php

    } elseif (isset($_GET['menu'])) {
        ?>
        <ul data-role="listview" data-inset="true">
            <li><a href="?sidebar=1" class="ui-btn ui-corner-all ui-shadow ui-icon-edit ui-btn-icon-left">Edit Shortcuts</a></li>
            <li><a href="?help=1" class="ui-btn ui-corner-all ui-shadow ui-icon-info ui-btn-icon-left">Help</a></li>
            <li><a href="?stats=1" class="ui-btn ui-corner-all ui-shadow ui-icon-info ui-btn-icon-left">Game stats</a></li>
            <li><a href="?gameconfig=1" class="ui-btn ui-corner-all ui-shadow ui-icon-info ui-btn-icon-left">Game config</a></li>
            <li><a href="?about=1" class="ui-btn ui-corner-all ui-shadow ui-icon-info ui-btn-icon-left">About</a></li>
            <li><a href="?logout=1" class="ui-btn ui-corner-all ui-shadow ui-icon-power ui-btn-icon-left">Logout</a></li>
        </ul>
        <?php

    } elseif (isset($_GET['gamelog'])) {
        doomsday_sessionlog();

    } elseif (isset($_GET['about'])) {
        blitzed_title("About Doomsday");
        ?>
        <p>
        In the year 2020, Scientists discover an asteroid the size of Norway on a collision course with Earth.
        In the year 2022 a delegation arrived from the planet Xtosven many thousands of light years away from
        the Earth. The plight of the Earth for the last few years has been known to the Xtosvenites and they
        have offered to let one colony inhabit a small region of Xtosven. The first nation on Earth to launch
        a space shuttle that would reach the outer system of the solar system, would be worthy. Earth has been
        thrown into chaos. Nations have risen and fallen in the matter of months. Earth is now a battlefield
        and it is up to you to Escape from Doomsday.
        </p>
        <?php
        blitzed_title("Game Style");
        ?>
        <p>
        Doomsday is a text UI move point based strategy game. The goal is to build up your nation
        to the point that it is able to research the appropriate technology and Escape from Doomsday.
        Time to execute commands is allocated in Move points which are issued in bulk every 2 hours. A game
        of Doomsday can take several weeks but should only require a small amount of your time per day due
        to the sparse allocation of movement points.
        </p>
        <?php
        blitzed_title("History");
        ?>
        <p>
        Doomsday was originally an IRC game played on undernet in the 90's. Erik (strtok) used
        to tell tales of this game to us as we played another IRC game, Conquest. Eventually Erik found
        the original author who gave him the game however it was broken and not able to compile in modern
        environments.
        </p>
        <p>
        Erik then tried to recreate it in C++ (2002). This did not work out well and it appeared Doomsday had met
        its end. Finally Erik started fresh in Perl (2003) and we had a playable game in record time. Eventually
        Erik became moody because he tends to get that way and cancelled the game forever. After about a year
        of relentless pestering I (CrazySpence) was given the Perl game (2004) and allowed to continue it until this day.
        </p>
        <?php

    } elseif (isset($_GET['help'])) {
        require "help.html";

    } elseif (isset($_GET['features'])) {
        blitzed_title("Features");
        ?>
        <ul>
            <li>Over 18 military units to discover and use to crush the enemy</li>
            <li>19 structures to help build your nations economy</li>
            <li>22 topics to research to better your nations technology</li>
            <li>20 achievements to gain as you battle through the game</li>
            <li>Optional E-mail notification for attack/defense alerts</li>
            <li>3 different game modes, First to 50AU, Beat the Asteroid and Restricted shuttle mode</li>
            <li>Ingame mail system</li>
            <li>Random events to either help or doom your efforts</li>
            <li>In game market where you can buy and sell new units and commodities</li>
            <li>Performance enhancing commodities that can improve research, production and farmers</li>
            <li>Self generating market items that generate based on existing production</li>
            <li>Multiple clients to support many ways of playing Doomsday</li>
            <li>Movepoint bank to bank unused points for later distribution</li>
            <li>Hall of fame to ensure your legacy lives on after a hard fought victory</li>
            <li>NPC players that build up their own nation and can win if left unchecked</li>
            <li>Raid/Quests, where the players traverse a generated map to find a reward</li>
        </ul>
        <?php

    } elseif (isset($_GET['log'])) {
        blitzed_title("Site Changelog");
        $db = mysqli_connect($sqlhost, $sqluser, $sqlpass, $sqldb);
        $sql = "SELECT * FROM log ORDER BY modified DESC LIMIT 25";
        $result = mysqli_query($db, $sql);
        while ($row = mysqli_fetch_array($result)) {
            printf("[%s] %s %s<br/>\n",
                htmlspecialchars($row["modified"]),
                htmlspecialchars($row["user"]),
                htmlspecialchars($row["message"]));
        }
        mysqli_close($db);

    } elseif (isset($_GET['sidebar']) || isset($_POST['sidebar'])) {
        if ($nick = chan_auth()) {
            $db = mysqli_connect($sqlhost, $sqluser, $sqlpass, $sqldb);
            $safe_nick = mysqli_real_escape_string($db, $nick);

            if (isset($_POST['editside'])) {
                $safe_cmd  = mysqli_real_escape_string($db, $_POST['command']);
                $safe_desc = mysqli_real_escape_string($db, $_POST['description']);
                $sql = "INSERT INTO player_sidebar SET player_nick='$safe_nick',command='$safe_cmd',Description='$safe_desc'";
                mysqli_query($db, $sql);
            }
            if (isset($_POST['delete'])) {
                $safe_id = (int)$_POST['id'];
                $sql = "DELETE FROM player_sidebar WHERE id='$safe_id' AND player_nick='$safe_nick'";
                mysqli_query($db, $sql);
            }
            ?>
            <form name="sidebar" method="POST" action="/">
            <?php blitzed_title("Add commands to the sidebar"); ?>
            <label for="command">Command</label>
            <input type="text" name="command" value=""/>
            <br/>
            <label for="description">Description</label>
            <input type="text" name="description" value=""/>
            <br/>
            <input type="submit" name="editside" value="Save"/>
            <input type="hidden" name="sidebar" value="1"/>
            </form>
            <?php
            blitzed_title("Current saved commands");
            $result = mysqli_query($db, "SELECT id,command,Description FROM player_sidebar WHERE player_nick='$safe_nick'");
            if ($result) {
                while ($row = mysqli_fetch_array($result)) {
                    ?>
                    <form name="deletesidebar" method="POST" action="/">
                        <input type="hidden" name="id" value="<?php echo (int)$row['id']; ?>"/>
                        <input type="hidden" name="sidebar" value="1"/>
                        <?php echo htmlspecialchars($row['Description']) . ", " . htmlspecialchars($row['command']); ?>
                        <input type="submit" name="delete" value="delete"/>
                    </form>
                    <?php
                }
            }
            mysqli_close($db);
        }

    } elseif (isset($_GET["stats"])) {
        $db = mysqli_connect($sqlhost, $sqluser, $sqlpass, $sqldb);
        blitzed_title("Player Statistics");
        $result = mysqli_query($db, "SELECT count(id) AS total, sum(land) AS land, sum(money) AS money FROM player WHERE active=1");
        $row = mysqli_fetch_array($result);
        echo "<pre>";
        echo "Active players for this round : " . $row['total'] . "\n";
        echo "Total occupied land           : " . $row['land'] . " acres\n";
        echo "Global economic wealth        : $" . $row['money'] . "\n";
        echo "</pre>";

        blitzed_title("Armed forces statistics");
        $result = mysqli_query($db, "SELECT SUM(unit.amount) AS amount FROM unit,unittype WHERE unit.unit_id=unittype.id AND unittype.type != 10");
        $row = mysqli_fetch_array($result);
        $result2 = mysqli_query($db, "SELECT sum(killed) AS killed, sum(launched) AS launched, sum(bomb_structure) AS structures, sum(bomb_civillian) AS civ_lost, sum(quest_complete) AS quest, sum(quest_pk) AS pk FROM player_statistics");
        $row2 = mysqli_fetch_array($result2);
        echo "<pre>";
        echo "Global military units      : " . $row['amount'] . "\n";
        echo "Global military casualties : " . $row2['killed'] . "\n";
        echo "Escape shuttles launched   : " . $row2['launched'] . "\n";
        echo "</pre>";

        blitzed_title("Airforce statistics");
        echo "<pre>";
        echo "Global structures bombed     : " . $row2['structures'] . "\n";
        echo "Global civillian casualities : " . $row2['civ_lost'] . "\n";
        echo "</pre>";

        blitzed_title("Raid Statistics");
        echo "<pre>";
        echo "Raids successfully completed : " . $row2['quest'] . "\n";
        echo "Raid player kill stats       : " . $row2['pk'] . "\n";
        echo "</pre>";
        mysqli_close($db);

    } elseif (isset($_GET['changelog'])) {
        $db = mysqli_connect($sqlhost, $sqluser, $sqlpass, $sqldb);
        $result = mysqli_query($db, "SELECT * FROM changelog");
        echo "<pre>\n";
        while ($row = mysqli_fetch_array($result)) {
            echo htmlspecialchars($row["date"]) . "\n" . htmlspecialchars($row["changes"]) . "\n\n";
        }
        echo "</pre>\n";
        mysqli_close($db);

    } elseif (isset($_GET['gameconfig'])) {
        $db = mysqli_connect($sqlhost, $sqluser, $sqlpass, $sqldb);
        $result = mysqli_query($db, "SELECT * FROM game_options");
        blitzed_title("Game Configuration");
        echo "<pre>\n";
        while ($row = mysqli_fetch_array($result)) {
            echo "MP max                   : " . $row["mp_max"] . "\n";
            echo "MP growth                : " . $row["mp_growth"] . "\n";
            echo "MP bank max              : " . $row["mp_bankmax"] . "\n";
            echo "Min land                 : " . $row["minland"] . "\n";
            echo "Housekeeping interval    : " . $row["hk_interval"] . "\n";
            echo "Population growth min    : " . $row["popgrowth_min"] . "\n";
            echo "Population growth max    : " . $row["popgrowth_max"] . "\n";
            echo "Bully ratio              : " . $row["bully"] . "\n";
            echo "Anti bully ratio         : " . $row["antibully"] . "\n";
            echo "Min bully seperation     : " . $row["bullysep"] . "\n";
            echo "Space range              : " . $row["spacerange"] . "\n";
            echo "Population -> land ratio : " . $row["land_ratio"] . "\n";
            echo "Anarchy max favour       : " . $row["anarch_max"] . "\n";
            echo "Tax bonus                : " . $row["tax_bonus"] . "\n";
            echo "Baby bonus               : " . $row["baby_bonus"] . "\n";
            echo "Factory bonus            : " . $row["factory_bonus"] . "\n";
            echo "NPC Players              : " . $row["ai_count"] . "\n";
            echo "Shuttle Limit mode       : " . $row["shuttle_limit"] . "\n";
            echo "Asteroid Mode            : " . $row["asteroid"] . "\n";
            echo "Colonists per shuttle    : " . $row["colonist"] . "\n";
        }
        echo "</pre>\n";
        mysqli_close($db);

    } else {
        ?>
        <h2>Can you Escape?</h2>
        <img width="500" height="350" src="asteroid-doomsday.jpg" alt="Doomsday asteroid"/>
        <?php
    }

    echo "</div>\n";
}
?>
    </div>

    <div data-role="footer">
<?php
if ($nick = chan_auth()) {
    $db = mysqli_connect($sqlhost, $sqluser, $sqlpass, $sqldb);
    $safe_nick = mysqli_real_escape_string($db, $nick);
    $result = mysqli_query($db, "SELECT command,Description FROM player_sidebar WHERE player_nick='$safe_nick'");
    if ($result) {
        while ($row = mysqli_fetch_array($result)) {
            printf('<a href="%s?game=1&amp;command=%s" class="ui-btn ui-corner-all ui-shadow ui-icon-carat-r ui-btn-icon-left">%s</a>' . "\n",
                htmlspecialchars($_SERVER["PHP_SELF"]),
                urlencode($row['command']),
                htmlspecialchars($row['Description']));
        }
        mysqli_close($db);
    }
}
?>
    </div>
</div>
</body>
</html>
