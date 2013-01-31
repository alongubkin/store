INSERT INTO `store_categories` (`display_name`, `description`, `require_plugin`, `web_color`) VALUES 
	('Titles', 'Tags in your chat name.', 'title', 'A50F79');
	
set @category_id = (select last_insert_id());

INSERT INTO `store_items` (`name`, `display_name`, `description`, `type`, `loadout_slot`, `price`, `category_id`, `attrs`) VALUES
('sir', 'Sir', NULL, 'title', 'title', 100, @category_id, '{ "text": "Sir", "color": "FF0000FF" }'),
('lady', 'Lady', NULL, 'title', 'title', 100, @category_id, '{ "text": "Lady", "color": "00FFFFFF" }'),
('warrior', 'Warrior', NULL, 'title', 'title', 150, @category_id, '{ "text": "Warrior", "color": "000000FF" }'),
('baron', 'Baron', NULL, 'title', 'title', 200, @category_id, '{ "text": "Baron", "color": "FA8072FF" }'),
('overlord', 'Overlord', NULL, 'title', 'title', 250, @category_id, '{ "text": "Overlord", "color": "98FB98FF" }'),
('prince', 'Prince', NULL, 'title', 'title', 1000, @category_id, '{ "text": "Prince", "color": "000080FF" }'),
('princess', 'Princess', NULL, 'title', 'title', 1000, @category_id, '{ "text": "Princess", "color": "FFE4E1FF" }'),
('lionheart', 'Lionheart', NULL, 'title', 'title', 1500, @category_id, '{ "text": "Lionheart", "color": "FFA500FF" }'),
('bandit', 'Bandit', NULL, 'title', 'title', 2000, @category_id, '{ "text": "Bandit", "color": "F0E68CFF" }'),
('assassin', 'Assassin', NULL, 'title', 'title', 2000, @category_id, '{ "text": "Assassin", "color": "696969FF" }'),
('king', 'King', NULL, 'title', 'title', 3500, @category_id, '{ "text": "King", "color": "8A2BE2FF" }'),
('queen', 'Queen', NULL, 'title', 'title', 3500, @category_id, '{ "text": "Queen", "color": "FF69B4FF" }'),
('emperor', 'Emperor', NULL, 'title', 'title', 4000, @category_id, '{ "text": "Emperor", "color": "CF6A32FF" }'),
('theawesome', 'The Awesome', NULL, 'title', 'title', 6000, @category_id, '{ "text": "The Awesome", "color": "8650ACFF" }'),
('themagnificent', 'The Magnificent', NULL, 'title', 'title', 6000, @category_id, '{ "text": "The Magnificent", "color": "A50F79FF" }'),
('theundefeated', 'The Undefeated', NULL, 'title', 'title', 6000, @category_id, '{ "text": "The Undefeated", "color": "476291FF" }');
