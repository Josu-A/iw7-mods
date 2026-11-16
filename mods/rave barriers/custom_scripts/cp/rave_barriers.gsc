/*
 * Restores a cut Rave in the Redwoods feature. After 30 seconds in Rave Vision,
 * the game was meant to place an effect at one of 5 spots near the players in
 * Rave Vision, and another every 30 seconds after: a fire at 2 of them, and at
 * the other 3 a barrier that pushes players in Rave Vision away.
 *
 * The game's create_rave_fx_walls_after_time does all of this but nothing calls
 * it, so this starts it whenever someone enters Rave Vision. The barrier's effect
 * doesn't exist in the game's files either, so this loads rave_barrier_fx, the
 * custom effect in this mod's mod.ff.
 */

main()
{
    if(!isdefined(getfunction("scripts/cp/maps/cp_rave/cp_rave", "create_rave_fx_walls_after_time")))
        return;

    level._effect["rave_barrier_fx"] = loadfx("vfx/iw7/core/zombie/rave/rave_barrier_fx.vfx");
}

init()
{
    start = getfunction("scripts/cp/maps/cp_rave/cp_rave", "create_rave_fx_walls_after_time");
    if(!isdefined(start))
        return;

    level.ravebarriers_start = start;
    level thread start_on_rave();
}

/* Starts the effects when the first player enters Rave Vision, until everyone leaves it. */
start_on_rave()
{
    level endon("game_ended");

    for(;;)
    {
        level waittill("player_entered_rave");

        if(isdefined(level.ravebarriers_running))
            continue;

        if(!isdefined(level._effect["rave_barrier_fx"]))
            level._effect["rave_barrier_fx"] = level._effect["rave_shimmer"];

        level.ravebarriers_running = 1;
        level thread [[level.ravebarriers_start]]();
        level thread clear_on_empty();
    }
}

/* The game's loop ends when nobody is left in Rave Vision, so allow starting it again. */
clear_on_empty()
{
    level waittill("rave_mode_empty");
    level.ravebarriers_running = undefined;
}
