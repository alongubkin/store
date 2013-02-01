![store](http://alongubkin.github.com/store/logo.png "store")

## Description
An open store plugin for SourceMod. 

More documentation and tutorials can be found at [our wiki](https://github.com/alongubkin/store/wiki).

### Requirements

* Working Source-based Game Server with SourceMod installed.
* MySQL database, with a tool such as phpMyAdmin for database management. 
* [SDKHooks](http://forums.alliedmods.net/showthread.php?t=106748) 
* [SMJansson](https://forums.alliedmods.net/showthread.php?t=184604)

### Features

* **Modular** and **Extensible** - This package is organized in modules, where each module is a different SourceMod plugin. You can extend the store, [add new items](https://github.com/alongubkin/store/wiki/Creating-items-for-Store) or anything you can think of just by writing a new SourceMod plugins.
* **Shop** - Players can buy various items from the shop. The item is added to the player's inventory. Items in the shop are organized in categories.
* **Inventory** - The player's personal inventory, allowing for storage for all in-game items. From their inventory, players can use or equip items they own. Items in the inventory are also organized in categories.
* **Loadout** - Players can have multiple sets of equipped items. You can switch between the sets anytime using the loadout menu. You can have specific loadouts for different games, different in-game (TF2) classes, different in-game teams or any combination of them.
* **Distributor** - Every X minutes, all players that are currently connected to server will get Y credits (configurable).
* **Logging** - The plugin maintains full logs of all errors, warnings and information.
* Custom currency name.
* Custom chat triggers for the store main menu, shop, inventory and loadout.

## Installation

Just download the attached zip archive and extract to your sourcemod folder intact. Then navigate to your `configs/` directory and add the following entry in `databases.cfg`:
    
    "store"
    {
        "driver"        "mysql"
        "host"          "<your-database-host>"
        "database"		"<your-database-name>"
        "user"		    "<username>"
        "pass"		    "<password>"
    }
    
Then, navigate to `configs/store/sql-init-scripts` and execute `store.sql` in your database. For each item module you want to add, execute the corresponding SQL file in `configs/store/sql-init-scripts` and enable the plugin.

([Tutorial](https://github.com/alongubkin/store/wiki/Installing-Store))
## License

Copyright (C) 2013  Alon Gubkin

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
