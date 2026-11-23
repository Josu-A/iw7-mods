/*
 * Sends the host's position, rounded to whole units, to
 * ui_scripts/dev_show_origin, which draws it at the top of the screen.
 *
 * Toggled with the showorigin dvar from the console: "set showorigin 1" shows
 * it, "set showorigin 0" hides it. It's off by default.
 *
 * The position goes out in the showorigin_pos dvar as "x y z", 10 times a
 * second while it changes. A client crashes when it's sent a dvar it doesn't
 * have, so it's only sent to the host, and only once the UI script has created
 * the dvar, which the host's game shares with the server.
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
        player thread send_origin();
    }
}

send_origin()
{
    self endon("disconnect");

    last = "";

    for(;;)
    {
        wait 0.1;

        if(!self ishost() || !getdvarint("showorigin") || getdvar("showorigin_pos") == "")
        {
            last = "";
            continue;
        }

        position = int(self.origin[0]) + " " + int(self.origin[1]) + " " + int(self.origin[2]);
        if(position == last)
            continue;

        last = position;
        self setclientdvar("showorigin_pos", position);
    }
}
