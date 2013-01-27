INSERT INTO `store_categories` (`display_name`, `description`, `require_plugin`, `web_color`) VALUES 
	('Trails', 'Magical trails that follow your character.', 'trails', 'FFD700');
	
set @category_id = (select last_insert_id());

INSERT INTO `store_items` (`name`, `display_name`, `description`, `type`, `loadout_slot`, `price`, `category_id`, `attrs`) VALUES
('cocacola', 'Coca Cola', NULL, 'trails', 'trails', 250, @category_id, '{ "material": "materials/sprites/trails/cocacola.vmt", "color": "FFFFFF" }');