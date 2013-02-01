INSERT INTO `store_categories` (`display_name`, `description`, `require_plugin`, `web_color`) VALUES 
	('Titles', 'Tags in your chat name.', 'title', 'A50F79');
	
set @category_id = (select last_insert_id());

INSERT INTO `store_items` (`name`, `display_name`, `description`, `type`, `loadout_slot`, `price`, `category_id`, `attrs`) VALUES
('title_sir', 'Sir', NULL, 'title', 'title', 100, @category_id, '{ "text": "{green}Sir", "colorful_text": "{fullred}Sir" }'),
('title_lady', 'Lady', NULL, 'title', 'title', 100, @category_id, '{ "text": "{green}Lady", "colorful_text": "{aqua}Lady" }'),
('title_warrior', 'Warrior', NULL, 'title', 'title', 150, @category_id, '{ "text": "{green}Warrior", "colorful_text": "{black}Warrior" }'),
('title_baron', 'Baron', NULL, 'title', 'title', 200, @category_id, '{ "text": "{green}Baron", "colorful_text": "{salmon}Baron" }'),
('title_overlord', 'Overlord', NULL, 'title', 'title', 250, @category_id, '{ "text": "{green}Overlord", "colorful_text": "{palegreen}Overlord" }'),
('title_prince', 'Prince', NULL, 'title', 'title', 1000, @category_id, '{ "text": "{green}Prince", "colorful_text": "{navy}Prince" }'),
('title_princess', 'Princess', NULL, 'title', 'title', 1000, @category_id, '{ "text": "{green}Princess", "colorful_text": "{mistyrose}Princess" }'),
('title_lionheart', 'Lionheart', NULL, 'title', 'title', 1500, @category_id, '{ "text": "{green}Lionheart", "colorful_text": "{orange}Lionheart" }'),
('title_bandit', 'Bandit', NULL, 'title', 'title', 2000, @category_id, '{ "text": "{green}Bandit", "colorful_text": "{khaki}Bandit" }'),
('title_assassin', 'Assassin', NULL, 'title', 'title', 2000, @category_id, '{ "text": "{green}Assassin", "colorful_text": "{dimgray}Assassin" }'),
('title_king', 'King', NULL, 'title', 'title', 3500, @category_id, '{ "text": "{green}King", "colorful_text": "{blueviolet}King" }'),
('title_queen', 'Queen', NULL, 'title', 'title', 3500, @category_id, '{ "text": "{green}Queen", "colorful_text": "{hotpink}Queen" }'),
('title_emperor', 'Emperor', NULL, 'title', 'title', 4000, @category_id, '{ "text": "{green}Emperor", "colorful_text": "{strange}Emperor" }'),
('title_theawesome', 'The Awesome', NULL, 'title', 'title', 6000, @category_id, '{ "text": "{green}The Awesome", "colorful_text": "{unusual}The Awesome" }'),
('title_themagnificent', 'The Magnificent', NULL, 'title', 'title', 6000, @category_id, '{ "text": "{green}The Magnificent", "colorful_text": "{valve}The Magnificent" }'),
('title_theundefeated', 'The Undefeated', NULL, 'title', 'title', 6000, @category_id, '{ "text": "{green}The Undefeated", "colorful_text": "{vintage}The Undefeated" }');
