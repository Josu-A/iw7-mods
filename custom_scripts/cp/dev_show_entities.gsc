/*
 * Shows entity counts at the top left of the screen, drawn by
 * ui_scripts/dev_show_entities: entities in use, the highest entity number in
 * use, living agents out of the agent pool and the 6 most common classnames.
 * "set showents 1" turns it on; it's off by default.
 *
 * Scripts can't read how many entity slots are free, so it counts what
 * getentarray() returns, twice a second. It's only sent to the host, once its
 * UI script has created the showents_data dvar: a client crashes when it's sent
 * a dvar it doesn't have.
 */

init()
{
    level thread on_player_connect();
}

on_player_connect()
{
    level endon("game_ended");

    for(;;)
    {
        level waittill("connected", player);
        player thread send_counts();
    }
}

/@
"Name: send_counts()"
"Summary: Sends the counts to the host's UI in the showents_data dvar twice a second while showents is on, whenever they change."
"Example: player thread send_counts();"
@/
send_counts()
{
    self endon("disconnect");

    last = "";

    for(;;)
    {
        wait 0.5;

        if(!self ishost() || !getdvarint("showents") || getdvar("showents_data") == "")
        {
            last = "";
            continue;
        }

        data = counts();
        if(data == last)
            continue;

        last = data;
        self setclientdvar("showents_data", data);
    }
}

/@
"Name: counts()"
"Summary: Returns the counts as \"entities highest alive pool class=count ...\", the classnames most common first."
"Example: data = counts();"
@/
counts()
{
    entities = getentarray();
    highest = 0;
    classes = [];

    foreach(entity in entities)
    {
        number = entity getentitynumber();
        if(number > highest)
            highest = number;

        class = "?";
        if(isdefined(entity.classname))
            class = entity.classname;

        if(!isdefined(classes[class]))
            classes[class] = 0;

        classes[class]++;
    }

    alive = 0;
    pool = 0;
    if(isdefined(level.agentarray))
    {
        alive = scripts\mp\mp_agent::getaliveagents().size;
        pool = level.agentarray.size;
    }

    data = entities.size + " " + highest + " " + alive + " " + pool;

    names = getarraykeys(classes);
    for(i = 0; i < 6 && names.size > 0; i++)
    {
        best = 0;
        for(j = 1; j < names.size; j++)
        {
            if(classes[names[j]] > classes[names[best]])
                best = j;
        }

        data += " " + names[best] + "=" + classes[names[best]];
        names = scripts\engine\utility::array_remove(names, names[best]);
    }

    return data;
}
