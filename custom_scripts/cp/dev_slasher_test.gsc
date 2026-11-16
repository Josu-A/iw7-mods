/*
 * Test helper for Rave in the Redwoods: "set slasher_test 1" in the console
 * spawns a Slasher in front of the host that can be hit outside Rave Mode, the
 * way the easter egg's Slasher fights do, but without their 60-second timeout.
 *
 * It spawns the agent directly instead of through cp_rave's spawner, since
 * calling into a map's script would break this file on every other map. So the
 * map doesn't track it as its Slasher: Rave Mode can still spawn its own.
 */

init()
{
    if(getdvar("ui_mapname") != "cp_rave")
        return;

    level thread watch_dvar();
}

watch_dvar()
{
    level endon("game_ended");

    setdvar("slasher_test", 0);

    for(;;)
    {
        wait 0.25;

        if(getdvarint("slasher_test") == 0)
            continue;

        setdvar("slasher_test", 0);
        level thread spawn_test_slasher(level.players[0]);
    }
}

/* The agent's setup makes it ethereal, so that's undone once it has run. */
spawn_test_slasher(player)
{
    if(isdefined(level.test_slasher))
    {
        iprintln("The test Slasher is still alive");
        return;
    }

    if(scripts\mp\mp_agent::getfreeagentcount() < 1)
    {
        iprintln("No free agent slot for the Slasher");
        return;
    }

    yaw = player.angles[1];
    origin = getclosestpointonnavmesh(player.origin + anglestoforward((0, yaw, 0)) * 250);

    level.test_slasher = scripts\mp\mp_agent::spawnnewagent("slasher", "axis", origin, (0, yaw + 180, 0));
    if(!isdefined(level.test_slasher))
    {
        iprintln("The Slasher failed to spawn");
        return;
    }

    level.test_slasher thread forget_on_death();

    wait 0.5;
    if(isdefined(level.test_slasher))
        level.test_slasher setethereal(0);
}

/*
 * Agents are pooled, so once the Slasher dies his entity can come back as a
 * zombie and would still look alive. Forget him as soon as he dies.
 */
forget_on_death()
{
    self waittill("death");

    if(isdefined(level.test_slasher) && level.test_slasher == self)
        level.test_slasher = undefined;
}
