Entity Crash Catcher v2
===============

This script detects entities that are moving too fast, leading to a potential server crash.

Make sure to configure the convars in the script to best fit your server.

#### Convars
* gs_crazyphysics (default "1"): Enables Lua crazyphysics detection
* gs_crazyphysics_echo (default "0"): Inform players of ragdoll freezing/removal
* gs_crazyphysics_interval (default "0.1"): How often to check entities for extreme velocity
* gs_crazyphysics_speed_defuse (default "4000"): Max velocity in in/s an entity can reach before it's frozen
* gs_crazyphysics_speed_remove (default "6000"): Max velocity in in/s an entity can reach before it's removed
* gs_crazyphysics_defusetime (default "1"): How long to freeze the entity for during diffusal

By default, the script only checks prop_ragdoll entities. To add more entity classes, add an entry to the tEntitiesToCheck table. tIdentifyEntities is the table of entities to run through TTT's identification process.

#### Authors
* code_gs - v2 creator and current maintainer
* Ambro - Original creator of script and concept
* DarthTealc - Added TTT support
* TheEMP - Fixed TTT body identification
* LuaTenshi - Better TTT check and misc fixes

Facepunch: https://gmod.facepunch.com/f/gmodaddon/jjec/Entity-Crash-Catcher/1/

GitHub: https://github.com/Kefta/Entity-Crash-Catcher
