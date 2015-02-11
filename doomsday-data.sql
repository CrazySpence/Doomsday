-- phpMyAdmin SQL Dump
-- version 3.3.7deb6
-- http://www.phpmyadmin.net
--
-- Host: localhost
-- Generation Time: Nov 01, 2011 at 06:47 PM
-- Server version: 5.1.49
-- PHP Version: 5.3.3-7+squeeze3

SET SQL_MODE="NO_AUTO_VALUE_ON_ZERO";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;

--
-- Database: `doomsday`
--

-- --------------------------------------------------------

--
-- Table structure for table `achievementtype`
--

CREATE TABLE IF NOT EXISTS `achievementtype` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(255) NOT NULL COMMENT 'Achievment name',
  `description` varchar(255) NOT NULL COMMENT 'Description of requirements',
  `farmers` int(11) NOT NULL COMMENT '# of farmers req',
  `land` int(11) NOT NULL COMMENT '# of land req',
  `money` int(11) NOT NULL COMMENT '# of money req',
  `killed` int(11) NOT NULL COMMENT '# of enemy troops killed',
  `died` int(11) NOT NULL COMMENT '# of players troops killed',
  `launched` int(11) NOT NULL COMMENT '# of shuttles launched',
  `downed` int(11) NOT NULL COMMENT '# of shuttles downed',
  `wins` int(11) NOT NULL COMMENT '# of wins',
  PRIMARY KEY (`id`)
) ENGINE=MyISAM  DEFAULT CHARSET=latin1 AUTO_INCREMENT=21 ;

--
-- Dumping data for table `achievementtype`
--

INSERT INTO `achievementtype` (`id`, `name`, `description`, `farmers`, `land`, `money`, `killed`, `died`, `launched`, `downed`, `wins`) VALUES
(1, 'Township', 'Have 5000 farmers sustainable by your nation', 5000, 5000, 0, 0, 0, 0, 0, 0),
(2, 'City', 'Have 10000 farmers sustainable by your nation', 10000, 10000, 0, 0, 0, 0, 0, 0),
(3, 'Thriving nation', 'Have 20000 farmers sustainable by your nation', 20000, 20000, 0, 0, 0, 0, 0, 0),
(4, 'Chieftan', '500 kills on the battle field', 0, 0, 0, 500, 0, 0, 0, 0),
(5, 'Master Chieftan', '1000 kills on the battle field', 0, 0, 0, 1000, 0, 0, 0, 0),
(6, 'Warlord', '5000 kills on the battlefield', 0, 0, 0, 5000, 0, 0, 0, 0),
(7, 'Count the dead', 'Lose 1000 troops in battle', 0, 0, 0, 0, 1000, 0, 0, 0),
(8, 'Blood bath', 'Lose 5000 troops in battle', 0, 0, 0, 0, 5000, 0, 0, 0),
(9, 'The great escape', 'Win a round of Doomsday', 0, 0, 0, 0, 0, 0, 0, 1),
(10, 'Immortal', 'Win 5 rounds of Doomsday', 0, 0, 0, 0, 0, 0, 0, 5),
(11, 'Great shot', 'Shoot down a shuttle', 0, 0, 0, 0, 0, 0, 1, 0),
(12, 'Sharp shooter', 'Shoot down 5 shuttles', 0, 0, 0, 0, 0, 0, 5, 0),
(13, 'Blue skies', 'Launch a shuttle', 0, 0, 0, 0, 0, 1, 0, 0),
(14, 'The sky is falling', 'Launch 10 shuttles', 0, 0, 0, 0, 0, 10, 0, 0),
(15, 'Money bags', 'Have a million dollars', 0, 0, 1000000, 0, 0, 0, 0, 0),
(16, 'First world nation', 'Have a nation with 30k land and farmers and 2 million dollars', 30000, 30000, 2000000, 0, 0, 0, 0, 0),
(17, 'They''re here to stay!', 'Change your password which is surely a sign you are here to stay', 0, 0, 0, 0, 0, 0, 0, -1),
(18, 'He''s dead Jim', 'Be killed', 0, 0, 0, 0, 0, 0, 0, -1),
(19, 'Citizen uprising', 'Be executed by your citizens', 0, 0, 0, 0, 0, 0, 0, -1),
(20, 'NPC Thrashing', 'Lose to an Non player character', 0, 0, 0, 0, 0, 0, 0, -1);

-- --------------------------------------------------------

--
-- Table structure for table `changelog`
--

