/*
 * Stops zombies from spawning, for testing in peace. Spawns stay on until
 * "!spawns" in chat toggles them, or "set spawns 0" or "set spawns 1" in the
 * console turns them off or on. Zombies already up stay, and quests that spawn
 * their own enemies, like the Shovel charm's skeletons, still do.
 */

init()
{
    setdvarifuninitialized("spawns", 1);
    level thread hold_spawns();
    level thread watch_chat();
}

/@
"Name: hold_spawns()"
"Summary: Keeps the round's spawning paused while the spawns dvar is 0. The wave loops in zombies_spawning.gsc wait while level.zombies_paused is set; it's set every frame because quests like the Shovel charm's clear it when they're done, and cleared only once when spawns come back on, so the game's own pauses still work."
"Example: level thread hold_spawns();"
@/
hold_spawns()
{
    level endon("game_ended");
    was_off = 0;

    for(;;)
    {
        scripts\engine\utility::waitframe();
        is_off = getdvarint("spawns") == 0;

        if(is_off)
            level.zombies_paused = 1;

        if(is_off == was_off)
            continue;

        level.zombies_paused = is_off;
        iprintlnbold(is_off ? "Spawns off" : "Spawns on");
        was_off = is_off;
    }
}

/@
"Name: watch_chat()"
"Summary: Toggles spawns when someone types !spawns in chat. iw7-mod notifies say on the level for every chat message, team chat included."
"Example: level thread watch_chat();"
@/
watch_chat()
{
    level endon("game_ended");

    for(;;)
    {
        level waittill("say", player, message);

        if(toupper(message) != "!SPAWNS")
            continue;

        if(getdvarint("spawns") == 0)
            setdvar("spawns", 1);
        else
            setdvar("spawns", 0);
    }
}
