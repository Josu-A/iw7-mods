/*
 * Teleports a player for testing: "!tp -619 -1933 72" in chat moves whoever
 * typed it, and "set teleport -619 -1933 72" in the console moves the host.
 * Coordinates are game units, the ones dev_show_origin shows and the wiki's
 * map places its markers at.
 */

init()
{
    setdvarifuninitialized("teleport", "");
    level thread watch_dvar();
    level thread watch_chat();
}

/@
"Name: watch_dvar()"
"Summary: Teleports the host to coordinates set from the console. The dvar is cleared once applied, so the same spot can be asked for again."
"Example: level thread watch_dvar();"
@/
watch_dvar()
{
    level endon("game_ended");

    for(;;)
    {
        scripts\engine\utility::waitframe();

        coordinates = getdvar("teleport");
        if(coordinates == "")
            continue;

        setdvar("teleport", "");
        teleport_player(level.players[0], strtok(coordinates, " "));
    }
}

/@
"Name: watch_chat()"
"Summary: Teleports a player who asks with !tp in chat. iw7-mod notifies say on the level for every chat message, team chat included."
"Example: level thread watch_chat();"
@/
watch_chat()
{
    level endon("game_ended");

    for(;;)
    {
        level waittill("say", player, message);

        words = strtok(message, " ");
        if(words.size == 0 || toupper(words[0]) != "!TP")
            continue;

        coordinates = [];
        for(i = 1; i < words.size; i++)
            coordinates[coordinates.size] = words[i];

        teleport_player(player, coordinates);
    }
}

/@
"Name: teleport_player( <player>, <coordinates> )"
"Summary: Moves a player to a spot, keeping where they look. The spot isn't checked: a z below the ground drops them out of the map, so use one at or above it, like the z dev_show_origin shows standing there. A marker's z on the wiki's map is its struct's, which can sit inside the floor or a wall."
"MandatoryArg: <player>: The player to move."
"MandatoryArg: <coordinates>: x, y and z, as text."
"Example: teleport_player( player, strtok( "-619 -1933 72", " " ) );"
@/
teleport_player(player, coordinates)
{
    if(coordinates.size != 3)
    {
        player iprintlnbold("Use: !tp <x> <y> <z>");
        return;
    }

    spot = (float(coordinates[0]), float(coordinates[1]), float(coordinates[2]));
    player setorigin(spot);
    player iprintlnbold("Teleported to " + spot);
}