CREATE TABLE IF NOT EXISTS `changelog` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `date` date NOT NULL,
  `changes` longtext NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=MyISAM  DEFAULT CHARSET=latin1 COMMENT='History of updates' AUTO_INCREMENT=21 ;

--
-- Dumping data for table `changelog`
--

INSERT INTO `changelog` (`id`, `date`, `changes`) VALUES
(1, '2003-05-25', '- Fixed bug where objects in space that travel further than 50 AU do not disappear out of range.'),
(2, '2003-05-27', '- Added endgame code (deletion of all players) if a shuttle > 50 AU\r\n- Added antibully code\r\n- Made production units more powerful and raised production costs across board\r\n- Raised research costs across board\r\n'),
(3, '2003-05-28', '- Passwords are now MD5\r\n- Added NEWPASS command\r\n'),
(4, '2003-05-29', '- Added MSG command\r\n- Added SAY command\r\n- MP cap of 75 now works\r\n- 3 MP / ten minuate are given, anything leftover is added to a bank\r\n  and given out 1 per ten minute\r\n'),
(5, '2003-05-30', '-Added SPY unit type and prelim SPY command\r\n-Removed troop type, troops are now ground units.\r\n-Added TRAIN = true/false enum to unittype table. Units with train=true\r\n are now trainable from farmers.\r\n'),
(6, '2003-06-02', '-Added initial terrorist generating code'),
(7, '2003-06-03', '-Added population limiting code. Population now balances\r\n at 1 acre per 1 HUMAN UNIT (farmers, troops, workers).\r\n'),
(8, '2003-07-31', '-Added ETA in report research'),
(9, '2003-08-01', '-Fixed ETA rounding. It shows the correct ETA now'),
(10, '2005-01-01', '- Game now under CrazySpence control! muwahahahaaaa\r\n- Fixed a few bugs revolving around MP bank, list\r\n- Added AI player ability, these players grow, research, train units like a  player....sort of. AI Hard has the ability to win the game if left un checked\r\n- Report Market added, the market is where units can be bought and sold'),
(11, '2007-06-08', '- wrote a new main.pl that was client/server based\r\n- wrote simple protocol for game to clients in form of:\r\n- From server: PLAYER <playername> data\r\n               GLOBAL <worldmessage>\r\n- To server: DATA <playername> <commands or stuff>\r\n             CLIENT <Client to Server command>\r\n- Web client written in PHP\r\n- Telnet client written in PERL\r\n- IRC clients brought back to life from old main line\r\n- Fixed 4 year old bug in newpass command that allowed null passwords, oops!\r\n'),
(12, '2008-01-01', '-Commodities added to game which can affect affect production and taxes\r\n-Auto market added where market is populated based on global production\r\n'),
(13, '2008-05-17', '- Added HallOfFame now when you win you you will be remembered forever and how many hk''s it took you to get there\r\n- Corrected endgame bug that left the market filled with goodies for the next game'),
(14, '2008-06-15', 'DDAY =>motd\r\nDDAY => New in 1.2.4:\r\nDDAY => Launch command revised:\r\nDDAY => launch all: launches 1 missile per shuttle as long as inventory and MP allow it\r\nDDAY => launch starwars missile: with no ID this will now target the furthest shuttle\r\nDDAY => motd command: this message is displayed by it\r\nDDAY => list command bug fixes: for 5 years the sorting has been buggy hopefully it is now corrected\r\nDDAY => Market bug fix: Selling trained units and using the market as storage is no longer possible'),
(15, '2008-09-06', '- Items have a minimum Sell price now, the lowest is half of whatever the auto market sells for. Example: Jeeps sell for 1000, you can sell them as low as 500\r\n- If you are evil, you die. any favour less than -98.9 the next housekeeping you will be killed. Don''t be evil.'),
(16, '2008-11-09', 'DDAY => New in 1.2.5:\r\nDDAY => New unit..what could it be...what does it do?\r\nDDAY => New bomb functionality BOMB <player> <building id> \r\nDDAY => Retaliation! get those small fries picking away at you!\r\nDDAY => ADVISE command shows if you can retaliate\r\nDDAY => REPORT WINNERS see who''s in the hall of fame!'),
(17, '2009-09-13', 'New in 1.2.6:\r\n\r\n-Airstrikes now bound to a 15 second delay just like ground attacks\r\n-To use the bomb command a player must now have an airfield\r\n-Destruction of factories from an Airstrike causes casualties which are logged under the defense category\r\n-Bombing with a Recon spy and Bomb ID yields a 20% higher chance of strike that a regular bomb command\r\n-Recon Spies send reports via ingame mail\r\n-Recon Spies no longer return every HK but remain inside the enemy nation until discovered or recalled.\r\n-Recon Spies that are not discovered send a new report every housekeeping via in game mail\r\n-Added recall command which recalls the Recon spy home.\r\n-Fixed a bug with disband that allowed you to disband your Recon spy but still receive reports\r\n-Recon command uses 10MP Recall uses 15 so a recon and recall equal the same mp as an attack\r\n-Moved retaliation from the housekeeping loop to the 10 minute loop to still allow the intended feature of defending your much larger nation against greedy smaller ones picking away at you but reducing the time in which you can seek that revenge. Before if a small player attacked 3 times it took 3 hks for all 3 revenge attacks to expire now it will take 30 minutes. This allows larger players to still get revenge when active but not for nearly a third of a day which was incredibly unbalanced.\r\n-Random housekeeping events that may benefit or punish you\r\n-Random Explore events that may benefit or punish you\r\n-Added command to refresh the events list so it can be updated during game\r\n-Added command to set the game to shut down after completion for when maintenance or upgrades are waiting'),
(18, '2010-10-19', 'A new round of Doomsday has begun with the launch of new version 1.3\r\n\r\nChanges:\r\n\r\n-Static accounts: your account remains after death and between rounds\r\n-New time based game: An asteroid will hit the Earth at a specified date regardless if someone has won or not which will increase pressure on the players to advance the game\r\n-Shuttle limitation: No more spamming shuttles, should lead to an interesting end game\r\n-New research item: A new research item has been added to improve your nations efficiency...find it and gain the advantage\r\n-More random events! The random event list has gone from 8 to 18 this round\r\n-E-mail notifications: with the new setemail command you can add an e-mail address to your player which will be notified whenever you are attacked or bombed'),
(19, '2011-08-24', 'New in Doomsday 1.4:\r\nFixed Bugs:\r\n-Fixed long standing issue with the telnet server which would cause it to eventually refuse new connections\r\n-If debug mode is disabled, irc,telnet and the game server no longer continue to write to stdout\r\nNew Features:\r\n-Moved Doomsday Configuration into database\r\n-Created Gameplay achievements, 20 in total that the player can collect as they progress through the game\r\n-New Doomsday Website with User profiles, Custom theming and Integrated client\r\n-Session log for web client so that you can see your command history and incoming globals during a session\r\n-Server side session timeout, If session goes stale for over an hour it is removed\r\n-Player statistics are recorded in database now for Troops killed and lost, shuttles launched and shot down and for the amount of game wins\r\n-New Web client Quick Commands sidebar for an easy click to common commands. Can be edited by User\r\n-Clear log link which clears the web clients backlog if you find Doomsday is running too far off the screen\r\n-Added catchalls for existing users to ensure their user database information is updated to new version when they re activate\r\n-Statistics page added to new website which shows various global game stats\r\n-Adjusted endgame() to handle session removal and also to preserve the global log instead of deleting it\r\nCommands:\r\n-Changed log command behavior, using log by itself will only show you entries you haven''t viewed yet\r\n-report achievement command added which will show you your acquired achievements\r\n-SESS Command for the server, If a Session exists in the database that Session ID can be used instead of logging in to issue commands. Mainly used for new web client'),
(20, '2011-09-23', '1.4.1 Fixes:\r\n\r\n-Admin flag now works correctly on appropriate users through sessions\r\n-Incoming messages now work correctly on sessions\r\n-Attack delay now works properly with sessions\r\n-Fixed critical issue with retaliation where the defender would be forced to 5% surrender max (instead of the correct 50%) and still lose their full surrenders amount of resources for example 90% instead of the max 50%.\r\n-Corrected issue with website profiles where some clever <script></script>''ing could execute a command on a logged in player by removing <script> and onclick references from profile output\r\n-Corrected issue with website where help syntax responses were not displaying correctly\r\n-Fixed issue with missile to shuttle collisions where when the shuttle was destroyed the loop continued processing which was throwing an error\r\n-Improved newplayer creation from website with a new form and explanation');

