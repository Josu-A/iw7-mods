/*
 * Shows a wireframe cube on each zombie spawn point the spawn zones use near
 * the host. "set showspawns 1" turns it on; it's off by default.
 *   showspawns_radius   flat distance from the host (1000)
 *   showspawns_max      most cubes shown, nearest first (10), 66 at most
 *   showspawns_size     cube width in units (40)
 *   showspawns_thick    edge thickness in units (1); raise it to see far cubes
 *   showspawns_xray     1 shows the cubes through walls (0)
 *
 * This script only picks the spawn points. ui_scripts/dev_show_spawns draws the
 * cubes, as UI placed in the world: retail builds can't draw debug lines, and
 * cubes made of beam effects disconnected the game with a full horde, each
 * beam being an entity. The two talk through dvars, which the host's game
 * shares with its server, so only the host sees the cubes. The UI's cubes have
 * a limit too: 100 of them dropped the game with "Requested a command not
 * received", and 66 is the most seen working (MAX_CUBES in the UI script).
 */

init()
{
    setdvarifuninitialized("showspawns", 0);
    setdvarifuninitialized("showspawns_radius", 1000);
    setdvarifuninitialized("showspawns_max", 10);
    setdvarifuninitialized("showspawns_size", 40);
    setdvarifuninitialized("showspawns_thick", 1);
    setdvarifuninitialized("showspawns_xray", 0);
    level thread update_loop();
}

/@
"Name: update_loop()"
"Summary: Hands the spawn points near the host to the UI 4 times a second while showspawns is on, once the spawn zones are set up."
"Example: level thread update_loop();"
@/
update_loop()
{
    level endon("game_ended");

    while(!scripts\engine\utility::flag_exist("init_spawn_volumes_done") || !scripts\engine\utility::flag("init_spawn_volumes_done"))
        wait 1;

    for(;;)
    {
        host = level.players[0];
        if(getdvarint("showspawns") && isdefined(host))
            set_positions(nearest_spawners(host.origin, getdvarfloat("showspawns_radius"), int(min(getdvarint("showspawns_max"), 66))));

        wait 0.25;
    }
}

/@
"Name: set_positions( <spawners> )"
"Summary: Writes the spawn points' positions, in whole units, for ui_scripts/dev_show_spawns to read, as \"x y z;x y z\" split over the dvars showspawns_data1 and showspawns_data2, 900 characters each, which holds the 66 cubes the UI draws at most, with \"none\" in an unused one. They're set on the server, where the host's UI reads them, and nothing is sent."
"MandatoryArg: <spawners>: The spawn points to draw."
"Example: set_positions( spawners );"
@/
set_positions(spawners)
{
    chunks = [];
    chunk = "";
    foreach(spawner in spawners)
    {
        spot = int(spawner.origin[0]) + " " + int(spawner.origin[1]) + " " + int(spawner.origin[2]);
        if(chunk.size + spot.size > 900)
        {
            chunks[chunks.size] = chunk;
            chunk = "";
        }

        if(chunk != "")
            chunk += ";";

        chunk += spot;
    }

    chunks[chunks.size] = chunk;

    for(i = 0; i < 2; i++)
    {
        name = "showspawns_data" + (i + 1);
        data = "none";
        if(isdefined(chunks[i]) && chunks[i] != "")
            data = chunks[i];

        if(data != getdvar(name))
            setdvar(name, data);
    }
}

/@
"Name: nearest_spawners( <origin>, <radius>, <count> )"
"Summary: Returns the spawn zones' spawn points within a flat radius of a spot, skipping removed ones: all of them in the zones' order when count allows, which keeps what's sent steady as the host moves, else the nearest count, nearest first."
"MandatoryArg: <origin>: The spot to measure from."
"MandatoryArg: <radius>: How far to look, in units."
"MandatoryArg: <count>: How many to return at most."
"Example: spawners = nearest_spawners( level.players[0].origin, 1000, 10 );"
@/
nearest_spawners(origin, radius, count)
{
    candidates = [];
    foreach(volume in level.spawn_volume_array)
    {
        if(!isdefined(volume.spawners))
            continue;

        foreach(spawner in volume.spawners)
        {
            if(!scripts\engine\utility::is_true(spawner.remove_me) && distance2d(spawner.origin, origin) <= radius)
                candidates[candidates.size] = spawner;
        }
    }

    if(candidates.size <= count)
        return candidates;

    nearest = [];
    while(nearest.size < count && candidates.size > 0)
    {
        best = 0;
        for(i = 1; i < candidates.size; i++)
        {
            if(distance2d(candidates[i].origin, origin) < distance2d(candidates[best].origin, origin))
                best = i;
        }

        nearest[nearest.size] = candidates[best];
        candidates = scripts\engine\utility::array_remove(candidates, candidates[best]);
    }

    return nearest;
}
