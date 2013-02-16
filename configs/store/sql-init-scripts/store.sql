CREATE TABLE IF NOT EXISTS `store_categories` (
  `id` int(11) NOT NULL auto_increment,
  `display_name` varchar(32) NOT NULL,
  `description` varchar(128) default NULL,
  `require_plugin` varchar(32) default NULL,
  `web_description` text default NULL,  
  `web_color` varchar(10) default NULL,
  PRIMARY KEY  (`id`)
) ENGINE=MyISAM  DEFAULT CHARSET=latin1 AUTO_INCREMENT=10 ;


CREATE TABLE IF NOT EXISTS `store_items` (
  `id` int(11)NOT NULL auto_increment,
  `name` varchar(32) NOT NULL,
  `display_name` varchar(32) NOT NULL,
  `description` varchar(128) default NULL,
  `web_description` text,
  `type` varchar(32) NOT NULL,
  `loadout_slot` varchar(32) default NULL,
  `price` int(11) NOT NULL,
  `category_id` int(11) NOT NULL,
  `attrs` text default NULL, 
  `is_buyable` tinyint(1) NOT NULL DEFAULT '1',
  `is_tradeable` tinyint(1) NOT NULL DEFAULT '1',
  `is_refundable` tinyint(1) NOT NULL DEFAULT '1',
  `expiry_time` int(11) NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `name` (`name`)
) ENGINE=MyISAM  DEFAULT CHARSET=latin1 AUTO_INCREMENT=150 ;


CREATE TABLE IF NOT EXISTS `store_loadouts` (
  `id` int(11) NOT NULL auto_increment,
  `display_name` varchar(32) NOT NULL,
  `game` varchar(32) default NULL,
  `class` varchar(32) default NULL,
  `team` int(11) default NULL,
  PRIMARY KEY  (`id`)
) ENGINE=MyISAM  DEFAULT CHARSET=latin1 AUTO_INCREMENT=4 ;

INSERT INTO `store_loadouts` (`display_name`, `game`, `class`, `team`) VALUES
('A', NULL, NULL, NULL),
('B', NULL, NULL, NULL),
('C', NULL, NULL, NULL);

CREATE TABLE IF NOT EXISTS `store_users` (
  `id` int(11) NOT NULL auto_increment,
  `auth` int(11) NOT NULL,
  `name` varchar(32) NOT NULL,
  `credits` int(11) NOT NULL,
  PRIMARY KEY  (`id`),
  UNIQUE KEY `auth` (`auth`)
) ENGINE=MyISAM  DEFAULT CHARSET=latin1 AUTO_INCREMENT=730 ;

CREATE TABLE IF NOT EXISTS `store_users_items` (
  `id` int(11) NOT NULL auto_increment,
  `user_id` int(11) NOT NULL,
  `item_id` int(11) NOT NULL,
  `acquire_date` DATETIME NULL,
  `aquire_method` ENUM('shop', 'trade', 'gift', 'admin', 'web') NULL,
  PRIMARY KEY  (`id`)
) ENGINE=MyISAM  DEFAULT CHARSET=latin1 AUTO_INCREMENT=434 ;

CREATE TABLE IF NOT EXISTS `store_users_items_loadouts` (
  `id` int(11) NOT NULL auto_increment,
  `useritem_id` int(11) NOT NULL,
  `loadout_id` int(11) NOT NULL,
  PRIMARY KEY  (`id`)
) ENGINE=MyISAM  DEFAULT CHARSET=latin1 AUTO_INCREMENT=1036 ;