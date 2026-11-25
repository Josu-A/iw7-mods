/*
 * Draws a wireframe cube on each zombie spawn point the spawn zones use near
 * the host. "set showspawns 1" turns it on; it's off by default.
 *   showspawns_radius   flat distance from the host (1000)
 *   showspawns_max      most cubes drawn, nearest first (10)
 *   showspawns_size     cube width in units (40)
 *   showspawns_refresh  seconds between redraws, in 0.05 steps (0.3)
 *
 * Retail builds can't draw debug lines, so each edge is the blue_ark_beam
 * effect, which lasts about a third of a second and is redrawn to stay on
 * screen. Too many effects in one frame disconnect the game, hence the cap and
 * spreading each redraw over frames.
 */

init()
{
    setdvarifuninitialized("showspawns", 0);
    setdvarifuninitialized("showspawns_radius", 1000);
    setdvarifuninitialized("showspawns_max", 10);
    setdvarifuninitialized("showspawns_size", 40);
    setdvarifuninitialized("showspawns_refresh", 0.3);
    level thread draw_loop();
}

/@
"Name: draw_loop()"
"Summary: Redraws the cubes near the host every showspawns_refresh seconds while showspawns is on, once the spawn zones are set up."
"Example: level thread draw_loop();"
@/
draw_loop()
{
    level endon("game_ended");

    while(!scripts\engine\utility::flag_exist("init_spawn_volumes_done") || !scripts\engine\utility::flag("init_spawn_volumes_done"))
        wait 1;

    for(;;)
    {
        host = level.players[0];
        if(!getdvarint("showspawns") || !isdefined(host) || !isdefined(level._effect["blue_ark_beam"]))
        {
            wait 0.25;
            continue;
        }

        half = getdvarfloat("showspawns_size") / 2;
        edges = [];
        foreach(spawner in nearest_spawners(host.origin, getdvarfloat("showspawns_radius"), getdvarint("showspawns_max")))
            edges = scripts\engine\utility::array_combine(edges, cube_edges(spawner.origin, half));

        frames = int(max(getdvarfloat("showspawns_refresh") / 0.05, 1));
        for(frame = 0; frame < frames; frame++)
        {
            for(i = frame; i < edges.size; i += frames)
                draw_edge(edges[i][0], edges[i][1]);

            scripts\engine\utility::waitframe();
        }
    }
}

/@
"Name: nearest_spawners( <origin>, <radius>, <count> )"
"Summary: Returns the spawn zones' spawn points within a flat radius of a spot, nearest first, skipping removed ones."
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

/@
"Name: cube_edges( <centre>, <half> )"
"Summary: Returns the 12 edges of an axis-aligned cube, each as its two corners."
"MandatoryArg: <centre>: The cube's centre."
"MandatoryArg: <half>: Half the cube's width."
"Example: edges = cube_edges( spawner.origin, 20 );"
@/
cube_edges(centre, half)
{
    corners = [];
    for(i = 0; i < 8; i++)
    {
        x = half;
        if(i & 1)
            x = -half;

        y = half;
        if(i & 2)
            y = -half;

        z = half;
        if(i & 4)
            z = -half;

        corners[i] = centre + (x, y, z);
    }

    edges = [];
    for(i = 0; i < 8; i++)
    {
        for(bit = 1; bit < 8; bit *= 2)
        {
            if(!(i & bit))
                edges[edges.size] = [corners[i], corners[i | bit]];
        }
    }

    return edges;
}

/@
"Name: draw_edge( <start>, <end> )"
"Summary: Stretches the blue_ark_beam effect from one point to another."
"MandatoryArg: <start>: Where the beam starts."
"MandatoryArg: <end>: Where it ends."
"Example: draw_edge( (0, 0, 0), (0, 0, 40) );"
@/
draw_edge(start, end)
{
    playfxbetweenpoints(level._effect["blue_ark_beam"], start, vectortoangles(end - start), end);
}
