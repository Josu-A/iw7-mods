/*
 * Restores Rave in the Redwoods' free Kendall 44 wall buy in the spawn room,
 * which the game disables because Rave's weapon table doesn't list the
 * Kendall 44 as a wall weapon.
 */

init()
{
    if(getdvar("ui_mapname") != "cp_rave")
        return;

    level thread add_kendall_wall_buy();
}

/@
"Name: add_kendall_wall_buy()"
"Summary: Adds the Kendall 44 as a wall weapon once the table has been read, which the cryo grenade's entry signals. _id_138A1 is wall_buys and _id_DB01 is purchase_type, names iw7-mod 1.1.0's compiler doesn't have."
"Example: level thread add_kendall_wall_buy();"
@/
add_kendall_wall_buy()
{
    while(!isdefined(level._id_138A1) || !isdefined(level._id_138A1["zfreeze_semtex_mp"]))
        scripts\engine\utility::waitframe();

    kendall = spawnstruct();
    kendall.weapon = "iw7_g18_zmr";
    kendall.model = getweaponmodel("iw7_g18_zmr");
    kendall._id_DB01 = "wall";
    level._id_138A1["g18"] = kendall;
}
