# Blizzard Nameplates - Threat  
Lightweight addon which colors the default blizzard nameplates according to threat.  
See default usage in **bold** below. Settings are saved in your WoW \_retail\_ (or similar) subfolder:  
WTF\Account\\\<userid\>\SavedVariables\NamePlatesThreat.lua  
You can tweak settings/colors below from Escape menu > Interface/Options > AddOns > NamePlatesThreat  

**Red or orange color is bad, yellow is okay but pay attention, gray or green is best.**  

"Color Non-Friendly Nameplates" addon option you can quickly disable if you want Blizzard colors always.  
"Color Nameplate Border Only" (retail only) ensures healthbar inside still uses original Blizzard colors.  
"Color Group Pets as Tanks" is an addon option that treats all pets as a tank even if their player is not.  

"Color out of Dungeons" and "Color Out of Combat" if disabled use Blizzard colors outside those situations.  
Out of combat topmost three colors below indicate if enemy is a player, or hostile/neutral NPC reputation.  
"Color Player Characters" for PvP enemies depending on who they are targeting (never based on NPC threat).  

**Colors Out of Combat (2.7-release and newer):**  
VIOLET: Hostile Out of Combat (turns blue if fighting totems/NPCs/others)  
BLUE: Neutral Out of Combat (or hostiles fighting totems/NPCs/others)  
PINK: Player is Out of Combat (only if PvP colors enabled and no target)  

"Color Gradient Updates Per Second" is an advanced feature; x times per second it fades the color between high and low as threat percent changes.
Example if you are tank with high threat (green by default) then as threat is dropping toward only 100% it will fade toward the low color (gray).
World of Warcraft generally treats anyone with 100% threat or more as "having aggro" for that enemy, and only taunt skills can override this.
It may be crucial information as a tank to know if you are losing threat to one of the other players in the group, so they should cool off a bit.
This option is advanced because color fading makes it harder to see exactly who has aggro when close to the 100% low threat target switchover.
This gradual information for hard-hitting bosses may still be preferred by some tanks.  

"Color Nameplates by Role" you can disable if you only wish to color enemies red to green, otherwise it will use the advanced role colors below.
The role colors just below lets you customize colors when you have the tank role, you can disable the checkbox again after tweaking the colors.
Notice there is both a color for "you" and "tanks" even when you have a tank role, this is so you know if YOU have aggro or an offtank buddy does.
"Unique Colors In-Between" lets you pick custom colors when someone is using taunt skills, if disabled addon just reuses the colors just above.  

**Playing as Tank role (2.7-release and newer):**  
RED: Healers have High Threat (emergency! get on it asap)  
ORANGE: Damage has High Threat (not good, defend your dps)  
YELLOW: Tanks have Low Threat (offtanks struggle, help them)  
GRAY: You have the Low Threat (or offtanks have high threat)  
GREEN: You have the High Threat (perfect tank, ignore these)  

**Damage or Heal role (2.7-release and newer):**  
RED: Healers have High Threat (emergency! get on it asap)  
ORANGE: You have the High Threat (disengage! find a tank)  
YELLOW: You have the Low Threat (hold attacks, wait for tank)  
GRAY: Damage has High Threat (okay to attack, but not much)  
GREEN: Tanks have High Threat (fire at will, tanks are on it)  

"Unique Colors as Non-Tank Role" lets you pick custom colors if you are a damager/healer role, otherwise addon reuses the color to the left of it.
Notice there is a color for "you" but also healers and damage, this is so you know if YOU have aggro or if another damage/healer buddy has aggro.
Note also how some role colors mention "you have the low threat" or "tanks have low threat" etc, it shows if enemy will soon change its target.
Note also healers have a different color from damagers; healers are very important so even damagers should help tanks defend them.  

The addon decides player roles via Set Role right-clicking their player portrait, with some exceptions:  
When you are not grouped, you are always a damager (see "Color Group Pets as Tanks" if you have a pet).  
Retail treats YOU purely by your talent spec, regardless of group role (you can still Set Role on others).  
Wrath lets you Set Role default via the round icon top right of your talent panel (or Set Role on others).  
Classic Era has no roles; leader or raid maintank/assist are tank, others healing within last 60 seconds.  
