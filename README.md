# Blizzard Nameplates - Threat  
Extremely lightweight addon which colors the default blizzard nameplates according to threat.  

General advice is everyone should attack red nameplates, then tanks should attack orange before yellow while others attack green before gray nameplates.  

You can tweak a few settings and colors below from Escape menu > Interface > AddOns > NamePlatesThreat:  

Colors Out of Combat (2.4-release):  

PINK: Player is Out of Combat (only if PvP colors enabled and no target)  
VIOLET: Hostile Out of Combat (or gray if fighting totems/NPCs/others)  
BLUE: Neutral Out of Combat (or gray if fighting totems/NPCs/others)  

Playing as Tank spec (2.4-release):  

RED: Healers have High Threat (emergency! get on it asap)  
ORANGE: Damage has High Threat (not good, defend your dps)  
YELLOW: Tanks have Low Threat (offtanks struggle, help them)  
GRAY: You have the Low Threat (tanking, but not perfect)  
GREEN: You have the High Threat (perfect tank, ignore these)  

Damage or Heal spec (2.4-release):  

RED: Healers have High Threat (emergency! get on it asap)  
ORANGE: You have the High Threat (disengage! find a tank)  
YELLOW: You have the Low Threat (hold attacks, wait for tank)  
GRAY: Damage has High Threat (okay to attack, but not much)  
GREEN: Tanks have High Threat (fire at will, tanks are on it)  

Settings are saved in your World of Warcraft _retail_ subfolder:  
WTF\Account\<userid>\SavedVariables\NamePlatesThreat.lua  

Anyone from TidyPlates who prefer old colors before 1.8-release can find them in Issue #4 third comment, which has a SavedVariables file you can overwrite (remember to logout your characters while doing so).  