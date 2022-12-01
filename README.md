# FE-Player-Template
An open-source rbxm-suite package that provides a framework for experienced scripters or animators of any level or both to reanimate a character or their accessories and a system to switch between different reanimations nonintrusively.

# Note
This framework is currently in alpha. Thus, the information provided below and the source code may change at any given point. 

## Usage
This framework isn't necessarily plug and play. This framework requires a few steps, which aren't hard to follow. 
1. Download the up-to-date roblox model file (.rbxm file) of FE-Player-Template
2. Place this file into a directory in your executor's workspace (a directory that allows the executor to see its files)
3. Download FE-Player-Template.lua and place this in your executor's script list
4. Execute the script. If successful, a notification should pop up on the bottom right.
Results may vary depending on the Roblox experience. You should test this in a place that lacks anti-cheats.

Installing and running animation modules are also simple:
1. Ensure the directory "fe-player-template/modules/R6" or "fe-player-template/modules/R15" is located in your executor workspace. The gui will try to locate your animation modules in this directory.
2. Place your animation module inside the R6 or R15 folder, depending on your animation module's character type
3. Observe the modules tab in this script's UI and see if they show up.
4. Click on the animation module and observe the animation change on your character.
If an animation change does not occur, it may be due to a typo in the script itself. 

## For Developers
There are two ways to modify the source code and provide your own animation modules: the Rojo method and the Roblox Studio method. I recommend the former, as the template was developed in Rojo, and the source code can be directly used in your own Rojo projects. If you use Roblox Studio, you will need to download the rbxm file in order to import the script directory and edit its contents. 

Animation modules are defined as a folder with a lua file and an animation folder, which also contains a set of lua files.

Script documentation is work-in-progress. Generally, the user of this template should only modify the contents of the animation module. I provided an example staff wielder module that interfaces with the controllers

# Acknowledgements
- A friend who introduced me to their FE Bike script. This would not exist if not for them
- Dance+emote Animations from Club Boates, Midnight Horrors, R6 Dances, Royal Hillcrest, Midnight Horrors
- richie0866 for rbxm-suite and Rostruct and MidiPlayer. Their method of loading models allowed me to design the UI without having to touch code. The framework here is inspired by Rostruct and MidiPlayer. 
- Many existing reanimations. They help alot with inspiration!
