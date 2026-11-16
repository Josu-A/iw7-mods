/*
 * Fixes the Slasher's block. The game cuts damage to 10% while the Slasher is
 * in the "block" state, but that state only passes through to block_intro,
 * block_loop and block_outro, so the cut never applies.
 *
 * Replaces the game's onslasherdamagefinished with a copy that checks those
 * three states instead. The Slasher's functions are looked up by name, which
 * gives undefined on maps that don't load its script, so this does nothing
 * there. Referencing them directly fails to link on those maps.
 */

main()
{
    path = "scripts/mp/agents/slasher/slasher_agent";
    original = getfunction(path, "onslasherdamagefinished");
    if(!isdefined(original))
        return;

    level.blockfix_accumulatedamage = getfunction(path, "accumulatedamage");
    level.blockfix_finish = getfunction(path, "slasher_on_damage_finished");

    replacefunc(original, ::onslasherdamagefinished_stub);
}

/* The game's onslasherdamagefinished, with only the block check changed. */
onslasherdamagefinished_stub(param_00,param_01,param_02,param_03,param_04,param_05,param_06,param_07,param_08,param_09,param_0A,param_0B,param_0C)
{
    var_0D = param_02;
    if(param_05 == "iw7_harpoon_zm") {
        param_02 = min(0.1 * self.maxhealth,2000);
        param_02 = int(param_02);
    }
    else if(issubstr(param_05,"harpoon1")) {
        param_02 = min(0.01 * self.maxhealth,100);
        param_02 = int(param_02);
    }
    else if(issubstr(param_05,"harpoon2")) {
        param_02 = min(0.1 * self.maxhealth,1500);
        param_02 = int(param_02);
    }
    else if(issubstr(param_05,"harpoon3")) {
        param_02 = min(0.1 * self.maxhealth,1500);
        param_02 = int(param_02);
    }
    else if(issubstr(param_05,"harpoon4")) {
        param_02 = min(0.01 * self.maxhealth,1000);
        param_02 = int(param_02);
    }

    if(isdefined(param_05) && param_05 == "iw7_slasher_zm") {
        param_02 = param_02 * 0.1;
        param_02 = int(param_02);
    }
    else
    {
        if(self isethereal() || (isdefined(param_01.rave_mode) && param_01.rave_mode)) {
            param_02 = 0;
        }

        if(scripts\asm\asm::asm_isinstate("block_intro") || scripts\asm\asm::asm_isinstate("block_loop") || scripts\asm\asm::asm_isinstate("block_outro")) {
            param_02 = param_02 * 0.1;
            param_02 = int(param_02);
        }
    }

    if(isdefined(level.players) && level.players.size > 1) {
        if(param_02 != 0) {
            var_0E = int(param_02 / (level.players.size + 1));
            param_02 = int(max(var_0E,1));
        }
    }

    if(param_02 > 0) {
        self [[level.blockfix_accumulatedamage]](param_02,param_07);
    }

    if(isdefined(self.nodamagescale)) {
        param_02 = var_0D;
    }

    self [[level.blockfix_finish]](param_00,param_01,param_02,param_03,param_04,param_05,param_06,param_07,param_08,param_09,0,param_0B,param_0C);
}
