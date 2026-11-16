"""Builds the psychedelic Rave Vision barrier effect from the game's own effects.

Reads zonetool's dumps in dumps/, edits the barrier shimmer, adds emitters
borrowed from other Rave effects, and writes both the effect zonetool builds
into rave_barrier.ff and the list of game assets that fastfile only refers to.
"""

import colorsys
import copy
import json
from pathlib import Path

ROOT = Path(__file__).parent
DUMPS = ROOT / "dumps"
TARGET = ROOT.parent / (
    "zonetool/rave_barrier/particlesystem/vfx/iw7/core/zombie/rave/rave_barrier_fx.json"
)
IGNORE_LIST = ROOT.parent / "zone_source/rave_barrier_ignore.csv"

ASSET_TYPES = {"material": "material", "lightDef": "lightdef", "model": "xmodel"}
HAS_NON_SPRITES = 0x2
HAS_LIGHTS = 0x4
BLENDS_BOTH_CURVE_SETS = 16
USE_WORLD_SPACE = 128

#: Where the shimmer's sprites sit, relative to the spot the script places it at.
PANEL_CENTRE = [0.0, 25.0, 60.0, 0.0]


def load(name):
    """A dumped effect by file name."""
    return json.loads((DUMPS / f"{name}.json").read_text())


def curve(points, scale=1.0):
    """A curve from (time, value) pairs, with the slope helper zonetool expects."""
    control_points = []
    previous = None
    for time, value in points:
        delta = 0.0 if previous is None else 1.0 / (time - previous)
        control_points.append({"value": value, "time": time, "invTimeDelta": delta})
        previous = time
    return {"scale": scale, "ControlPoint": control_points}


def hue_curves(start, sweep, brightness):
    """Red, green and blue curves that travel `sweep` degrees of hue from `start`."""
    steps = max(2, round(abs(sweep) / 30) + 1)
    channels = ([], [], [])
    for step in range(steps):
        time = step / (steps - 1)
        hue = ((start + sweep * time) % 360) / 360
        for channel, value in zip(channels, colorsys.hsv_to_rgb(hue, 1.0, brightness)):
            channel.append((time, value))
    return [curve(points) for points in channels]


def module(emitter, name):
    """The emitter's first module of the given type."""
    for group in emitter["State"][0]["ModuleGroup"].values():
        for candidate in group.get("Module", []):
            if candidate["type"] == f"PARTICLE_MODULE_{name}":
                return candidate
    raise KeyError(name)


def recolour(emitter, first, second, sweep, brightness):
    """Shifts each particle's hue over its life, between two starting hues.

    Keeps the emitter's own opacity curves.
    """
    graph = module(emitter, "COLOR_GRAPH")
    curves = graph["Curves"]
    graph["m_flags"] = BLENDS_BOTH_CURVE_SETS
    graph["Curves"] = (
        hue_curves(first, sweep, brightness)
        + [curves[3]]
        + hue_curves(second, sweep, brightness)
        + [curves[7]]
    )


def spin(emitter, angle, rate):
    """Starts each sprite at a random angle and turns it either way, in radians."""
    rotation = module(emitter, "INIT_ROTATION")
    rotation["m_rotationAngle.min"] = -angle
    rotation["m_rotationAngle.max"] = angle
    rotation["m_rotationRate.min"] = -rate
    rotation["m_rotationRate.max"] = rate


def cycle_together(emitter, rate, alive, start, brightness):
    """Makes every sprite of the emitter the same hue at any moment.

    Sprites spawn `1 / rate` seconds apart and live long enough for `alive` of
    them to overlap. Each one runs through the whole spectrum once per spawn
    interval, so they stay in step and the layer cycles the spectrum as one,
    instead of mixing its sprites' hues into white.
    """
    life = alive / rate
    emitter["particleSpawnRate.min"] = rate
    emitter["particleSpawnRate.max"] = rate
    emitter["particleLife.min"] = life
    emitter["particleLife.max"] = life
    emitter["particleCountMax"] = alive + 1
    recolour(emitter, start, start, 360 * alive, brightness)


def loop_texture(emitter, loops):
    """Plays the sprite's animation this many times over its life."""
    module(emitter, "INIT_ATLAS")["m_loopCount"] = loops


def strobe(emitter):
    """Makes the sprites flicker 8 times over their life, at the game's own brightness."""
    pulse = [(step / 16, 1.0 if step % 2 == 0 else 0.3) for step in range(17)]
    module(emitter, "INTENSITY_GRAPH")["Curves"] = [curve(pulse, 3.0), curve(pulse, 1.0)]


def breathe(emitter):
    """Makes the sprites grow over their life instead of shrinking."""
    attributes = module(emitter, "INIT_ATTRIBUTES")
    lerp = module(emitter, "SIZE_LERP")
    for key in ("m_sizeMin.v", "m_sizeMax.v"):
        attributes[key][0:2] = [40.0, 30.0]
    lerp["m_sizeBegin.v"][0:2] = [40.0, 30.0]
    lerp["m_sizeEnd.v"][0:2] = [75.0, 56.0]


