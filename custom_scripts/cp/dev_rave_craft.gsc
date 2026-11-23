/*
 * Gives a gem reward without crafting it: "!craft boombox" in chat gives it to
 * whoever typed it, and "set craft boombox" ("craft boombox") in the console
 * gives it to the host. It replaces whatever reward the player was holding,
 * the same as taking one from a totem.
 *
 * Names: balloon, boombox, electric, fireworks, kindlepops, laser, mower,
 * medusa, revocator, sentry.
 *
 * Each reward is given by the function its totem calls (cp_rave_interactions,
 * register_crafting_interactions). They're looked up by name, which gives
 * undefined on maps that don't load their scripts, so this only runs on Rave
 * in the Redwoods. Referencing them directly fails to link on other maps.
 */

init()
{
    if(getdvar("ui_mapname") != "cp_rave")
        return;

    level.craft_rewards = [];
    level.craft_rewards["BALLOON"] = getfunction("scripts/cp/crafted_trap_balloons", "give_crafted_trap");
    level.craft_rewards["BOOMBOX"] = getfunction("scripts/cp/crafted_trap_boombox", "give_crafted_boombox");
    level.craft_rewards["ELECTRIC"] = getfunction("scripts/cp/crafted_trap_electric", "give_crafted_trap");
    level.craft_rewards["FIREWORKS"] = getfunction("scripts/cp/crafted_trap_fireworks", "give_crafted_fireworks_trap");
    level.craft_rewards["KINDLEPOPS"] = getfunction("scripts/cp/crafted_trap_gascan", "give_crafted_gascan");
    level.craft_rewards["LASER"] = getfunction("scripts/cp/zombies/interaction_windowtraps", "purchase_laser_trap");
    level.craft_rewards["MOWER"] = getfunction("scripts/cp/crafted_trap_mower", "give_crafted_trap");
    level.craft_rewards["MEDUSA"] = getfunction("scripts/cp/cp_weapon_medusa", "give_crafted_medusa");
    level.craft_rewards["REVOCATOR"] = getfunction("scripts/cp/crafted_trap_revocator", "give_crafted_revocator");
    level.craft_rewards["SENTRY"] = getfunction("scripts/cp/cp_weapon_autosentry", "give_crafted_sentry");

    setdvarifuninitialized("craft", "");
    level thread watch_dvar();
    level thread watch_chat();
}

/@
"Name: watch_dvar()"
"Summary: Gives the host the reward named in the craft dvar, then empties the dvar, so the same reward can be asked for again."
"Example: level thread watch_dvar();"
@/
watch_dvar()
{
    level endon("game_ended");

    for(;;)
    {
        scripts\engine\utility::waitframe();

        name = getdvar("craft");
        if(name == "")
            continue;

        setdvar("craft", "");

        foreach(player in level.players)
        {
            if(player ishost())
                player give_reward(name);
        }
    }
}

/@
"Name: watch_chat()"
"Summary: Gives a player the reward named in their !craft chat message. Messages that aren't !craft followed by one name are ignored."
"Example: level thread watch_chat();"
@/
watch_chat()
{
    level endon("game_ended");

    for(;;)
    {
        level waittill("say", player, message);

        words = strtok(message, " ");
        if(words.size != 2 || toupper(words[0]) != "!CRAFT" || !isdefined(player))
            continue;

        player give_reward(words[1]);
    }
}

/@
"Name: give_reward( <name> )"
"Summary: Gives the player a reward by its name, in any case, or tells them the name is unknown. The totems pass their interaction struct first, which none of the give functions read, so it's left undefined."
"CallOn: A player"
"MandatoryArg: <name>: The reward's name, like boombox."
"Example: player give_reward( "boombox" );"
@/
give_reward(name)
{
    give = level.craft_rewards[toupper(name)];
    if(!isdefined(give))
    {
        self iprintlnbold("Unknown reward: " + name);
        return;
    }

    [[give]](undefined, self);
}
