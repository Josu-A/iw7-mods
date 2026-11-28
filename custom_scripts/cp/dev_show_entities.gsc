/*
 * Shows entity counts at the top left of the screen, drawn by
 * ui_scripts/dev_show_entities: entities in use, the highest entity number in
 * use, living agents out of the agent pool, the host's waiting notify queues
 * and the 24 most common classnames. "set showents 1" turns it on; it's off by
 * default.
 *
 * The queues are the ones scripts\cp\utility::add_to_notify_queue() keeps in
 * self.notify_queue, such as player_earned_money and katana_melee_hit. Each
 * waiting entry is a live thread, so a queue that keeps growing fills the
 * engine's script variable pool and crashes the game.
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

        data = self counts();
        if(data == last)
            continue;

        last = data;
        self setclientdvar("showents_data", data);
    }
}

/@
"Name: counts()"
"Summary: Returns the counts as \"entities highest alive pool @queue=waiting ... class=count ...\", with the player's waiting notify queues, then the classnames most common first."
"Example: data = self counts();"
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

    if(isdefined(self.notify_queue))
    {
        foreach(name in getarraykeys(self.notify_queue))
            data += " @" + name + "=" + (self.notify_queue[name] + 1);
    }

    names = getarraykeys(classes);
    for(i = 0; i < 24 && names.size > 0; i++)
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
