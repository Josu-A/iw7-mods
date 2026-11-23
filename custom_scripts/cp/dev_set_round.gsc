/*
 * Jumps to a round for testing: "!round 69" in chat, or "set round 69" in the
 * console, ends the current round at once so round 69 starts next.
 */

init()
{
    setdvarifuninitialized("round", 0);
    level thread watch_dvar();
    level thread watch_chat();
}

/@
"Name: watch_dvar()"
"Summary: Applies a round set from the console. The dvar is reset to 0 once applied, so the same round can be asked for again."
"Example: level thread watch_dvar();"
@/
watch_dvar()
{
    level endon("game_ended");

    for(;;)
    {
        scripts\engine\utility::waitframe();

        target = getdvarint("round");
        if(target == 0)
            continue;

        setdvar("round", 0);
        set_round(target);
    }
}

/@
"Name: watch_chat()"
"Summary: Applies a round asked for with !round in chat. iw7-mod notifies say on the level for every chat message, team chat included."
"Example: level thread watch_chat();"
@/
watch_chat()
{
    level endon("game_ended");

    for(;;)
    {
        level waittill("say", player, message);

        words = strtok(message, " ");
        if(words.size != 2 || toupper(words[0]) != "!ROUND")
            continue;

        set_round(int(words[1]));
    }
}

/@
"Name: set_round( <target> )"
"Summary: Ends the current round so the target round starts next. The round's spawning stops once current_enemy_deaths reaches desired_enemy_deaths_this_wave, and the next round is wave_num + 1 (zombies_spawning.gsc). A special round is rolled from the rounds played since the last one (cp_rave_should_run_event), so last_event_wave moves with the jump; otherwise a long jump would make one all but certain. It refuses during a special round, since the event's own script ends it rather than the kill count."
"MandatoryArg: <target>: The round to start next, 1 or higher."
"Example: set_round( 69 );"
@/
set_round(target)
{
    if(target < 1)
    {
        iprintlnbold("Round must be 1 or higher");
        return;
    }

    if(scripts\engine\utility::is_true(level.spawn_event_running))
    {
        iprintlnbold("Can't change the round during a special round");
        return;
    }

    next = level.wave_num + 1;
    level.last_event_wave = level.last_event_wave + (target - next);
    level.wave_num = target - 1;

    if(isdefined(level.desired_enemy_deaths_this_wave))
        level.current_enemy_deaths = level.desired_enemy_deaths_this_wave;

    kill_round_zombies();
    iprintlnbold("Round " + target + " starts next");
}

/@
"Name: kill_round_zombies()"
"Summary: Kills the round's zombies as died_poorly, the flag the game gives zombies it kills itself (kill_me_if_stuck), so challenges don't count the deaths. dont_cleanup marks agents other scripts keep alive: Rave's memory quest skeletons and the Super Slasher fight's zombies."
"Example: kill_round_zombies();"
@/
kill_round_zombies()
{
    foreach(enemy in scripts\cp\cp_agent_utils::getaliveagentsofteam("axis"))
    {
        if(isdefined(enemy.agent_type) && (enemy.agent_type == "slasher" || enemy.agent_type == "superslasher"))
            continue;

        if(isdefined(enemy.dont_cleanup))
            continue;

        enemy.died_poorly = 1;
        enemy suicide();
    }
}
