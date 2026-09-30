#!/usr/bin/env python3
"""Measure what a running Desktop Widget Control costs.

    tools/measure.py PID [SECONDS]

Samples /proc/PID every second for SECONDS (default 30) and prints the mean and
peak CPU use (percent of one core) and the resident memory at the end. It only
sees the process itself, not the compositor's or the GPU's share, so read it
as "what the shell costs", and measure with your own widgets on your own
machine; the numbers in the README are one machine's.

Find the PID with:  pgrep -f 'desktop-widget-control|Main.qml'
"""
import os
import sys
import time

HZ = os.sysconf("SC_CLK_TCK")


def cpu_ticks(pid):
    with open(f"/proc/{pid}/stat") as f:
        rest = f.read().rsplit(")", 1)[1].split()
    return int(rest[11]) + int(rest[12])      # utime + stime


def rss_mb(pid):
    with open(f"/proc/{pid}/status") as f:
        for line in f:
            if line.startswith("VmRSS:"):
                return int(line.split()[1]) / 1024
    return 0.0


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    pid = int(sys.argv[1])
    seconds = int(sys.argv[2]) if len(sys.argv) > 2 else 30
    samples = []
    last = cpu_ticks(pid)
    for _ in range(seconds):
        time.sleep(1)
        now = cpu_ticks(pid)
        samples.append((now - last) / HZ * 100)
        last = now
    mean = sum(samples) / len(samples)
    print(f"{seconds}s  cpu mean {mean:.1f}%  peak {max(samples):.0f}%  rss {rss_mb(pid):.0f} MB")


main()