def warp(emitter):
    """Makes the distortion layer stronger, bigger and longer lived."""
    emitter["particleLife.min"] = 1.0
    emitter["particleLife.max"] = 1.4
    emitter["particleCountMax"] = 12
    attributes = module(emitter, "INIT_ATTRIBUTES")
    for key in ("m_sizeMin.v", "m_sizeMax.v"):
        attributes[key][0:2] = [96.0, 72.0]
    alpha = module(emitter, "COLOR_GRAPH")["Curves"][3]
    peak = max(point["value"] for point in alpha["ControlPoint"])
    for point in alpha["ControlPoint"]:
        point["value"] /= peak


def place(emitter, position):
    """Moves a borrowed emitter's spawn cylinder to a spot relative to the wall.

    The mushroom effects spawn in world space, which ignores the way the wall faces.
    """
    cylinder = module(emitter, "INIT_SPAWN_SHAPE_CYLINDER")
    cylinder["m_flags"] &= ~USE_WORLD_SPACE
    cylinder["m_offset.v"] = [0.0, 0.0, 0.0, 0.0]
    cylinder["unk.v"] = position + [0.0]
    cylinder["m_radius.min"] = 0.0
    cylinder["m_radius.max"] = 30.0


def sparks():
    """The mushrooms' rising sparks, spread over the panel and cycling the spectrum."""
    emitter = copy.deepcopy(load("shroom_idle_violet")["Emitter"][1])
    emitter["particleSpawnRate.min"] = 16.0
    emitter["particleSpawnRate.max"] = 16.0
    emitter["particleCountMax"] = 22
    attributes = module(emitter, "INIT_ATTRIBUTES")
    attributes["m_sizeMin.v"][0:2] = [1.0, 1.0]
    attributes["m_sizeMax.v"][0:2] = [3.5, 3.5]
    attributes["m_colorMin.v"] = [1.0, 1.0, 1.0, 1.0]
    attributes["m_colorMax.v"] = [1.0, 1.0, 1.0, 1.0]
    place(emitter, [0.0, 25.0, 30.0])
    recolour(emitter, 0, 180, 360, 1.0)
    return emitter


def smoke():
    """The mushrooms' wispy smoke, bigger, slowly turning and cycling the spectrum."""
    emitter = copy.deepcopy(load("shroom_idle_violet")["Emitter"][0])
    place(emitter, [0.0, 25.0, 55.0])
    size = module(emitter, "SIZE_GRAPH")
    for key in ("m_sizeBegin.v", "m_sizeEnd.v"):
        size[key] = [value * 4.0 for value in size[key]]
    for size_curve in size["Curves"][0:2]:
        size_curve["scale"] *= 4.0
    spin(emitter, 3.1416, 0.35)
    graph = module(emitter, "COLOR_GRAPH")
    graph["Curves"][0:3] = hue_curves(280, 360, 0.9)
    return emitter


def light():
    """The pouch's flickering light, bigger and flickering between magenta and cyan."""
    emitter = copy.deepcopy(load("rave_pouch_fx")["Emitter"][2])
    world = module(load("shroom_idle_violet")["Emitter"][0], "INIT_RELATIVE_VELOCITY")
    module(emitter, "INIT_RELATIVE_VELOCITY").update(copy.deepcopy(world))
    box = module(emitter, "INIT_SPAWN_SHAPE_BOX")
    box["m_dimensionsMin.v"] = [-8.0] + PANEL_CENTRE[1:]
    box["m_dimensionsMax.v"] = [8.0] + PANEL_CENTRE[1:]
    lerp = module(emitter, "SIZE_LERP")
    lerp["m_sizeBegin.v"][0] = 90.0
    lerp["m_sizeEnd.v"][0] = 90.0
    recolour(emitter, 300, 180, 0, 1.0)
    return emitter


def referenced_assets(node, found):
    """Collects the (type, name) of every game asset the effect points at."""
    if isinstance(node, dict):
        for entry in node.get("AssetList") or []:
            for key, name in entry.items():
                if name:
                    found.add((ASSET_TYPES[key], name))
        for value in node.values():
            referenced_assets(value, found)
    elif isinstance(node, list):
        for value in node:
            referenced_assets(value, found)
    return found


def main():
    effect = load("rave_barrier_shimmer")
    distortion, wave_a, wave_b, glitch_a, glitch_b = effect["Emitter"]

    warp(distortion)

    for emitter in (wave_a, wave_b):
        cycle_together(emitter, 1.0, 2, 300, 0.7)

    for emitter in (glitch_a, glitch_b):
        cycle_together(emitter, 1.0, 2, 60, 0.7)
        loop_texture(emitter, 8)
        spin(emitter, 0.26, 0.3)
        strobe(emitter)
        breathe(emitter)

    effect["Emitter"] += [sparks(), smoke(), light()]
    effect["flags"] |= HAS_NON_SPRITES | HAS_LIGHTS

    TARGET.parent.mkdir(parents=True, exist_ok=True)
    TARGET.write_text(json.dumps(effect, indent=4) + "\n")
    assets = sorted(referenced_assets(effect, set()))
    IGNORE_LIST.write_text("".join(f"{kind},{name}\n" for kind, name in assets))
    print(f"Wrote {TARGET}")
    print(f"Wrote {IGNORE_LIST}: {len(assets)} assets")


if __name__ == "__main__":
    main()
