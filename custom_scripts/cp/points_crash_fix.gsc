/*
 * Stops notify queues from crashing the game with "Exceeded maximum number of
 * script variables (children)".
 *
 * scripts\cp\utility::add_to_notify_queue() delays each notify by 0.05 seconds
 * per entry already waiting, so a queue releases about 20 a second, and every
 * waiting entry is a live thread holding script variables. Nothing caps a
 * queue, so anything that queues faster, like points from hitting a horde with
 * a fast-firing gun or the Katana's chained hits in Shaolin Shuffle, fills the
 * child variable pool until the game crashes.
 *
 * This replaces add_to_notify_queue() with the same function plus two changes:
 *   - player_earned_money is notified straight away instead of queued. No
 *     script waits for it, so play doesn't change.
 *   - Any other queue stops taking entries once QUEUE_CAP are waiting, and the
 *     console says so once per queue. The Katana's chain still works, but it
 *     can no longer grow without limit.
 *
 * Every points award also goes through scripts\cp\utility::bufferednotify()
 * as currency_earned_buffered, which the money earned contract waits for. Its
 * list sends one entry per frame and rebuilds the whole array each time, so a
 * long list ends up needing more free slots on one block than there are. This
 * replaces bufferednotify_internal() too, adding a new award's points to the
 * last waiting entry instead of adding an entry: the contract still gets the
 * same total, and the list never grows.
 *
 * The functions are looked up by name, so this does nothing where
 * scripts/cp/utility isn't loaded.
 */

/*
 * How many entries a queue other than player_earned_money can have waiting
 * before new ones are dropped.
 */
#define QUEUE_CAP 200

main()
{
    original = getfunction("scripts/cp/utility", "add_to_notify_queue");
    if(!isdefined(original))
        return;

    replacefunc(original, ::add_to_notify_queue);

    buffered = getfunction("scripts/cp/utility", "bufferednotify_internal");
    if(isdefined(buffered))
        replacefunc(buffered, ::bufferednotify_internal);
}

/@
"Name: add_to_notify_queue( <name>, <a>, <b>, <c>, <d>, <e>, <f>, <g>, <h> )"
"Summary: The game's add_to_notify_queue() with player_earned_money sent at once and every other queue capped at QUEUE_CAP waiting entries."
"MandatoryArg: <name>: The notify to send."
"OptionalArg: <a> to <h>: The notify's arguments."
"Example: player thread scripts\cp\utility::add_to_notify_queue( "katana_melee_hit", weapon, zombie, damage );"
@/
add_to_notify_queue(name, a, b, c, d, e, f, g, h)
{
    if(name == "player_earned_money")
    {
        self notify(name, a, b, c, d, e, f, g, h);
        return;
    }

    if(!isdefined(self.notify_queue))
        self.notify_queue = [];

    if(!isdefined(self.notify_queue[name]))
        self.notify_queue[name] = 0;
    else
    {
        if(name == "weapon_hit_enemy")
        {
            now = gettime();

            if(isdefined(self.last_notify_time) && self.last_notify_time == now)
                return;

            self.last_notify_time = now;
        }

        if(self.notify_queue[name] >= QUEUE_CAP)
        {
            report_cap(name);
            return;
        }

        self.notify_queue[name]++;
    }

    if(self.notify_queue[name] > 0)
        wait(0.05 * self.notify_queue[name]);

    self notify(name, a, b, c, d, e, f, g, h);
    waittillframeend;

    if(isdefined(self.notify_queue[name]))
    {
        self.notify_queue[name]--;

        if(self.notify_queue[name] < 1)
            self.notify_queue[name] = undefined;
    }
}

/@
"Name: report_cap( <name> )"
"Summary: Prints to the console the first time a queue drops entries for being full."
"MandatoryArg: <name>: The full queue's notify."
"Example: report_cap( "katana_melee_hit" );"
@/
report_cap(name)
{
    if(!isdefined(level.points_crash_fix_capped))
        level.points_crash_fix_capped = [];

    if(isdefined(level.points_crash_fix_capped[name]))
        return;

    level.points_crash_fix_capped[name] = 1;
    PrintLn("points_crash_fix: " + name + " reached " + QUEUE_CAP + " waiting entries, dropping new ones");
}

/@
"Name: bufferednotify_internal( <name>, <a>, <b>, <c>, <d>, <e>, <f>, <g>, <h>, <i> )"
"Summary: The game's bufferednotify_internal() with currency_earned_buffered points added to the last waiting entry when there is one. Every entry still in the list hasn't been sent yet, and returning early leaves the thread already sending them running."
"MandatoryArg: <name>: The notify to send."
"OptionalArg: <a> to <i>: The notify's arguments."
"Example: self thread bufferednotify_internal( "currency_earned_buffered", 10 );"
@/
bufferednotify_internal(name, a, b, c, d, e, f, g, h, i)
{
    self endon("disconnect");
    level endon("game_ended");

    if(name == "currency_earned_buffered" && isdefined(self.bufferednotifications) && isdefined(self.bufferednotifications[name]) && self.bufferednotifications[name].size > 0)
    {
        waiting = self.bufferednotifications[name];
        last = waiting[waiting.size - 1];
        last.param1 = last.param1 + a;
        return;
    }

    restart = "bufferedNotify_" + name;
    self notify(restart);
    self endon(restart);

    if(!isdefined(self.bufferednotifications))
        self.bufferednotifications = [];

    if(!isdefined(self.bufferednotifications[name]))
        self.bufferednotifications[name] = [];

    entry = spawnstruct();
    entry.param1 = a;
    entry.param2 = b;
    entry.param3 = c;
    entry.param4 = d;
    entry.param5 = e;
    entry.param6 = f;
    entry.param7 = g;
    entry.param8 = h;
    entry.param9 = i;
    self.bufferednotifications[name][self.bufferednotifications[name].size] = entry;
    waittillframeend;

    while(self.bufferednotifications[name].size > 0)
    {
        entry = self.bufferednotifications[name][0];
        self notify(name, entry.param1, entry.param2, entry.param3, entry.param4, entry.param5, entry.param6, entry.param7, entry.param8, entry.param9);
        self.bufferednotifications[name] = scripts\cp\utility::array_remove_index(self.bufferednotifications[name], 0);
        wait 0.05;
    }
}
