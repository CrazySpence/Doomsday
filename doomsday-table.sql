-- phpMyAdmin SQL Dump
-- version 3.3.7deb6
-- http://www.phpmyadmin.net
--
-- Host: localhost
-- Generation Time: Nov 01, 2011 at 06:48 PM
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
-- Table structure for table `achievement`
--

CREATE TABLE IF NOT EXISTS `achievement` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `player_id` int(11) NOT NULL COMMENT 'ID of player',
  `achievement_id` int(11) NOT NULL COMMENT 'ID of Achievement',
  PRIMARY KEY (`id`)
) ENGINE=MyISAM  DEFAULT CHARSET=latin1 AUTO_INCREMENT=202 ;

-- --------------------------------------------------------

--
-- Table structure for table `address_log`
--

CREATE TABLE IF NOT EXISTS `address_log` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `nick` varchar(30) NOT NULL,
  `ip` varchar(255) NOT NULL,
  `date` date NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=MyISAM  DEFAULT CHARSET=latin1 AUTO_INCREMENT=728 ;

-- --------------------------------------------------------

--
-- Table structure for table `HallOfFame`
--

CREATE TABLE IF NOT EXISTS `HallOfFame` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `player` varchar(255) NOT NULL,
  `country` varchar(15) NOT NULL,
  `hks` int(11) NOT NULL DEFAULT '0' COMMENT '# of housekeepings to win',
  `date` date NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=MyISAM  DEFAULT CHARSET=latin1 COMMENT='Winner tracking' AUTO_INCREMENT=59 ;

-- --------------------------------------------------------

CREATE TABLE IF NOT EXISTS  `player_formation` (

 `id` INT( 11 ) NOT NULL AUTO_INCREMENT ,
 `player_id` INT( 11 ) NOT NULL ,
 `formation` TEXT NOT NULL ,
 `formation_string` VARCHAR( 255 ) NOT NULL ,
PRIMARY KEY (  `id` )
) ENGINE = MYISAM DEFAULT CHARSET = latin1 COMMENT =  'Preferred unit battle formation' AUTO_INCREMENT =21;

--
-- Table structure for table `log`
--

CREATE TABLE IF NOT EXISTS `log` (
  `id` int(8) unsigned NOT NULL AUTO_INCREMENT,
  `player_id` mediumint(8) unsigned NOT NULL DEFAULT '0',
  `time` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  `type` varchar(30) NOT NULL DEFAULT '',
  `text` text NOT NULL,
  `read` int(11) NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  KEY `player_id` (`player_id`)
) ENGINE=MyISAM  DEFAULT CHARSET=latin1 AUTO_INCREMENT=75485 ;

-- --------------------------------------------------------

--
-- Table structure for table `lottery`
--

CREATE TABLE IF NOT EXISTS `lottery` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `money` int(11) NOT NULL,
  `farmers` int(11) NOT NULL,
  `winner` varchar(255) NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=MyISAM  DEFAULT CHARSET=latin1 COMMENT='Lottery tracking table' AUTO_INCREMENT=2 ;

-- --------------------------------------------------------

--
-- Table structure for table `mail`
--

CREATE TABLE IF NOT EXISTS `mail` (
  `id` int(4) NOT NULL AUTO_INCREMENT,
  `player_id` int(4) NOT NULL,
  `from_player` varchar(32) NOT NULL,
  `message` blob NOT NULL,
  `read` tinyint(4) NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`)
) ENGINE=MyISAM  DEFAULT CHARSET=latin1 COMMENT='stores player to player mail' AUTO_INCREMENT=1210 ;

-- --------------------------------------------------------

--
-- Table structure for table `market`
--

CREATE TABLE IF NOT EXISTS `market` (
  `id` smallint(5) unsigned NOT NULL AUTO_INCREMENT,
  `player_id` smallint(5) unsigned NOT NULL DEFAULT '0',
  `unit_id` tinyint(3) unsigned NOT NULL DEFAULT '0',
  `sell` int(10) unsigned NOT NULL DEFAULT '0',
  `amount` int(10) unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`)
) ENGINE=MyISAM  DEFAULT CHARSET=latin1 AUTO_INCREMENT=1845 ;

-- --------------------------------------------------------

--
-- Table structure for table `player`
--

CREATE TABLE IF NOT EXISTS `player` (
  `id` smallint(5) unsigned NOT NULL AUTO_INCREMENT,
  `nick` varchar(30) NOT NULL DEFAULT '',
  `password` varchar(32) NOT NULL DEFAULT '',
  `email` varchar(255) DEFAULT NULL COMMENT 'if set the player will get e-mail notifications',
  `active` tinyint(1) NOT NULL DEFAULT '1',
  `flags` set('admin','established','surrender','ai','easy','medium','hard') NOT NULL,
  `country` varchar(15) NOT NULL DEFAULT '',
  `government_id` tinyint(4) unsigned NOT NULL DEFAULT '1',
  `mp` smallint(6) unsigned NOT NULL DEFAULT '75',
  `mp_bank` tinyint(3) unsigned NOT NULL DEFAULT '0',
  `surrender` tinyint(3) unsigned NOT NULL DEFAULT '20',
  `tax` tinyint(3) unsigned NOT NULL DEFAULT '7',
  `favor` float NOT NULL DEFAULT '0',
  `money` int(10) unsigned NOT NULL DEFAULT '15000',
  `land` int(10) unsigned NOT NULL DEFAULT '1100',
  `farmers` int(10) unsigned NOT NULL DEFAULT '1000',
  `scientists` int(10) unsigned NOT NULL DEFAULT '0',
  `hk` int(3) unsigned NOT NULL DEFAULT '0',
  `recon` int(11) unsigned NOT NULL DEFAULT '0',
  `infiltrate` int(11) unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  KEY `nick` (`nick`)
) ENGINE=MyISAM  DEFAULT CHARSET=latin1 AUTO_INCREMENT=52 ;

