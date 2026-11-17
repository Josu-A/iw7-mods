/*
 * Restores the Slasher's ground pound. The game has the attack, its animation
 * state and its damage, and gives it a 30% chance in meleeattackchance, but
 * trymeleeattacks only ever picks the spin or the swipe, so it never happens.
 *
 * Replaces trymeleeattacks with a copy that rolls the ground pound's chance
 * after the spin's, and moves the saw to the Slasher's wrist while it ground
 * pounds. The Slasher's functions are looked up by name, which gives
 * undefined on maps that don't load its scripts, so this does nothing there.
 */

main()
{
    original = getfunction("scripts/aitypes/slasher/behaviors", "trymeleeattacks");
    if(!isdefined(original))
        return;

    level.groundpound_getenemy = getfunction("scripts/mp/agents/slasher/slasher_agent", "getenemy");
    level.groundpound_gettunedata = getfunction("scripts/mp/agents/slasher/slasher_tunedata", "gettunedata");

    replacefunc(original, ::trymeleeattacks_stub);

    level.groundpound_setaction = getfunction("scripts/asm/slasher/slasher_asm", "setslasheraction");
    level.groundpound_clearaction = getfunction("scripts/asm/slasher/slasher_asm", "clearslasheraction");
    level.groundpound_waitsetup = getfunction("scripts/aitypes/slasher/bt_state_api", "asm_wait_state_setup");
    level.groundpound_transition = getfunction("scripts/aitypes/slasher/bt_state_api", "btstate_transitionstate");
    level.groundpound_defaultkilled = getfunction("scripts/mp/mp_agent", "default_on_killed");

    replacefunc(getfunction("scripts/aitypes/slasher/behaviors", "groundpoundattack_begin"), ::groundpoundattack_begin_stub);
    replacefunc(getfunction("scripts/aitypes/slasher/behaviors", "groundpoundattack_end"), ::groundpoundattack_end_stub);
    replacefunc(getfunction("scripts/mp/agents/slasher/slasher_agent", "onslasherkilled"), ::onslasherkilled_stub);
}

/*
 * The game's groundpoundattack_begin, moving the saw to the wrist for the
 * attack. The ground pound animation doesn't move the weapon bone the saw
 * hangs from, so the saw would float where that bone rests.
 */
groundpoundattack_begin_stub(param_00)
{
    self detach("weapon_zmb_slasher_vm", "tag_weapon_right");
    self attach("weapon_zmb_slasher_vm", "j_wrist_ri");
    self.groundpound_saw_on_wrist = 1;

    self [[level.groundpound_setaction]]("ground_pound");
    self clearpath();
    self [[level.groundpound_waitsetup]](param_00, "slam", "ground_pound");
    self [[level.groundpound_transition]](param_00, "slam");
}

/* The game's groundpoundattack_end, putting the saw back on the weapon bone. */
groundpoundattack_end_stub(param_00)
{
    move_saw_back();
    self [[level.groundpound_clearaction]]();
}

/*
 * The game's onslasherkilled, which detaches the saw from the weapon bone and
 * would fail if the Slasher died mid ground pound with the saw on its wrist.
 */
onslasherkilled_stub(param_00, param_01, param_02, param_03, param_04, param_05, param_06, param_07, param_08)
{
    move_saw_back();
    self detach("weapon_zmb_slasher_vm", "tag_weapon_right");
    self.nocorpse = 1;
    self [[level.groundpound_defaultkilled]](param_00, param_01, param_02, param_03, param_04, param_05, param_06, param_07, param_08);
}

move_saw_back()
{
    if(!isdefined(self.groundpound_saw_on_wrist))
        return;

    self.groundpound_saw_on_wrist = undefined;
    self detach("weapon_zmb_slasher_vm", "j_wrist_ri");
    self attach("weapon_zmb_slasher_vm", "tag_weapon_right");
}

/* The game's trymeleeattacks, with the ground pound roll added before the swipe. */
trymeleeattacks_stub(param_00)
{
    var_01 = self [[level.groundpound_getenemy]]();
    if(!isdefined(param_00))
        param_00 = distancesquared(self.origin, var_01.origin);

    var_02 = [[level.groundpound_gettunedata]]();
    if(param_00 > var_02.ground_pound_radius_sq)
        return 0;

    var_03 = 0;
    if(!ispointonnavmesh(var_01.origin))
    {
        if(param_00 > self.meleeradiuswhentargetnotonnavmesh * self.meleeradiuswhentargetnotonnavmesh)
            var_03 = 1;
    }
    else if(param_00 > self.meleeradiusbasesq)
        var_03 = 1;

    if(var_03)
        return 0;

    var_04 = var_01.origin - self.origin;
    var_04 = (var_04[0], var_04[1], 0);
    var_05 = anglestoforward(self.angles);
    var_06 = vectornormalize(var_04);
    var_07 = vectordot(var_05, var_06);

    if(var_07 < self.meleedot)
    {
        self.desiredaction = "melee_spin";
        return 1;
    }

    if(randomint(100) < self.meleeattackchance["melee_spin"])
    {
        self.desiredaction = "melee_spin";
        return 1;
    }

    if(randomint(100) < self.meleeattackchance["ground_pound"])
    {
        self.desiredaction = "ground_pound";
        return 1;
    }

    self.desiredaction = "swipe_attack";
    return 1;
}
