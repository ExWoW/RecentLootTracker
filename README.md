# RecentLootTracker
A World of Warcraft WotLK (3.3.5a) addon that shows recently acquired loot in a persistent window.

This addon was written to address the 'issue' of the loot window disappearing too quickly after looting, making it hard to see what you just looted, due to AzerothCore's prompt handling of loot packets.

## Features
- Displays a list of recently acquired loot items.
- Configurable display settings including position, size, and number of items shown.
- Session mode to track loot only for the most recent kill.
- Highlights new loot entries for better visibility.

## Installation
1. Download the addon files by clicking the green "Code" button and selecting "Download ZIP".
2. Unzip the folder and remove the `-main` from the name, so that the folder is named `RecentLootTracker`.
3. Place the `RecentLootTracker` folder into your World of Warcraft `Interface/AddOns` directory.
4. Restart World of Warcraft and enable the addon in the AddOns menu.

## Configuration
- Access the configuration panel via the Blizzard Options menu.
- Customize settings such as:
    - Number of items to display. 
    - Display position and size of the loot window.
    - Enable or disable session mode.
- Use the `/rlt` command in-game to toggle the permanent display of the loot window.