-- --------------------------------------------------------

-- --------------------------------------------------------

--
-- Table structure for table `player_statistics`
--

CREATE TABLE IF NOT EXISTS `player_statistics` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `player_id` int(11) NOT NULL COMMENT 'id of player',
  `killed` int(11) NOT NULL COMMENT 'Enemy units killed',
  `died` int(11) NOT NULL COMMENT 'Player units lost',
  `launched` int(11) NOT NULL COMMENT 'Shuttles launched',
  `downed` int(11) NOT NULL COMMENT 'Shuttles shot down',
  `wins` int(11) NOT NULL COMMENT '# of wins',
  PRIMARY KEY (`id`)
) ENGINE=MyISAM  DEFAULT CHARSET=latin1 AUTO_INCREMENT=55 ;

-- --------------------------------------------------------

--
-- Table structure for table `research`
--

CREATE TABLE IF NOT EXISTS `research` (
  `id` smallint(5) unsigned NOT NULL AUTO_INCREMENT,
  `player_id` smallint(5) unsigned NOT NULL DEFAULT '0',
  `research_id` tinyint(3) unsigned NOT NULL DEFAULT '0',
  `allocation` tinyint(3) unsigned NOT NULL DEFAULT '0',
  `level` float unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  KEY `player_id` (`player_id`)
) ENGINE=MyISAM  DEFAULT CHARSET=latin1 AUTO_INCREMENT=1285 ;

-- --------------------------------------------------------

--
-- Table structure for table `retaliation`
--

CREATE TABLE IF NOT EXISTS `retaliation` (
  `player_id` int(11) NOT NULL,
  `attacker_id` int(11) NOT NULL,
  `attacked` int(11) NOT NULL,
  `attacks` int(11) NOT NULL
) ENGINE=MyISAM DEFAULT CHARSET=latin1 COMMENT='Tracks attacks from countries in the -favour zone';

-- --------------------------------------------------------

--
-- Table structure for table `sessions`
--

CREATE TABLE IF NOT EXISTS `sessions` (
  `sessid` varchar(32) NOT NULL DEFAULT '',
  `nick` varchar(32) DEFAULT NULL,
  `time` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  PRIMARY KEY (`sessid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1 COMMENT='Blitzed auth table';

-- --------------------------------------------------------

--
-- Table structure for table `session_log`
--

CREATE TABLE IF NOT EXISTS `session_log` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `nickname` varchar(30) NOT NULL COMMENT 'Session owner',
  `data` blob NOT NULL COMMENT 'data',
  KEY `id` (`id`)
) ENGINE=MyISAM  DEFAULT CHARSET=latin1 AUTO_INCREMENT=551242 ;

-- --------------------------------------------------------

--
-- Table structure for table `space`
--

CREATE TABLE IF NOT EXISTS `space` (
  `id` smallint(5) unsigned NOT NULL AUTO_INCREMENT,
  `player_id` smallint(5) unsigned NOT NULL DEFAULT '0',
  `unit_id` tinyint(3) unsigned NOT NULL DEFAULT '0',
  `target_id` smallint(6) NOT NULL DEFAULT '0',
  `distance` float unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  KEY `player_id` (`player_id`)
) ENGINE=MyISAM  DEFAULT CHARSET=latin1 AUTO_INCREMENT=2504 ;

-- --------------------------------------------------------

--
-- Table structure for table `structure`
--

CREATE TABLE IF NOT EXISTS `structure` (
  `id` smallint(5) unsigned NOT NULL AUTO_INCREMENT,
  `player_id` smallint(5) unsigned NOT NULL DEFAULT '0',
  `structure_id` tinyint(3) unsigned NOT NULL DEFAULT '0',
  `amount` smallint(5) unsigned NOT NULL DEFAULT '0',
  `workers` mediumint(8) unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  KEY `player_id` (`player_id`)
) ENGINE=MyISAM  DEFAULT CHARSET=latin1 AUTO_INCREMENT=685 ;

-- --------------------------------------------------------

--
-- Table structure for table `unit`
--

CREATE TABLE IF NOT EXISTS `unit` (
  `id` mediumint(8) unsigned NOT NULL AUTO_INCREMENT,
  `unit_id` tinyint(3) unsigned NOT NULL DEFAULT '0',
  `player_id` mediumint(8) unsigned NOT NULL DEFAULT '0',
  `amount` int(10) unsigned NOT NULL DEFAULT '0',
  `build` float unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  KEY `player_id` (`player_id`)
) ENGINE=MyISAM  DEFAULT CHARSET=latin1 AUTO_INCREMENT=11959 ;
