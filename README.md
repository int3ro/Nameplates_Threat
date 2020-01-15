# Blizzard Nameplates - Threat
Extremely lightweight addon which colors the default blizzard nameplates according to threat.

You can tweak a few settings and colors below from Escape menu > Interface > AddOns > NamePlatesThreat:

Colors Out of Combat (1.8-release):

PINK: Player is Out of Combat (only if PvP colors enabled)  
VIOLET: Hostile Out of Combat (or fighting NPC/non-group)  
BLUE: Neutral Out of Combat (or fighting NPC/non-group)  

Playing as Tank spec (1.8-release):

RED: Healers have High Threat (emergency! get on it asap)  
ORANGE: Damage has High Threat (not good, defend dps)  
YELLOW: You have the Low Threat (tanking, but not perfect)  
GRAY: You have the High Threat (perfect tank, ignore these)  
GREEN: Tanks have High Threat (offtanks on it, ignore these)  

Damage or Heal spec (1.8-release):

RED: Healers have High Threat (emergency! get on it asap)  
ORANGE: You have the High Threat (disengage! find a tank)  
YELLOW: You have the Low Threat (slow down, wait for tank)  
GRAY: Damage has High Threat (ok to attack, but not much)  
GREEN: Tanks have High Threat (fire at will! tanks are on it)  

Settings are saved in your World of Warcraft _retail_ subfolder:  
WTF\Account\<userid>\SavedVariables\NamePlatesThreat.lua

Anyone from TidyPlates who prefer old colors before 1.8-release can find them in Issue #4 third comment, which has a SavedVariables file you can overwrite (remember to logout your characters while doing so).
