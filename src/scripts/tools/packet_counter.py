#!/usr/bin/env python

import time, os, decimal, subprocess

def packetc():
    """Counts the packets number"""
    while True:
        t = subprocess.check_output('${SUME_SDNET}/sw/sume/rwaxi -a 0x44030000', shell=True)
        data = int((t.split())[3], 16)

        print("Count = "+ str(data))
        time.sleep(1)

def main():
    packetc()

if __name__ == "__main__":
    main()
