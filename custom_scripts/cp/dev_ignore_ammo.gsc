/*
 * Unlimited ammo for testing: keeps every player's magazine, weapon reserves
 * and both power slots full. "!ignoreammo" in chat, or "set ignoreammo 1" and
 * "set ignoreammo 0" in the console, turns it on or off for everyone. It's off
 * by default.
 *
 * It refills the magazine the way the Infinite Ammo power-up does (loot.gsc,
 * unlimited_ammo), but also covers the Venom-X, which the power-up leaves out
 * (level.opweaponsarray in zombie.gsc).
 */

init()
{
    setdvarifuninitialized("ignoreammo", 0);
    level thread on_player_connect();
    level thread toggle_from_chat();
    level thread announce_changes();
}

/@
"Name: on_player_connect()"
"Summary: Starts the refill loop for every player who joins. The loops keep running while ignoreammo is off, so turning it back on needs no restart."
"Example: level thread on_player_connect();"
@/
on_player_connect()
{
    level endon("game_ended");

    for(;;)
    {
        level waittill("connected", player);
        player thread keep_clip_full();
    }
}

/@
"Name: toggle_from_chat()"
"Summary: Flips ignoreammo when anyone sends !ignoreammo. iw7-mod notifies say on the level for every chat message, team chat included, but can't hide the message, so the command still shows in chat."
"Example: level thread toggle_from_chat();"
@/
toggle_from_chat()
{
    level endon("game_ended");

    for(;;)
    {
        level waittill("say", player, message);

        if(toupper(message) != "!IGNOREAMMO")
            continue;

        if(getdvarint("ignoreammo") == 0)
            setdvar("ignoreammo", 1);
        else
            setdvar("ignoreammo", 0);
    }
}

/@
"Name: announce_changes()"
"Summary: Announces every change of ignoreammo to everyone. It watches the dvar rather than the chat, so changes made from the console are announced too."
"Example: level thread announce_changes();"
@/
announce_changes()
{
    level endon("game_ended");

    last = getdvarint("ignoreammo");

    for(;;)
    {
        scripts\engine\utility::waitframe();

        current = getdvarint("ignoreammo");
        if(current == last)
            continue;

        last = current;

        if(current == 0)
            iprintlnbold("ignoreammo OFF");
        else
            iprintlnbold("ignoreammo ON");
    }
}

/@
"Name: keep_clip_full()"
"Summary: The refill loop. zm_ui_unlimited_ammo is the HUD's infinite ammo icon, which the Infinite Ammo power-up also sets; turning ignoreammo off leaves the icon on while the power-up is active (has_infinite_ammo), since the power-up clears it when it ends. The left hand's magazine is the second gun of an akimbo weapon."
"CallOn: A player"
"Example: player thread keep_clip_full();"
@/
keep_clip_full()
{
    self endon("disconnect");
    level endon("game_ended");

    was_on = 0;

    for(;;)
    {
        scripts\engine\utility::waitframe();

        if(getdvarint("ignoreammo") == 0)
        {
            if(was_on && !scripts\engine\utility::is_true(self.has_infinite_ammo))
                self setclientomnvar("zm_ui_unlimited_ammo", 0);

            was_on = 0;
            continue;
        }

        was_on = 1;
        self setclientomnvar("zm_ui_unlimited_ammo", 1);

        foreach(owned in self getweaponslistprimaries())
            self setweaponammostock(owned, weaponmaxammo(owned));

        refill_grenades();

        weapon = self getcurrentweapon();
        size = weaponclipsize(weapon);
        if(size <= 0)
            continue;

        self setweaponammoclip(weapon, size, "left");
        self setweaponammoclip(weapon, size, "right");
    }
}

/@
"Name: refill_grenades()"
"Summary: Refills both power slots with power_adjustcharges, the call the Infinite Grenades power-up uses (loot.gsc, apply_infinite_grenade_effects). One call fills every power in a slot, so each slot gets at most one, and only once a power in it is below its maximum, since every call updates the HUD and notifies power_used."
"CallOn: A player"
"Example: self refill_grenades();"
@/
refill_grenades()
{
    if(!isdefined(self.powers))
        return;

    foreach(slot in ["primary", "secondary"])
    {
        foreach(name in getarraykeys(self.powers))
        {
            power = self.powers[name];
            if(power.slot != slot || !isdefined(level.powers[name]))
                continue;

            if(power.charges < level.powers[name].maxcharges)
            {
                self scripts\cp\powers\coop_powers::power_adjustcharges(undefined, slot, 1);
                break;
            }
        }
    }
}
