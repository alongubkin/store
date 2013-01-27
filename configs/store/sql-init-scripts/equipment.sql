INSERT INTO `store_categories` (`display_name`, `description`, `require_plugin`, `web_color`) VALUES 
	('Hats', 'Cosmetic hats that appear on your head.', 'equipment', '476291');
	
set @category_id = (select last_insert_id());

INSERT INTO `store_items` (`name`, `display_name`, `description`, `type`, `loadout_slot`, `price`, `category_id`, `attrs`) VALUES
('trafficcone', 'Traffic Cone', NULL, 'equipment', 'hat', 650, @category_id, '{ "model": "models/props_junk/trafficcone001a.mdl", "position": [0.0, -1.0, 20.0], "angles": [0.0, 0.0, 0.0], "attachment": "forward" }'),
('watermelon', 'Watermelon', NULL, 'equipment', 'hat', 650, @category_id, '{ "model": "models/props_junk/watermelon01.mdl", "position": [0.0, 0.0, 5.0], "angles": [0.0, 0.0, 0.0], "attachment": "forward" }');