--
-- Table structure for table `categories`
--

CREATE TABLE IF NOT EXISTS `store_categories` (
  `id` int(11) NOT NULL auto_increment,
  `display_name` varchar(32) NOT NULL,
  `description` varchar(128) default NULL,
  `require_plugin` varchar(32) default NULL,
  `web_description` text default NULL,  
  `web_color` varchar(10) default NULL,
  PRIMARY KEY  (`id`)
) ENGINE=MyISAM  DEFAULT CHARSET=latin1 AUTO_INCREMENT=10 ;

--
-- Table structure for table `items`
--

CREATE TABLE IF NOT EXISTS `store_items` (
  `id` int(11)NOT NULL auto_increment,
  `name` varchar(32) NOT NULL,
  `display_name` varchar(32) NOT NULL,
  `description` varchar(128) default NULL,
  `web_description` text,
  `type` varchar(32) NOT NULL,
  `loadout_slot` varchar(32) default NULL,
  `price` int(11) NOT NULL,
  `category_id` int(11) NOT NULL
  PRIMARY KEY  (`id`)
) ENGINE=MyISAM  DEFAULT CHARSET=latin1 AUTO_INCREMENT=150 ;

--
-- Table structure for table `loadouts`
--

CREATE TABLE IF NOT EXISTS `store_loadouts` (
  `id` int(11) NOT NULL auto_increment,
  `display_name` varchar(32) NOT NULL,
  `game` varchar(32) default NULL,
  `class` varchar(32) default NULL,
  `team` int(11) default NULL,
  PRIMARY KEY  (`id`)
) ENGINE=MyISAM  DEFAULT CHARSET=latin1 AUTO_INCREMENT=4 ;

INSERT INTO `loadouts` (`displayName`, `game`, `class`, `team`) VALUES
('A', NULL, NULL, NULL),
('B', NULL, NULL, NULL),
('C', NULL, NULL, NULL);

--
-- Table structure for table `users`
--

CREATE TABLE IF NOT EXISTS `store_users` (
  `id` int(11) NOT NULL auto_increment,
  `auth` int(11) NOT NULL,
  `name` varchar(32) NOT NULL,
  `credits` int(11) NOT NULL,
  PRIMARY KEY  (`id`),
  UNIQUE KEY `auth` (`auth`)
) ENGINE=MyISAM  DEFAULT CHARSET=latin1 AUTO_INCREMENT=730 ;

--
-- Table structure for table `users_items`
--

CREATE TABLE IF NOT EXISTS `store_users_items` (
  `id` int(11) NOT NULL auto_increment,
  `user_id` int(11) NOT NULL,
  `item_id` int(11) NOT NULL,
  PRIMARY KEY  (`id`)
) ENGINE=MyISAM  DEFAULT CHARSET=latin1 AUTO_INCREMENT=434 ;

--
-- Table structure for table `users_items_loadouts`
--

CREATE TABLE IF NOT EXISTS `store_users_items_loadouts` (
  `id` int(11) NOT NULL auto_increment,
  `useritem_id` int(11) NOT NULL,
  `loadout_id` int(11) NOT NULL,
  PRIMARY KEY  (`id`)
) ENGINE=MyISAM  DEFAULT CHARSET=latin1 AUTO_INCREMENT=1036 ;