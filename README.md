# FE-Player-Template
An open-source, code-based, rbxm-suite package that provides a framework for experienced scripters or animators of any level or both to reanimate a character or their accessories and a system to switch between different reanimations nonintrusively.

This framework uses the Nexo Animator as a base for R6 and a hybrid of Nexo R6 and kuraga's [R15 Reanimation](https://v3rmillion.net/showthread.php?tid=1073859) for R15, with 4eyes's Network Ownership Library as an additive layer for ownership.

## Note
This framework is currently in alpha. Thus, the information provided below and the source code may change at any given point. 

This framework is partially plug-and-play: external animation modules can be installed into the fe-player-template/modules directory as .rbxm files. The framework will be able to display these files in the provided UI. In addition, the UI constantly checks this directory for files; thus, you can load animation modules on the fly (existing animation modules can also be reloaded to include new updates).

## Features
* Player movement enhancements: leaning, looking around, dodging, flying, running, and sprinting
* A CFrame animation controller that can load any animation in a module script or keyframe sequence format 
* A dance/emote player with adjustable speed and pause and play capabilities and many dance animations.
* Nonintrusive switching between different reanimation modules
* Example modules which demonstrate the capabilities of the template

## Keybinds
* "-" - Respawn
* "=" - Toggle Fling at torso
* "LeftShift" - Run
* "Z" - Roll (on ground) or Flip (in air) or Slide (while running or sprinting)
* "Ctrl" - Descend / Crouch
* "Space" - Ascend / Jump
* Double tap "Space" - Toggle flight
* Double tap "LeftShift" - Sprint
* "N" - Toggle character visibility
* "M" - Mimic a target's animations


## Usage
This framework has been programmed to be plug-and-play. This framework requires a few steps, which aren't hard to follow. 
1. Download the up-to-date roblox model file (.rbxm file) of FE-Player-Template from Github releases
2. Place this file into a directory in your executor's workspace (a directory that allows the executor to see its files)
3. Download FE-Player-Template.lua and place this in your executor's script list
4. Execute the script. If successful, a notification should pop up on the bottom right.
Results may vary depending on the Roblox experience. You should test this in a place that lacks anti-cheats.


### Installing External Animation Modules
Installing and running animation modules are also simple:
1. Ensure the directory "fe-player-template/modules/R6" or "fe-player-template/modules/R15" is located in your executor workspace. The gui will try to locate your animation modules in this directory.
2. Place your animation module (in the form of an rbxm binary) inside the R6 or R15 folder, depending on your animation module's character type
3. Observe the modules tab in this script's UI and see if they show up. They will show up as the name of the module script in the rbxm file
4. Click on the animation module and observe the animation change on your character, as well as any additional keybinds added from the script.
If an animation change does not occur, it may be due to a typo in the script itself. 
To facilitate this, I've included the fe-player-template folder on this repository. This folder also includes dances for R6 and R15. The method of installing new dance animations has a similar process.


## For Developers
There are two ways to modify the source code and provide your own animation modules: the Rojo method and the Roblox Studio method. I recommend the former, as the template was developed in Rojo, and the source code can be directly used in your own Rojo projects. If you use Roblox Studio, you will need to download the rbxm file in order to import the script directory and edit its contents. 

### Animation Modules
Animation modules are defined as a folder with a module script and an animation folder, which also contains a set of ModuleScripts or KeyframeSequences. The following is an example seen in a Rojo project. In Roblox Studio, these would be module scripts or KeyframeSequences.
```
module-name/
├── module-name.lua
├── Animations
|     ├── Walk.lua (ModuleScript)
|     ├── Run.rbxm (KeyframeSequence)
|     ├── Sprint.rbxm (KeyframeSequence) 
└──   └── Jump.lua (etc.)
module-name.project.json
```
Module source code must exist directly under the module folder. I provided an example Staff Wielder module that interfaces with the controllers. Developers should use the framework to test their animation modules before distribution. To test the external animation module using the framework, export the module-name folder (not the modulescript) into an rbxm binary (e.g. ```rojo build --output 'module-name.rbxm'  module-name.project.json``` an example is included in the repository) and place this file in the appropriate directory (see **Installing External Animation Modules**) of your rigtype.

Generally, one should distribute their modules through a Github release (as per the design philosophy of richie0866's rbxm-suite).

### General Modules
In addition to animation modules, the framework also supports modules that provide general functionality for the user. An example of such a module is Mimic, which is installed internally into FE-Player-Template by default. Users should install general modules in lieu of modifying existing FE-Player-Template code if one wants to add additional player functions (such as a camera module or a gravity controller, to come up with examples). See Mimic.lua under the Modules for a coding template.

### Animations
This process involves using Roblox Studio. To make your own animation files, you will need a keyframe sequence to module script plugin. I've included a modified version of an [Animation Converter](https://www.roblox.com/library/442028078/Animation-Converter) that outputs a format that this frameworks animation controllers can read. The general outline for conversion are the following:
- Obtain or make an animation using Moon Animator 2 (through Rig Animation) or Roblox Animation Editor
- Export the animation as a keyframe sequence in **Roblox Animation Editor**. The addon will have trouble exporting from a direct-from-Moon-Animator-2 sequence.
- Use the modified Animation Converter to convert the keyframe sequence to an animation module script.
- Copy and paste the module script contents into a .lua folder under the Animations directory above
Generally, animations should have a lot of complete keyframes (a keyframe with animation data on all player parts). Moon Animator 2 has a way of generating many intermediary keyframes. In addition, if there are too many keyframes, the modified Animation Converter prints the source into the command bar. Make sure to paste it in a Roblox module script to ensure that there are no issues with the animation data. 

In addition, the plugin has other utilities (R15-to-R6, remodified ModuleScript-to-KeyframeSequence code) to aid in development and to take advantage of innovative technologies (e.g. Live Video Animation).

Script documentation is work-in-progress. Generally, the user of this template should only modify the contents of their animation module.


# Acknowledgements
- A friend who introduced me to their cool FE Bike script. This would not exist if not for them.
- Nexo for their implementation of filtering enabled reanimation. I do not have the animator itself, but I have seen how the script works, and that propagated the development of this framework.
- 4eyedfool for their network ownership library (https://v3rmillion.net/showthread.php?tid=1172007)
- kuraga for the R15 reanimation. I'm glad that they released the source code for their reanimation, as I was able to achieve R6 and R15 support for this template
- R6 Dance+emote Animations from Club Boates, Midnight Horrors, R6 Dances, Royal Hillcrest, Midnight Horrors. I've only hand-selected a few animations from there for testing purposes.
- richie0866 for rbxm-suite and Rostruct and MidiPlayer. Their method of loading models allowed me to design the UI without having to touch code. The framework here is inspired by Rostruct and MidiPlayer (I made the UI just by looking at MidiPlayer). 
- Many existing reanimations. They help alot with inspiration!
