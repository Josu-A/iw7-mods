/*
 * Fixes the 4 zombie spawn points in Rave in the Redwoods that drop under the
 * map, whose zombies die straight away below it and count as kills.
 *
 * At load the game moves every ground spawn point onto the ground below it
 * (zombies_spawning.gsc's _id_5D13 traces from 10 units above it down to
 * -12000). At these 4 the trace finds nothing near and stops at about z -3060:
 * the 2 in the spawn cabin stand on floors the trace goes through, and the 2
 * in the Camper to lake zone are placed below the terrain, so the trace starts
 * underground.
 *
 * A trace with player collision from above finds the ground at all 4. For 3
 * it's right by where the map places them. The 4th, by the campfire on the
 * path from Mess Hall, is about 275 units under a hill, on which zombies rise
 * and walk down to the path.
 */

/*
 * All in units. A spawn point counts as dropped when it's within SAME_SPOT of
 * where the map places it, seen from above, and more than DROPPED below that.
 *
 * The search for its ground traces down from MIN_HEIGHT above that place, then
 * from twice as high each time up to MAX_HEIGHT. Every trace ends MAX_BELOW
 * under the place, and one that stops less than SLACK short of its end found
 * nothing. A landing counts when it's no more than MAX_ABOVE over the place,
 * and the spawn point goes LIFT above it.
 */
#define SAME_SPOT 1
#define DROPPED 1000
#define MIN_HEIGHT 32
#define MAX_HEIGHT 4096
#define MAX_BELOW 64
#define MAX_ABOVE 512
#define SLACK 0.1
#define LIFT 1

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
            if(distance2d(spawner.origin, spot) < SAME_SPOT && spawner.origin[2] < spot[2] - DROPPED)
                spawner.origin = ground_near(spot);
        }
    }
}

/@
"Name: ground_near( <spot> )"
"Summary: Returns a point just above the ground near a spot, found by tracing down with player collision from higher and higher above it, doubling each time, until a trace lands in reach. If none does, returns the spot itself. The file's constants set the distances."
"MandatoryArg: <spot>: Where the map places the spawn point."
"Example: spawner.origin = ground_near( (-1371.8, -1039.9, 232) );"
@/
ground_near(spot)
{
    for(height = MIN_HEIGHT; height <= MAX_HEIGHT; height *= 2)
    {
        end = spot - (0, 0, MAX_BELOW);
        hit = playerphysicstrace(spot + (0, 0, height), end);
        if(hit[2] > end[2] + SLACK && hit[2] - spot[2] <= MAX_ABOVE)
            return hit + (0, 0, LIFT);
    }

    return spot;
}
