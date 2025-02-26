# Sorgis Raid Marks
Raid mark targeting and assigning addon for the vanilla wow client.

## How to optimize mark targeting
Short answer: ***enable nameplates and mod your client to increase nameplate range.***

Raid mark targeting is attempted through two methods:
- *unitid scan*: the addon scans raid/party members, their targets, pets, pet targets, etc., to try to find the marked unit. This method depends on the the unit either being a member of your group or being targeted by someone in it. 
- *nameplate scan*: if the unitid method fails **and there are nameplates visible on your screen**, the addon will scan through those nameplates to try to find the marked target.

***nameplates must be enabled and on screen for the addon to be able to scan them***

For melee DPS, enabling nameplates should be good enough. By default, plates appear at about 20 yards.

**Healers and ranged DPS should modify their clients to increase the range nameplates appear at to about 40 yards.**
The range mod can be done using this project: https://github.com/brndd/vanilla-tweaks.

Nameplates can be made to appear for enemy units only, friendly units only or all units. These modes can be assigned to keys from the Key Bindings menu, under the Targeting Functions heading. The bindings are: "Show Name Plates" (enemy only), "Show Friendly Name Plates" and "Show All Name Plates". The addon can take advantage of all three modes.

Raid mark targeting will continue to work if nameplates are disabled, but the addon will be limited to scanning group members and their targets to find raid marks.

## Slash commands
Raid mark names are: `skull`, `cross`, `moon`, `star`, `diamond`, `circle`, `square`, `triangle`. The names are not case sensitive.

### try target mark
`/trytargetmark {markname}`
tries to target the unit with the given mark name. If the mark cannot be found, the player will keep their original target.

examples:
```
/trytargetmark cross
/trytargetmark skull
/run CastSpellByName("Shadow Bolt")
```
If skull and cross are found or if only skull is found, target skull and cast shadowbolt.
If only cross is found, target cross and cast shadowbolt.
If neither marks are found, keep the player's original target and cast shadowbolt.

```
/trytargetmark moon
/run CastSpellByName("Polymorph")
```
Polymorph moon if moon is found, otherwise polymorph the player's original target.

### set mark
`/setmark {markname}`
assigns a raid mark to the player's target.

`/setmark {markname} {unitid}`
assigns a raid mark by *unitid* ("pettarget", "player", "raid1target", etc.)

examples:
```
/setmark star
/run CastSpellByName("Shackle Undead")
```
Mark the player's target with star and shackle it.

```
/trytargetmark cross
```
Attempts to target the mark and begins an auto attack

### clear mark
`/clearmark`
removes the raid mark assigned to the player's target
 
`/clearmark {unitid}`
removes the raid mark assigned to a unit by *unitid*

### clear marks
`clearmarks`
unassigns all raid marks

## Bindings
keys can be bound to target specific raid marks in the key binding menu, under the Sorgis Raid Marks heading.

## UI
The addon adds a list of raid icons to the user interface:
- Left click an icon to try to target the corresponding mark.
- Right click an icon to try to target and auto attack the mark.
- Left click + control to mark the current target with the corresponding mark.
- Move the tray by holding left click on any icon and dragging the mouse.

## Configuration
- Use `/sraidmarks` to list all options.
- `/sraidmarks lock` prevents the user from moving the UI
- `/sraidmarks unlock` allows the user to move the UI by left click + dragging an icon
- `/sraidmarks hide` hides the UI from the screen
- `/sraidmarks show` shows the UI on screen if it was hidden
- `/sraidmarks reset` sets UI default values.
- `/sraidmarks scale {VALUE}` set or check the size of the UI.
- `/sraidmarks enablecounter` each raid icon in the UI will show the number of raid/party members targeting the marked unit
- `/sraidmarks disablecounter` disables the per icon target counter
- `/sraidmarks seticon {MARK NAME} {X} {Y}` sets the position of the named raid icon in the UI. example: `/sraidmarks seticon skull 2 4`. X and Y must be postive whole numbers. unit length/height is equal to the length/height of a single icon.

