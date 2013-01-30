INSERT INTO `store_categories` (`display_name`, `description`, `require_plugin`, `web_color`) VALUES 
	('Hats', 'Cosmetic hats that appear on your head.', 'equipment', '476291');
	
set @hats_category_id = (select last_insert_id());

INSERT INTO `store_categories` (`display_name`, `description`, `require_plugin`, `web_color`) VALUES 
	('Miscs', 'Cosmetic items such as glasses and masks.', 'equipment', '4D7455');
	
set @miscs_category_id = (select last_insert_id());

INSERT INTO `store_items` (`name`, `display_name`, `description`, `type`, `loadout_slot`, `price`, `category_id`, `attrs`) VALUES
('trafficcone', 'Traffic Cone', NULL, 'equipment', 'hat', 650, @hats_category_id, '{ "model": "models/props_junk/trafficcone001a.mdl", "position": [0.0, -1.0, 20.0], "angles": [0.0, 0.0, 0.0], "attachment": "forward" }'),
('watermelon', 'Watermelon', NULL, 'equipment', 'hat', 650, @hats_category_id, '{ "model": "models/props_junk/watermelon01.mdl", "position": [0.0, 0.0, 5.0], "angles": [0.0, 0.0, 0.0], "attachment": "forward" }'),
('santahat', 'Santahat', NULL, 'equipment', 'hat', 650, @hats_category_id, '{ "model": "models/gmod_tower/santahat.mdl", "position": [0.0, -1.0, 6.0], "angles": [0.0, 0.0, 0.0], "attachment": "forward" }'),
('sombrero', 'Sombrero', NULL, 'equipment', 'hat', 650, @hats_category_id, '{ "model": "models/gmod_tower/sombrero.mdl", "position": [0.0, -1.0, 6.0], "angles": [0.0, 0.0, 0.0], "attachment": "forward" }'),
('headcrabhat', 'Head Crabhat', NULL, 'equipment', 'hat', 650, @hats_category_id, '{ "model": "models/gmod_tower/headcrabhat.mdl", "position": [0.0, -3.0, 6.0], "angles": [0.0, 0.0, 0.0], "attachment": "forward" }'),
('fedora', 'Fedora', NULL, 'equipment', 'hat', 650, @hats_category_id, '{ "model": "models/gmod_tower/fedorahat.mdl", "position": [0.0, -1.5, 8.5], "angles": [0.0, 0.0, 0.0], "attachment": "forward" }'),
('cakehat', 'Cake Hat', NULL, 'equipment', 'hat', 650, @hats_category_id, '{ "model": "models/cakehat/cakehat.mdl", "position": [0.0, -1.0, 3.0], "angles": [0.0, 0.0, 0.0], "attachment": "forward" }'),
('catears', 'Cat Ears', NULL, 'equipment', 'hat', 650, @hats_category_id, '{ "model": "models/gmod_tower/catears.mdl", "position": [0.0, -3.0, 6.0], "angles": [0.0, 0.0, 0.0], "attachment": "forward" }'),
('afro', 'Afro', NULL, 'equipment', 'hat', 1200, @hats_category_id, '{ "model": "models/gmod_tower/afro.mdl", "position": [0.0, -3.0, 6.0], "angles": [0.0, 0.0, 0.0], "attachment": "forward" }'),
('linkhat', 'Link Hat', NULL, 'equipment', 'hat', 1200, @hats_category_id, '{ "model": "models/gmod_tower/linkhat.mdl", "position": [0.0, -5.0, 4.0], "angles": [0.0, 0.0, 0.0], "attachment": "forward" }'),
('partyhat', 'Party Hat', NULL, 'equipment', 'hat', 1200, @hats_category_id, '{ "model": "models/gmod_tower/partyhat.mdl", "position": [1.0, -1.0, 7.0], "angles": [0.0, 0.0, 0.0], "attachment": "forward" }'),
('majorasmask', 'Majoras Mask', NULL, 'equipment', 'misc', 500, @miscs_category_id, '{ "model": "models/gmod_tower/majorasmask.mdl", "position": [0.0, 0.5, 0.0], "angles": [0.0, 0.0, 0.0], "attachment": "forward" }'),
('antlers', 'Antlers', NULL, 'equipment', 'hat', 1200, @hats_category_id, '{ "model": "models/sam/antlers.mdl", "position": [0.0, 0.0, 2.0], "angles": [0.0, 0.0, 0.0], "attachment": "forward" }'),
('cartire', 'Car Tire', NULL, 'equipment', 'hat', 1200, @hats_category_id, '{ "model": "models/props_vehicles/tire001c_car.mdl", "position": [0.0, -10.0, 0.0], "angles": [90.0, 0.0, 0.0], "attachment": "forward" }'),
('terracotta', 'Terra Cotta', NULL, 'equipment', 'hat', 1200, @hats_category_id, '{ "model": "models/props_junk/terracotta01.mdl", "position": [0.0, 3.0, -10.0], "angles": [180.0, 0.0, 0.0], "attachment": "forward" }'),
('baseballcap', 'Baseball Cap', NULL, 'equipment', 'hat', 1200, @hats_category_id, '{ "model": "models/props/cs_office/snowman_hat.mdl", "position": [0.0, 0.0, 7.0], "angles": [0.0, -90.0, 0.0], "attachment": "forward" }'),
('coffeemug', 'Coffee Mug', NULL, 'equipment', 'hat', 2600, @hats_category_id, '{ "model": "models/props/cs_office/coffee_mug.mdl", "position": [0.0, 0.0, 9.0], "angles": [0.0, 0.0, 0.0], "attachment": "forward" }'),
('iloveturtles', 'I Love Turtles', NULL, 'equipment', 'hat', 2600, @hats_category_id, '{ "model": "models/props/de_tides/vending_hat.mdl", "position": [1.8, 0.0, 4.0], "angles": [0.0, -90.0, 0.0], "attachment": "forward" }'),
('astronauthelmet', 'Astronaut Helmet', NULL, 'equipment', 'hat', 2600, @hats_category_id, '{ "model": "models/astronauthelmet/astronauthelmet.mdl", "position": [0.0, 0.0, -5.0], "angles": [0.0, 0.0, 0.0], "attachment": "forward" }'),
('vikinghelmet', 'Viking Helmet', NULL, 'equipment', 'hat', 2600, @hats_category_id, '{ "model": "models/vikinghelmet/vikinghelmet.mdl", "position": [0.0, -1.0, 6.0], "angles": [0.0, 0.0, 0.0], "attachment": "forward" }'),
('kfcbucket', 'KFC Bucket', NULL, 'equipment', 'hat', 2600, @hats_category_id, '{ "model": "models/gmod_tower/kfcbucket.mdl", "position": [0.0, -1.0, 3.0], "angles": [0.0, 0.0, 0.0], "attachment": "forward" }'),
('duncehat', 'Dunce Hat', NULL, 'equipment', 'hat', 2600, @hats_category_id, '{ "model": "models/duncehat/duncehat.mdl", "position": [0.0, -1.0, 6.0], "angles": [0.0, 0.0, 0.0], "attachment": "forward" }'),
('androssmask', 'Andross Mask', NULL, 'equipment', 'misc', 500, @miscs_category_id, '{ "model": "models/gmod_tower/androssmask.mdl", "position": [0.0, 2.0, 0.0], "angles": [0.0, 0.0, 0.0], "attachment": "forward" }'),
('drinkcap', 'Drink Cap', NULL, 'equipment', 'hat', 2600, @hats_category_id, '{ "model": "models/gmod_tower/drinkcap.mdl", "position": [0.0, -1.0, 7.0], "angles": [0.0, 0.0, 0.0], "attachment": "forward" }'),
('toromask', 'Toro Mask', NULL, 'equipment', 'misc', 500, @miscs_category_id, '{ "model": "models/gmod_tower/toromask.mdl", "position": [0.0, -1.0, 4.0], "angles": [0.0, 0.0, 0.0], "attachment": "forward" }'),
('tophat', 'Top Hat', NULL, 'equipment', 'hat', 3200, @hats_category_id, '{ "model": "models/gmod_tower/tophat.mdl", "position": [0.0, -1.7, 4.5], "angles": [0.0, 0.0, 0.0], "attachment": "forward" }'),
('witchhat', 'Witch Hat', NULL, 'equipment', 'hat', 3200, @hats_category_id, '{ "model": "models/gmod_tower/witchhat.mdl", "position": [0.0, 0.0, 6.0], "angles": [0.0, 0.0, 0.0], "attachment": "forward" }'),
('toetohat', 'Toeto Hat', NULL, 'equipment', 'hat', 3200, @hats_category_id, '{ "model": "models/gmod_tower/toetohat.mdl", "position": [0.0, -1.0, 6.0], "angles": [0.0, 0.0, 0.0], "attachment": "forward" }'),
('seusshat', 'Seuss hat', NULL, 'equipment', 'hat', 3200, @hats_category_id, '{ "model": "models/gmod_tower/seusshat.mdl", "position": [0.0, -1.0, 6.0], "angles": [0.0, 0.0, 0.0], "attachment": "forward" }'),
('midnahat', 'Midna Hat', NULL, 'equipment', 'misc', 1200, @miscs_category_id, '{ "model": "models/gmod_tower/midnahat.mdl", "position": [0.0, 0.0, 0.0], "angles": [0.0, 0.0, 0.0], "attachment": "forward" }'),
('3dglasses', '3D Glasses', NULL, 'equipment', 'misc', 2600, @miscs_category_id, '{ "model": "models/gmod_tower/3dglasses.mdl", "position": [0.0, 0.5, 2.0], "angles": [0.0, 0.0, 0.0], "attachment": "forward" }'),
('klienerglasses', 'Kliener Glasses', NULL, 'equipment', 'misc', 1200, @miscs_category_id, '{ "model": "models/gmod_tower/klienerglasses.mdl", "position": [0.0, 0.5, 2.0], "angles": [0.0, 0.0, 0.0], "attachment": "forward" }');