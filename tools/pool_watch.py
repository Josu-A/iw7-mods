"""Watches how full the game's script variable pools are while it runs.

The game crashes with "Exceeded maximum number of script variables (children)"
when it runs out of child variables, and scripts can't read how full the pools
are. This reads them straight out of the running game's memory, read-only, and
prints how many entries are in use once a second.

The pools are scr_VarGlob, at the address iw7-mod uses
(src/client/game/symbols.hpp in its source). Its structs.hpp declares 384,000
child variables, but dumps of a running game show the children in use are 4
blocks of 40,960, one per parent id & 3, as iw7-mod's code indexes them
(0xA000 * (parent_id & 3)). The crash comes when the block a new variable needs
is full, so each block is shown. A free entry's type is 24 (VAR_FREE), and an
object's type is the low 5 bits of its "w" field.

Reading another process's memory needs root while the kernel's
yama/ptrace_scope is 1: run it with "sudo python3 tools/pool_watch.py".
"""

import argparse
import sys
import time
from pathlib import Path

#: Where the game's image is meant to be loaded, which iw7-mod's addresses assume.
IMAGE_BASE = 0x140000000
#: scr_VarGlob's address with the image at IMAGE_BASE.
VAR_GLOB = 0x146691180

FREE = 24

OBJECT_COUNT = 40960
OBJECT_SIZE = 8
#: Offset of the object's type (its "w" field) within an entry.
OBJECT_TYPE_AT = 4

CHILD_BLOCKS = 4
CHILD_BLOCK_COUNT = 40960
CHILD_SIZE = 24
#: Offset of the child's type byte within an entry.
CHILD_TYPE_AT = 10
#: Where the child entries start, after the objects, their child lists and the hash buckets.
CHILDREN_AT = OBJECT_COUNT * OBJECT_SIZE + OBJECT_COUNT * 4 + 65536 * 2

#: How much --dump saves: scr_VarGlob as structs.hpp declares it, plus 1 MiB.
DUMP_SIZE = CHILDREN_AT + 384000 * CHILD_SIZE + 0x100000


def find_game():
    """The pid of the process that has memory mapped at scr_VarGlob, or None."""
    for entry in Path("/proc").iterdir():
        if not entry.name.isdigit():
            continue
        try:
            if "iw7" not in (entry / "cmdline").read_bytes().decode(errors="ignore").lower():
                continue
            if maps_contain(int(entry.name), VAR_GLOB):
                return int(entry.name)
        except OSError:
            continue
    return None


def maps_contain(pid, address):
    """Whether the process has memory mapped at the address."""
    for line in Path(f"/proc/{pid}/maps").read_text().splitlines():
        start, end = (int(part, 16) for part in line.split()[0].split("-"))
        if start <= address < end:
            return True
    return False


def read(memory, address, size):
    """Bytes read from the game's memory."""
    memory.seek(address)
    return memory.read(size)


def used_children(children):
    """How many entries are in use in each child block."""
    block_size = CHILD_BLOCK_COUNT * CHILD_SIZE
    return [
        CHILD_BLOCK_COUNT
        - children[block * block_size + CHILD_TYPE_AT : (block + 1) * block_size : CHILD_SIZE].count(FREE)
        for block in range(CHILD_BLOCKS)
    ]


def used_objects(objects):
    """How many object entries are in use."""
    return sum(
        1
        for at in range(OBJECT_TYPE_AT, OBJECT_COUNT * OBJECT_SIZE, OBJECT_SIZE)
        if objects[at] & 0x1F != FREE
    )


def main():
    """Finds the game, then prints the pools' use once a second until it closes."""
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--pid", type=int, help="the game's process id, found by itself if left out")
    parser.add_argument("--interval", type=float, default=1.0, help="seconds between reads")
    parser.add_argument("--dump", type=Path, help="save the raw scr_VarGlob block to this file and stop")
    arguments = parser.parse_args()

    pid = arguments.pid or find_game()
    if pid is None:
        sys.exit("No running game has memory at scr_VarGlob. Start a map first, or pass --pid.")
    if not maps_contain(pid, VAR_GLOB):
        sys.exit(f"Process {pid} has nothing mapped at {VAR_GLOB:#x}: the game image isn't at {IMAGE_BASE:#x}.")

    try:
        memory = open(f"/proc/{pid}/mem", "rb", buffering=0)
    except PermissionError:
        sys.exit("Not allowed to read the game's memory: run this with sudo.")

    if arguments.dump:
        with memory:
            data = read(memory, VAR_GLOB, DUMP_SIZE)
        arguments.dump.write_bytes(data)
        arguments.dump.chmod(0o644)
        print(f"Saved {len(data):,} bytes from {VAR_GLOB:#x} to {arguments.dump}.")
        return

    print(f"Watching process {pid}, scr_VarGlob at {VAR_GLOB:#x}. Ctrl+C to stop.")
    print(f"Children: {CHILD_BLOCKS} blocks of {CHILD_BLOCK_COUNT:,}. Objects: {OBJECT_COUNT:,}.")
    previous = None
    with memory:
        while True:
            try:
                objects = read(memory, VAR_GLOB, OBJECT_COUNT * OBJECT_SIZE)
                children = read(
                    memory, VAR_GLOB + CHILDREN_AT, CHILD_BLOCKS * CHILD_BLOCK_COUNT * CHILD_SIZE
                )
            except OSError:
                print("The game closed.")
                return

            blocks = used_children(children)
            total = sum(blocks)
            object_count = used_objects(objects)
            change = 0 if previous is None else total - previous
            previous = total
            fullest = max(blocks)

            print(
                f"{time.strftime('%H:%M:%S')}"
                f"  children {total:>6} ({total / (CHILD_BLOCKS * CHILD_BLOCK_COUNT):.1%}, {change:+})"
                f"  fullest block {fullest / CHILD_BLOCK_COUNT:.1%}"
                f"  blocks {' '.join(f'{used:>5}' for used in blocks)}"
                f"  objects {object_count:>5} ({object_count / OBJECT_COUNT:.1%})",
                flush=True,
            )
            time.sleep(arguments.interval)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        pass
