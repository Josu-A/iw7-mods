/*
 * Fixes the 4 zombie spawn points in Rave in the Redwoods that drop under the
 * map, whose zombies die straight away below it and count as kills.
 *
 * At load the game moves every ground spawn point onto the ground below it
 * (zombies_spawning.gsc's _id_5D13 traces from 10 units above it down to
 * -12000). At these 4 the trace finds nothing near and stops at about z -3060:
 * the 2 in the spawn cabin stand on floors the trace goes through, and one by
 * the campfire on the path from Mess Hall is placed below the terrain, so the
 * trace starts underground.
 */

init()
{
    if(getdvar("ui_mapname") != "cp_rave")
        return;

    level thread fix_spawners();
}

/@
"Name: fix_spawners()"
"Summary: Waits for the game to drop its ground spawn points, then puts the 4 that dropped under the map back on the ground. Their positions are the map's (cp_rave.d3dbsp.ents:6400, 6242, 9102 and 9903)."
"Example: level thread fix_spawners();"
@/
fix_spawners()
{
    level endon("game_ended");

    while(!scripts\engine\utility::flag_exist("init_spawn_volumes_done") || !scripts\engine\utility::flag("init_spawn_volumes_done"))
        scripts\engine\utility::waitframe();

    scripts\engine\utility::waitframe();

    spots = [(-1371.8, -1039.9, 232), (-806.8, -2452.6, 400), (-3877.4, -515.6, -57.5), (-3671.7, -959.3, 66.6)];
    spawners = scripts\engine\utility::getstructarray("static", "script_noteworthy");

    foreach(spot in spots)
    {
        foreach(spawner in spawners)
        {
            if(distance2d(spawner.origin, spot) < 1 && spawner.origin[2] < spot[2] - 1000)
                spawner.origin = ground_near(spot);
        }
    }
}

/@
"Name: ground_near( <spot> )"
"Summary: Returns a point 1 unit above the ground near a spot, found by tracing down with player collision from higher and higher above it, doubling from 32 units to 4096, until the trace lands within 64 units of the spot's height. If it never does, returns the nearest point on the navmesh, or the spot itself if there's none."
"MandatoryArg: <spot>: Where the map places the spawn point."
"Example: spawner.origin = ground_near( (-1371.8, -1039.9, 232) );"
@/
ground_near(spot)
{
    for(height = 32; height <= 4096; height *= 2)
    {
        end = spot - (0, 0, 64);
        hit = playerphysicstrace(spot + (0, 0, height), end);
        if(hit[2] > end[2] + 0.1 && abs(hit[2] - spot[2]) <= 64)
            return hit + (0, 0, 1);
    }

    navmesh = getclosestpointonnavmesh(spot);
    if(isdefined(navmesh))
        return navmesh;

    return spot;
}
