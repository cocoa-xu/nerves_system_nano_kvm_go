"""Makes the firmware file of Linux's panel-mipi-dbi from a command list.

  python3 mipi_dbi_cmd.py <commands.txt> <firmware.bin>
"""

import sys

MAGIC = b"MIPI DBI" + bytes(7)
VERSION = 1

out = bytearray(MAGIC + bytes([VERSION]))
for line in open(sys.argv[1]):
    words = line.split("#")[0].split()
    if not words:
        continue
    if words[0] == "delay":
        out += bytes([0x00, 1, int(words[1])])
    else:
        command, *parameters = (int(w, 0) for w in words)
        out += bytes([command, len(parameters), *parameters])
open(sys.argv[2], "wb").write(out)
