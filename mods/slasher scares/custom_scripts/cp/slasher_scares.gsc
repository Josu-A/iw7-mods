/*
 * Restores Rave in the Redwoods' Slasher scares. The map has 5 spots where a
 * Slasher walks past players outside Rave Vision once they come near and look
 * that way, and setup_scares sets them up, but nothing ever calls it.
 *
 * Calls setup_scares and replaces wait_for_player_approach, which runs each
 * spot, with a copy where the Slasher keeps walking while someone can see him
 * and then vanishes in his teleport effect, instead of being cut off after a
 * single stride.
 *
 * The Slasher's own teleport effects only show in Rave Vision, and the scares
 * only show outside it, so the vanish uses slasher_scare_vanish, the custom
 * effect in this mod's mod.ff: his weak teleport effect without the Rave
 * Vision emitter group.
 */

#using_animtree("slasher_scares");

main()
{
    setup = getfunction("scripts/cp/maps/cp_rave/cp_rave", "setup_scares");
    if(!isdefined(setup))
        return;

    level._effect["slasher_scare_vanish"] = loadfx("vfx/iw7/core/zombie/rave/slasher_scare_vanish.vfx");
    replacefunc(getfunction("scripts/cp/maps/cp_rave/cp_rave", "wait_for_player_approach"), ::wait_for_player_approach_stub);
    level thread [[setup]]();
}

/@
"Name: wait_for_player_approach_stub( <spot> )"
"Summary: Replaces the game's wait_for_player_approach. Once a player outside Rave Vision is within 164 units of the spot's trigger point and facing the spot, and no Slasher is on the map, shows the Slasher walking to the players outside Rave Vision. The game deletes him after one stride of the walk animation; here he walks up to 3 strides, stopping after the first once nobody can see him, and vanishes in the Slasher's teleport effect. His saw is a separate model linked to his hand, the way the game shows the Slasher in the Boots charm quest, because the body model has none."
"MandatoryArg: <spot>: The scare's slasher_scenes struct, whose target is its trigger point."
"Example: spot thread wait_for_player_approach_stub( spot );"
@/
wait_for_player_approach_stub(spot)
{
    level endon("game_ended");

    if(!isdefined(spot.target))
        return;

    trigger = scripts\engine\utility::getstruct(spot.target, "targetname");
    slasher = spawn("script_model", spot.origin);
    if(isdefined(spot.angles))
        slasher.angles = spot.angles;
    else
        slasher.angles = (0, 0, 0);

    slasher setmodel("body_zmb_slasher");
    slasher hide();

    slasher.saw = spawn("script_model", spot.origin);
    slasher.saw setmodel("weapon_zmb_slasher_vm");
    slasher.saw hide();
    slasher.saw.origin = slasher gettagorigin("tag_inhand");
    slasher.saw.angles = slasher gettagangles("tag_inhand");
    slasher.saw linkto(slasher, "tag_inhand");

    while(!player_approached(trigger, slasher))
        wait(randomfloatrange(0.1, 1));

    wait 0.5;

    foreach(player in level.players)
    {
        if(!scripts\engine\utility::is_true(player.rave_mode))
        {
            slasher showtoplayer(player);
            slasher.saw showtoplayer(player);
        }
    }

    for(stride = 0; stride < 3; stride++)
    {
        if(stride > 0 && !anyone_sees(slasher))
            break;

        slasher scriptmodelplayanimdeltamotionfrompos("IW7_cp_slasher_walk_forward_01", slasher.origin, slasher.angles);
        if(!walk_one_stride(slasher, stride > 0))
            break;
    }

    vanish(slasher);
}

/@
"Name: player_approached( <trigger>, <slasher> )"
"Summary: Returns whether a player has set off the scare: no Slasher is on the map, and a player is within 164 units of the trigger point, facing the hidden Slasher."
"MandatoryArg: <trigger>: The scare's trigger point struct."
"MandatoryArg: <slasher>: The hidden Slasher's script model."
"Example: approached = player_approached( trigger, slasher );"
@/
player_approached(trigger, slasher)
{
    if(isdefined(level.slasher))
        return 0;

    foreach(player in level.players)
    {
        isPlayerWithinDistance = distance2dsquared(player.origin, trigger.origin) <= 164*164;
        isPlayerFacingSlasher = isPlayerWithinDistance && scripts\engine\utility::within_fov(player.origin, player getplayerangles(), slasher.origin, 0.83);
        if(isPlayerFacingSlasher)
            return 1;
    }

    return 0;
}

/@
"Name: anyone_sees( <slasher> )"
"Summary: Returns whether a player outside Rave Vision has the Slasher in view, facing him with nothing in between."
"MandatoryArg: <slasher>: The Slasher's script model."
"Example: seen = anyone_sees( slasher );"
@/
anyone_sees(slasher)
{
    chest = slasher gettagorigin("j_spine4");

    foreach(player in level.players)
    {
        if(scripts\engine\utility::is_true(player.rave_mode))
            continue;

        eye = player geteye();
        isPlayerFacingSlasher = scripts\engine\utility::within_fov(eye, player getplayerangles(), chest, 0.83);
        isSlasherUnobstructed = isPlayerFacingSlasher && sighttracepassed(eye, chest, 0, slasher);
        if(isSlasherUnobstructed)
            return 1;
    }

    return 0;
}

/@
"Name: walk_one_stride( <slasher>, <watched> )"
"Summary: Waits out one stride of the walk animation, as long as the animation itself, and returns whether it finished."
"MandatoryArg: <slasher>: The Slasher's script model."
"MandatoryArg: <watched>: Whether to stop early once nobody can see him."
"Example: finished = walk_one_stride( slasher, 1 );"
@/
walk_one_stride(slasher, watched)
{
    strideTime = getanimlength(%iw7_cp_slasher_walk_forward_01);
    strideEnd = gettime() + strideTime * 1000;
    while(gettime() < strideEnd)
    {
        scripts\engine\utility::waitframe();
        if(watched && !anyone_sees(slasher))
            return 0;
    }

    return 1;
}

/@
"Name: vanish( <slasher> )"
"Summary: Removes the Slasher and his saw in slasher_scare_vanish, his weak teleport effect made visible outside Rave Vision, where he stands."
"MandatoryArg: <slasher>: The Slasher's script model."
"Example: vanish( slasher );"
@/
vanish(slasher)
{
    if(isdefined(level._effect["slasher_scare_vanish"]))
        playfx(level._effect["slasher_scare_vanish"], slasher.origin);

    slasher.saw delete();
    slasher delete();
}