-- --------------------------------------------------------

--
-- Table structure for table `events`
--

CREATE TABLE IF NOT EXISTS `events` (
  `id` tinyint(4) NOT NULL AUTO_INCREMENT,
  `farmers` int(4) NOT NULL,
  `scientists` int(4) NOT NULL,
  `workers` int(4) NOT NULL,
  `structure` tinyint(4) NOT NULL,
  `unit` tinyint(4) NOT NULL,
  `research` tinyint(4) NOT NULL,
  `money` int(11) NOT NULL,
  `message` varchar(255) NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=MyISAM  DEFAULT CHARSET=latin1 COMMENT='Random events, can be triggers at hk or during exploration' AUTO_INCREMENT=19 ;

--
-- Dumping data for table `events`
--

INSERT INTO `events` (`id`, `farmers`, `scientists`, `workers`, `structure`, `unit`, `research`, `money`, `message`) VALUES
(1, 100, 0, 0, 0, 0, 0, 0, 'You discover a caravan of 100 farmers searching for a home'),
(2, 0, 0, 0, 0, 0, 0, 10000, 'You stumble across a lost treasure valued at $10000'),
(3, 0, 0, 0, 0, 3, 0, 0, 'You discover some abandoned humvees '),
(4, 0, 0, 0, 0, 0, 14, 0, 'You discover an ancient scroll describing the secret of Lifestyle Improvements'),
(5, -15, 0, 0, 0, 0, 0, 0, 'A barn fire has killed 15 farmers'),
(6, 0, 0, 0, 0, 0, 0, -7000, 'Bandits rob your national banks for $7000'),
(7, 0, 100, 0, 1, 0, 0, 0, 'You discover a research lab with 100 scientists willing to join your cause'),
(8, 0, 0, 0, 9, 0, 0, 0, 'You discover an abandoned factory.'),
(9, 200, 0, 0, 0, 0, 0, 100000, 'You discover a small town of 200 people. They donate $100000 to join your cause.'),
(10, 0, 500, 0, 12, 0, 0, 0, 'You discover a medium lab fully staffed with scientists'),
(11, 0, 0, 0, 0, 0, 0, 100000, 'You have been awarded $100000'),
(12, 0, 0, 0, 0, 8, 0, 0, 'You discover some abandoned tanks'),
(13, 0, 0, 0, 0, 0, 6, 0, 'Your scientists have discovered the skill of Artillery'),
(14, 0, 0, 0, 0, 12, 0, 0, 'Your interstellar defense has been bolstered with some Starwars Missiles'),
(15, -200, 0, 0, 0, 0, 0, 0, 'A terrorist attack has left 200 farmers dead'),
(16, 0, 0, 0, 0, 0, 0, -50000, 'An accounting error reveals you have $50000 less than you believed'),
(17, 500, 100, 0, 1, 2, 0, 20000, 'You discover an outlying town and assimilate its 500 farmers, lab, jeeps and $20000 into your nation'),
(18, 0, 0, 1000, 18, 0, 0, 0, 'You have discovered a fully staffed fighter hanger and add it to your nation.');

-- --------------------------------------------------------

--
-- Table structure for table `game_options`
--

CREATE TABLE IF NOT EXISTS `game_options` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `mp_max` int(11) NOT NULL,
  `mp_growth` int(11) NOT NULL,
  `mp_bankmax` int(11) NOT NULL,
  `minland` int(11) NOT NULL,
  `hk_interval` int(11) NOT NULL,
  `popgrowth_min` float NOT NULL,
  `popgrowth_max` float NOT NULL,
  `bully` float NOT NULL,
  `antibully` float NOT NULL,
  `bullysep` int(11) NOT NULL,
  `spacerange` int(11) NOT NULL,
  `land_ratio` float NOT NULL,
  `anarch_max` int(11) NOT NULL,
  `bankallocate_max` int(11) NOT NULL,
  `tax_bonus` float NOT NULL,
  `baby_bonus` float NOT NULL,
  `factory_bonus` float NOT NULL,
  `shuttle_limit` int(11) NOT NULL,
  `asteroid` int(11) NOT NULL,
  `email_account` varchar(255) NOT NULL,
  `email_password` varchar(255) NOT NULL,
  `email_server` varchar(255) NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=MyISAM  DEFAULT CHARSET=latin1 COMMENT='Configuration options for Doomsday' AUTO_INCREMENT=2 ;

--
-- Dumping data for table `game_options`
--

INSERT INTO `game_options` (`id`, `mp_max`, `mp_growth`, `mp_bankmax`, `minland`, `hk_interval`, `popgrowth_min`, `popgrowth_max`, `bully`, `antibully`, `bullysep`, `spacerange`, `land_ratio`, `anarch_max`, `bankallocate_max`, `tax_bonus`, `baby_bonus`, `factory_bonus`, `shuttle_limit`, `asteroid`, `email_account`, `email_password`, `email_server`) VALUES
(1, 75, 35, 75, 500, 7200, 0.03, 0.1, 1.75, 1.75, 1000, 50, 1, 48, 6, 0.005, 0.06, 0.15, 1, 1, 'doomsday@philtopia.com', 'partytime', 'mail.spenced.com');

-- --------------------------------------------------------

--
-- Table structure for table `government`
--

CREATE TABLE IF NOT EXISTS `government` (
  `id` tinyint(3) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(30) NOT NULL DEFAULT '',
  `title` varchar(30) NOT NULL DEFAULT '',
  PRIMARY KEY (`id`)
) ENGINE=MyISAM  DEFAULT CHARSET=latin1 AUTO_INCREMENT=3 ;

--
-- Dumping data for table `government`
--

INSERT INTO `government` (`id`, `name`, `title`) VALUES
(1, 'Anarchy', 'Anarchist'),
(2, 'Dictatorship', 'Dictator');

-- --------------------------------------------------------

--
-- Table structure for table `help`
--

CREATE TABLE IF NOT EXISTS `help` (
  `id` smallint(6) NOT NULL AUTO_INCREMENT,
  `name` varchar(30) NOT NULL DEFAULT '',
  `mp` tinyint(3) unsigned NOT NULL DEFAULT '0',
  `syntax` varchar(128) NOT NULL DEFAULT '',
  `shorthelp` varchar(255) NOT NULL DEFAULT '',
  `help` text NOT NULL,
  PRIMARY KEY (`id`),
  KEY `name` (`name`)
) ENGINE=MyISAM  DEFAULT CHARSET=latin1 AUTO_INCREMENT=33 ;

--
-- Dumping data for table `help`
--

INSERT INTO `help` (`id`, `name`, `mp`, `syntax`, `shorthelp`, `help`) VALUES
(1, 'newplayer', 0, 'NEWPLAYER', 'Start a new player', 'The newplayer command is used to start a new player. Doomsday will give you a random password, and initiate a dcc chat with you. Once the chat is initiated you will be automatically logged in.\r\n\r\nThe PASSWORD command can be used to change from the randomly generated password to a custom password.'),
(2, 'password', 0, 'PASSWORD <newpass>', 'Change your password', 'The PASSWORD command is used to change your login password.'),
(3, 'login', 0, 'LOGIN <password>', 'Login to doomsday', 'The login command is used to login to doomsday in conjuction with the player password. Once successfully logged in, a DCC chat will be initiated and any game data will be sent through the DCC chat. If the DCC chat is closed or Doomsday witnesses the player leaving the game channel, the player will automatically be logged off.'),
(4, 'housekeeping', 0, 'N/A', 'Housekeeping Explanation', 'Housekeeping is the passing of one month on the Doomsday world. All automatic calculations and control of Doomsday occur at housekeeping.\r\n\r\nThe following events occur at housekeeping in order:\r\n\r\n1. Farmers are taxed\r\n2. Farmers reproduce\r\n3. Scientists Research\r\n4. Factories Produce\r\n5. Troops paid\r\n6. Movement Points Allocation'),
(5, 'report', 0, 'REPORT [type]', 'Request information', 'Report is the main command used to retrieve detailed information about your country. The following report types are possible:\r\n\r\nType REPORT for a list of possible reports.'),
(6, 'hire', 3, 'HIRE <amount> <factory>', 'Hire workers', 'The hire command is used to hire workers (from farmers) to a specific industry (factory type). The industry specified must have room for the new workers (REPORT INDUSTRY).'),
(7, 'fire', 3, 'FIRE <amount> <factory>', 'Fire workers', 'The fire command will fire workers from a specific industry (REPORT INDUSTRY). Fired workers will become farmers again.'),
(8, 'build', 3, 'BUILD <structure>', 'Build structure', 'The build command is used to build structures. Your nation must have the available funds and the enough available land for the new structure. See REPORT TECH for a list of structure costs and sizes that are available to your nation at this time.'),
(9, 'educate', 5, 'EDUCATE <amount>', 'Educate scientists', 'The education command is used to educate farmers into scientists. Your nation must have adequete room for the new scientists (1 acre of lab space per scientist).'),
(10, 'allocate', 1, 'ALLOCATE <percentage> <topic>', 'Allocate research team', 'Allocate is used to allocate a percentage of your nation''s entire research team to research a topic. The totality of your allocations must not be more than 100%. For instance if you allocate 70% of your research team to Ground Warfare, you can only allocate 30% of your team to another topic.'),
(11, 'log', 0, 'LOG <range/wildcard>', 'View player log', 'The LOG command is used to view your player logs. Logs contain detailed information not normally sent to the client, such as HK details (taxes, farmer growth, production, research production), and events that might have happened while you were not logged in. A numeric parameter can be passed to LOG for a listing of the last # of entries, or a wildcard parameter such as LOG *GENERAL* or LOG *farmer* can be passed.'),
(12, 'attack', 15, 'ATTACK <player>', 'Ground force attack', 'Attack begins a groundforce attack with the given player.\r\n\r\nAttack is the main medium for wars in doomsday. The only way to fully attack, takeover and eventually eliminate other players in doomsday is through attack.\r\n\r\nGround wars (attacks) in doomsday constist of alternating rounds of single unit versus unit battles. \r\n\r\nIn the first round, the attacker''s unit is the attacking unit, and the defender''s unit is the defending unit. If the attacking unit fails against the defending unit, neither unit is lost, and the next round begins. In the next round it alternates so that the attacker''s unit is defending, and the defender''s unit is attacking.\r\n\r\nIf either players reach their surrender %, the war is over. If the attacking unit was the winner, he is awarded up to the defender''s surrender % in land, farmers and scientists. The defender does not gain anything if the attacker reaches their surrender %.\r\n\r\nIn the case that neither players reach their surrender % in a given amount of rounds (relative to their military size), the game is considered a stalemate and the defender receives a favor bonus for defending his/her nation. '),
(13, 'surrender', 0, 'SURRENDER <percentage>', 'Set surrender level', 'Surrender is used to change the percentage of troops your nation loses before surrendering to enemy forces. Any value between 10 and 100% is allowed. Don''t be fooled into setting your surrender as low as possible. If two equal forces with different surrender levels are at war, the force with the higher surrender level has a better chance of winning (their troops will hold out long enough for the oppossing forces troops to reach surrender level).'),
(14, 'establish', 20, 'ESTABLISH', 'Establish your nation', 'The ESTABLISH command is used to establish your nation. An unestablished nation cannot attack or be attacked.'),
(15, 'train', 3, 'TRAIN <amount> <troop>', 'Train troops', 'The train command can be used to train living troops (soldiers, marines, etc). An initial starting wage will be charged (see REPORT TECH for a listing).'),
(16, 'country', 1, 'COUNTRY <name>', 'Change country name', 'The country command is used to change your nation''s name. This is most advised because the default name for your country is your playername.\r\n\r\nA country name may only contain alpha-numeric characters and the - character. It must be no more than 15 characters in length and may not contain spaces.'),
(17, 'bulldoze', 3, 'BULLDOZE <structure>', 'Demolish structures.', 'Bulldoze is used to remove structures from your land. You will free up all of the original land, and receive half the cost of the structures.'),
(18, 'explore', 12, 'EXPLORE', 'Explore for land', 'The explore command has your nation''s explorers   scout out and secure unused land. There is a higher probability of finding a small amount or no land, than there is of finding a large chunk of land.'),
(19, 'tax', 3, 'TAX <percentage>', 'Change nation''s tax', 'The tax command is used to change your nation''s tax to the given percentage. Tax will have a direct affect on   favor every HK. The default tax rate is 7%, any rate below 7% will give a positive favor while any tax rate over 7% will give a negative favor rating (doubling for each percentage).'),
(20, 'advise', 4, 'ADVISE <player>', 'Advise against attack', 'The advise command is used as a quick way to determine if it is safe to launch an attack on the given player (safe meaning they are within your level or jurisdiction and no penalty will be given.)'),
(21, 'list', 5, 'LIST', 'List players/nations', 'The list command lists the first 10 players closest to your nation in terms of land.'),
(22, 'disband', 5, 'DISBAND <amount> <troop type>', 'Disband Troops', 'Disband is used to disband troops from your military. Only troop units (human) can be disbanded and there is no favor penalty for disbanding troops.\r\n\r\nOnce disbanded, troops return to being farmers.'),
(23, 'launch', 10, 'LAUNCH [target] <unit>', 'Launch into space', 'Launch is used to launch a unit into orbit or space. If the unit being launched is a missile or other tactical unit, an optional target ID can be given (see REPORT SPACE for a list of ids).'),
(24, 'spy', 0, 'SPY <player>', 'Spy on nations', 'Spy is used to spy on the military of the target played. There is a chance the spy will be caught and executed If not caught, the amount of intelligence gathered varies.'),
(25, 'sell', 3, 'SELL [product] [amount] [cost]', 'Sell a product on the open market', 'The sell command allows you to sell excess items on the market to make more money'),
(26, 'buy', 3, 'BUY [market ID] [amount]', 'purchase items off the market', 'The buy command allows you to buy an item you find in REPORT MARKET'),
(27, 'mail', 0, 'MAIL <player> <message>', 'send message to other players', 'Use this command to send private game messages between players. Use INBOX to check mail'),
(28, 'inbox', 0, 'INBOX', 'Check your mail', 'the INBOX command by itself shows you any unread messages you have. INBOX all will show all messages read and unread. INBOX clear will delete all messages.'),
(29, 'info', 0, 'INFO', 'displays game info', 'INFO shows the current game version, last housekeeping and time until next housekeeping.'),
(30, 'bomb', 25, 'BOMB <player> <target_id>', 'Launch airstrike against player', 'This will launch your air units against the given player. The end result will be one of the following if you win: A building will be destroyed, Farmers will be killed or you will not be able to bomb due to weather.\r\n\r\nThe <target_id> is an optional field and can only be used in certain circumstances but it allows you to specify a building in a nation to bomb'),
(31, 'recon', 10, 'RECON [player]', 'Send a reconnaissance spy into enemy territory', 'The recon spy will report back location ID''s of enemy structures and assist you when using the bomb command.'),
(32, 'setemail', 0, 'setemail [address]', 'Use the setemail command to set or unset an e-mail address on your account', 'Use the setemail command to set or unset an e-mail address on your account. using setemail with an e-mail address will set or change the e-mail address to the new one you enter. setemail by itself with no parameters will unset an e-mail address on your account.');

-- --------------------------------------------------------

--
-- Table structure for table `researchtype`
--

CREATE TABLE IF NOT EXISTS `researchtype` (
  `id` tinyint(3) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(30) NOT NULL DEFAULT '',
  `prereq` tinyint(3) unsigned NOT NULL DEFAULT '0',
  `cost` mediumint(8) unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  KEY `name` (`name`)
) ENGINE=MyISAM  DEFAULT CHARSET=latin1 AUTO_INCREMENT=23 ;

--
-- Dumping data for table `researchtype`
--

INSERT INTO `researchtype` (`id`, `name`, `prereq`, `cost`) VALUES
(1, 'Combat Training', 0, 50),
(2, 'Ground Combat', 1, 750),
(3, 'Ground Vehicle', 0, 650),
(4, 'Humvee', 3, 1250),
(5, 'Light Tank', 3, 1500),
(6, 'Artillery', 0, 3500),
(7, 'Heavy Artillery', 6, 7500),
(8, 'Astrophysics', 0, 2500),
(9, 'Shuttle', 8, 100000),
(10, 'Starwars Missile', 8, 10000),
(11, 'Research Methods', 0, 1000),
(12, 'Intelligence', 0, 1000),
(13, 'Large Lab', 11, 2000),
(14, 'Lifestyle improvements', 11, 10000),
(15, 'Production enhancement', 14, 15000),
(16, 'Coffee shop', 15, 10000),
(17, 'Alcohol', 14, 25000),
(18, '40 hour work week', 15, 20000),
(19, 'Flight', 0, 10000),
(20, 'Bomber', 19, 5000),
(21, 'Reconnaissance  ', 12, 10000),
(22, 'Urban planning', 15, 20000);

-- --------------------------------------------------------

--
-- Table structure for table `structuretype`
--

CREATE TABLE IF NOT EXISTS `structuretype` (
  `id` tinyint(3) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(30) NOT NULL DEFAULT '',
  `type` tinyint(3) unsigned NOT NULL DEFAULT '0',
  `size` mediumint(8) unsigned NOT NULL DEFAULT '0',
  `prereq` tinyint(3) unsigned NOT NULL DEFAULT '0',
  `cost` int(10) unsigned NOT NULL DEFAULT '0',
  `product` tinyint(3) unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  KEY `name` (`name`)
) ENGINE=MyISAM  DEFAULT CHARSET=latin1 AUTO_INCREMENT=20 ;

--
-- Dumping data for table `structuretype`
--

INSERT INTO `structuretype` (`id`, `name`, `type`, `size`, `prereq`, `cost`, `product`) VALUES
(1, 'Lab', 1, 100, 0, 5000, 0),
(8, 'Artillery Factory', 2, 750, 6, 25000, 9),
(3, 'Jeep Factory', 2, 500, 3, 12500, 2),
(9, 'Heavy Artillery Factory', 2, 1500, 7, 40000, 11),
(7, 'Humvee Factory', 2, 600, 4, 17500, 3),
(6, 'Light Tank Factory', 2, 750, 5, 35000, 8),
(10, 'Starwars Missile Factory', 2, 2500, 10, 50000, 12),
(11, 'Shuttle Factory', 2, 15000, 9, 150000, 10),
(12, 'Medium Lab', 1, 500, 11, 20000, 0),
(13, 'Large Lab', 1, 1000, 13, 35000, 0),
(14, 'Terrorist School', 2, 250, 255, 99999999, 14),
(15, 'Coffee Shop', 2, 100, 16, 25000, 15),
(16, 'Brewery', 2, 200, 17, 30000, 16),
(17, 'Airfield', 3, 100, 19, 40000, 0),
(18, 'Fighter Hangar', 2, 1000, 19, 50000, 18),
(19, 'Bomber Hangar', 2, 1100, 20, 60000, 19);

-- --------------------------------------------------------

--
-- Table structure for table `unittype`
--

CREATE TABLE IF NOT EXISTS `unittype` (
  `id` tinyint(3) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(30) NOT NULL DEFAULT '',
  `type` tinyint(3) unsigned NOT NULL DEFAULT '0',
  `train` enum('true','false') NOT NULL DEFAULT 'false',
  `space` enum('true','false') NOT NULL DEFAULT 'false',
  `prereq` tinyint(3) unsigned NOT NULL DEFAULT '0',
  `cost` float unsigned NOT NULL DEFAULT '0',
  `wage` smallint(5) unsigned NOT NULL DEFAULT '0',
  `attack` smallint(5) unsigned NOT NULL DEFAULT '0',
  `defense` smallint(5) unsigned NOT NULL DEFAULT '0',
  `speed` float NOT NULL DEFAULT '0' COMMENT '50 / (144 * DAYSOFGAME)',
  PRIMARY KEY (`id`),
  KEY `name` (`name`)
) ENGINE=MyISAM  DEFAULT CHARSET=latin1 AUTO_INCREMENT=24 ;

--
-- Dumping data for table `unittype`
--

INSERT INTO `unittype` (`id`, `name`, `type`, `train`, `space`, `prereq`, `cost`, `wage`, `attack`, `defense`, `speed`) VALUES
(1, 'Soldier', 1, 'true', 'false', 1, 0, 65, 1, 1, 0),
(2, 'Jeep', 1, 'false', 'false', 3, 500, 0, 8, 8, 0),
(3, 'Humvee', 1, 'false', 'false', 4, 600, 0, 10, 12, 0),
(4, 'Marine', 1, 'true', 'false', 2, 0, 125, 2, 1, 0),
(9, 'Artillery', 1, 'false', 'false', 6, 750, 0, 25, 0, 0),
(8, 'Light Tank', 1, 'false', 'false', 5, 750, 0, 13, 15, 0),
(10, 'Shuttle', 2, 'false', 'true', 9, 125000, 0, 0, 900, 0.347222),
(11, 'Heavy Artillery', 1, 'false', 'false', 7, 1000, 0, 25, 4, 0),
(12, 'Starwars Missile', 3, 'false', 'true', 10, 5000, 0, 100, 0, 2.43055),
(13, 'Spy', 4, 'true', 'false', 12, 0, 1000, 0, 0, 0),
(14, 'Terrorist', 1, 'false', 'false', 255, 25, 0, 1, 1, 0),
(15, 'Coffee', 10, 'false', 'false', 16, 0.25, 0, 0, 0, 0),
(16, 'Beer', 10, 'false', 'false', 17, 0.5, 0, 0, 0, 0),
(17, 'RPG Soldier', 1, 'true', 'false', 6, 0, 350, 5, 1, 0),
(18, 'Fighter', 5, 'false', 'false', 19, 1000, 0, 10, 2, 0),
(19, 'Bomber', 5, 'false', 'false', 20, 2200, 0, 1, 20, 0),
(20, 'Recon Spy', 4, 'true', 'false', 21, 0, 10000, 0, 0, 0),
(21, 'Asteroid', 3, 'false', 'true', 255, 0, 0, 65535, 65535, -0.0198413),
(23, 'Moose', 1, 'false', 'false', 255, 0, 0, 2, 2, 0);
