#!/usr/bin/env python

#
# Copyright (c) 2017 Stephen Ibanez
# All rights reserved.
#
# This software was developed by Stanford University and the University of Cambridge Computer Laboratory
# under National Science Foundation under Grant No. CNS-0855268,
# the University of Cambridge Computer Laboratory under EPSRC INTERNET Project EP/H040536/1 and
# by the University of Cambridge Computer Laboratory under DARPA/AFRL contract FA8750-11-C-0249 ("MRC2"),
# as part of the DARPA MRC research programme.
#

# All rights reserved.
#


#
# Description:
#              Adapted to run in PvS architecture
# Create Date:
#              31.05.2019
#
# @NETFPGA_LICENSE_HEADER_START@
#
# Licensed to NetFPGA C.I.C. (NetFPGA) under one or more contributor
# license agreements.  See the NOTICE file distributed with this work for
# additional information regarding copyright ownership.  NetFPGA licenses this
# file to you under the NetFPGA Hardware-Software License, Version 1.0 (the
# "License"); you may not use this file except in compliance with the
# License.  You may obtain a copy of the License at:
#
#   http://www.netfpga-cic.org
#
# Unless required by applicable law or agreed to in writing, Work distributed
# under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
# CONDITIONS OF ANY KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations under the License.
#
# @NETFPGA_LICENSE_HEADER_END@
#

from nf_sim_tools import *
import random, numpy
from collections import OrderedDict
import sss_sdnet_tuples
from packetin_header import *

###########
# define #
##########

PAYLOAD = "ABC"
DEF_PKT_SIZE = 64  # default packet size (in bytes)
# HEADER_SIZE = 46    # headers size: Ether/Dot1Q/IP/UDP
HEADER_SIZE = 18    # headers size: Ether/Dot1Q # To packets <= 32 bytes (<= 256 bits)
DEF_PKT_NUM = 24    # default packets number to simulation
DEF_HOST_NUM = 4    # default hosts number in network topology
src_host = 0        # packets sender host
vlan_id = 0         # vlan identifier to matching with IPI architecture and nf_datapath.v
vlan_prio = 0       # vlan priority

dst_host_map = {0:1, 1:0, 2:3, 3:2}                   # map the sender and receiver Hosts H[0, 1, 2, 3] based in network topology
inv_nf_id_map = {0:"nf0", 1:"nf1", 2:"nf2", 3:"nf3"}  # map the keys of dictionary nf_id_map
vlan_id_map = {"l2_switch1":1, "l2_switch2":2}        # map the vlans of parrallel switches

port_slicing = {}                                     # map the slicing of ports of SUME nf[0, 1, 2, 3] based in network topology
port_slicing[0] = "l2_switch1"
port_slicing[1] = "l2_switch1"
port_slicing[2] = "l2_switch1"
port_slicing[3] = "l2_switch1"

########################
# pkt generation tools #
########################

pktsApplied = []
pktsExpected = []

# Pkt lists for SUME simulations
nf_applied = OrderedDict()
nf_applied[0] = []
nf_applied[1] = []
nf_applied[2] = []
nf_applied[3] = []
nf_expected = OrderedDict()
nf_expected[0] = []
nf_expected[1] = []
nf_expected[2] = []
nf_expected[3] = []

dma3_expected = []
dma2_applied = []

nf_port_map = {"nf0":0b00000001, "nf1":0b00000100, "nf2":0b00010000, "nf3":0b01000000, "dma_nf2":0b00100000, "dma_nf3":0b10000000, "none":0b00000000}
nf_id_map = {"nf0":0, "nf1":1, "nf2":2, "nf3":3}

sss_sdnet_tuples.clear_tuple_files()

def applyPkt(pkt, pkt_SUME, ingress, time):
    pktsApplied.append(pkt)
    sss_sdnet_tuples.sume_tuple_in['pkt_len'] = len(pkt)
    sss_sdnet_tuples.sume_tuple_in['src_port'] = nf_port_map[ingress]
    sss_sdnet_tuples.sume_tuple_expect['pkt_len'] = len(pkt)
    sss_sdnet_tuples.sume_tuple_expect['src_port'] = nf_port_map[ingress]
    pkt_SUME.time = pkt.time = time
    if ingress in ["nf0","nf1","nf2","nf3"]:
        nf_applied[nf_id_map[ingress]].append(pkt_SUME)
    elif ingress == 'dma_nf2':
        dma2_applied.append(pkt_SUME)


def expPkt(pkt, pkt_SUME, egress, drop):
    pktsExpected.append(pkt)
    sss_sdnet_tuples.sume_tuple_expect['dst_port'] = nf_port_map[egress]
    sss_sdnet_tuples.sume_tuple_expect['drop'] = drop
    sss_sdnet_tuples.write_tuples()
    if egress in ["nf0","nf1","nf2","nf3"] and drop == False:
        nf_expected[nf_id_map[egress]].append(pkt_SUME)
    elif egress == 'bcast' and drop == False:
        nf_expected[0].append(pkt_SUME)
        nf_expected[1].append(pkt_SUME)
        nf_expected[2].append(pkt_SUME)
        nf_expected[3].append(pkt_SUME)
    elif egress == 'dma_nf3':
        dma3_expected.append(pkt_SUME)

def write_pcap_files():
    wrpcap("src.pcap", pktsApplied)
    wrpcap("dst.pcap", pktsExpected)

    for i in nf_applied.keys():
        if (len(nf_applied[i]) > 0):
            wrpcap('nf{0}_applied.pcap'.format(i), nf_applied[i])

    for i in nf_expected.keys():
        if (len(nf_expected[i]) > 0):
            wrpcap('nf{0}_expected.pcap'.format(i), nf_expected[i])

    if (len(dma2_applied) > 0):
        wrpcap('dma2_applied.pcap', dma2_applied)

    if (len(dma3_expected) > 0):
        wrpcap('dma3_expected.pcap', dma3_expected)
        wrpcap('dma0_expected.pcap', dma3_expected) # Generate dummy dma0 pcap to get PASS in SUME simulation

    for i in nf_applied.keys(): # Printing applied packets
        print "nf{0}_applied times: ".format(i), [p.time for p in nf_applied[i]]
    print "dma_nf2_applied times: ".format(i), [p.time for p in dma2_applied]

#####################
# generate testdata #
#####################

MAC_addr_H = {}
MAC_addr_H[nf_id_map["nf0"]] = "08:11:11:11:11:08"
MAC_addr_H[nf_id_map["nf1"]] = "08:22:22:22:22:08"
MAC_addr_H[nf_id_map["nf2"]] = "08:33:33:33:33:08"
MAC_addr_H[nf_id_map["nf3"]] = "08:44:44:44:44:08"

IP_addr_H = {}
IP_addr_H[nf_id_map["nf0"]] = "10.1.1.1"
IP_addr_H[nf_id_map["nf1"]] = "10.2.2.2"
IP_addr_H[nf_id_map["nf2"]] = "10.3.3.3"
IP_addr_H[nf_id_map["nf3"]] = "10.4.4.4"

MAC_addr_S = {}
MAC_addr_S[nf_id_map["nf0"]] = "05:11:11:11:11:05"
MAC_addr_S[nf_id_map["nf1"]] = "05:22:22:22:22:05"
MAC_addr_S[nf_id_map["nf2"]] = "05:33:33:33:33:05"
MAC_addr_S[nf_id_map["nf3"]] = "05:44:44:44:44:05"


def get_rand_port():
    return random.randint(1, 0xffff)

sport = get_rand_port()
dport = get_rand_port()

# create some packets
for time in range(DEF_PKT_NUM):
    vlan_id = vlan_id_map[port_slicing[src_host]]
    src_IP = IP_addr_H[src_host]
    dst_IP = IP_addr_H[dst_host_map[src_host]]

    if ( vlan_id == vlan_id_map["l2_switch1"] ):
        src_MAC = MAC_addr_H[src_host]
        dst_MAC = MAC_addr_H[dst_host_map[src_host]]
        if (src_host == 2):
            # pkt_app = Ether(src=src_MAC, dst=dst_MAC) / Dot1Q(vlan=vlan_id, prio=vlan_prio) / IP(src=src_IP, dst=dst_IP, ttl=64, chksum=0x7ce7) / UDP(sport=sport, dport=dport) / (((DEF_PKT_SIZE-HEADER_SIZE)/len(PAYLOAD))*PAYLOAD)
            pkt_app = Ether(src=src_MAC, dst=dst_MAC) / Dot1Q(vlan=vlan_id, prio=vlan_prio) / (((DEF_PKT_SIZE-HEADER_SIZE)/len(PAYLOAD))*PAYLOAD) # To packets <= 32 bytes (<= 256 bits)
            pkt_exp_SUME = Metadata(metadata_id=vlan_id, port=src_host) / pkt_app
            pkt_app_SUME = pkt_exp = pkt_app
        elif (src_host == 3):
            # pkt_exp = Ether(src=src_MAC, dst=dst_MAC) / Dot1Q(vlan=vlan_id, prio=vlan_prio) / IP(src=src_IP, dst=dst_IP, ttl=64, chksum=0x7ce7) / UDP(sport=sport, dport=dport) / (((DEF_PKT_SIZE-HEADER_SIZE)/len(PAYLOAD))*PAYLOAD)
            pkt_exp = Ether(src=src_MAC, dst=dst_MAC) / Dot1Q(vlan=vlan_id, prio=vlan_prio) / (((DEF_PKT_SIZE-HEADER_SIZE)/len(PAYLOAD))*PAYLOAD) # To packets <= 32 bytes (<= 256 bits)
            pkt_app_SUME = Metadata(metadata_id=vlan_id, port=src_host) / pkt_exp
            pkt_exp_SUME = pkt_app = pkt_exp
        else:
            # pkt_exp = pkt_app = Ether(src=src_MAC, dst=dst_MAC) / Dot1Q(vlan=vlan_id, prio=vlan_prio) / IP(src=src_IP, dst=dst_IP, ttl=64, chksum=0x7ce7) / UDP(sport=sport, dport=dport) / (((DEF_PKT_SIZE-HEADER_SIZE)/len(PAYLOAD))*PAYLOAD)
            pkt_exp_SUME = pkt_app_SUME = pkt_exp = pkt_app = Ether(src=src_MAC, dst=dst_MAC) / Dot1Q(vlan=vlan_id, prio=vlan_prio) / (((DEF_PKT_SIZE-HEADER_SIZE)/len(PAYLOAD))*PAYLOAD) # To packets <= 32 bytes (<= 256 bits)
    elif( vlan_id == vlan_id_map["l2_switch2"] ):
        src_MAC = MAC_addr_H[src_host]
        dst_MAC = MAC_addr_H[dst_host_map[src_host]]
        pkt_exp = pkt_app = Ether(src=src_MAC, dst=dst_MAC) / Dot1Q(vlan=vlan_id, prio=vlan_prio) / (((DEF_PKT_SIZE-HEADER_SIZE)/len(PAYLOAD))*PAYLOAD)
    else:
        print("\nERROR: vlan_id not mapped!\n")
        exit(1)

    ingress = inv_nf_id_map[src_host]
    if (ingress == "nf3"):
        ingress = "dma_nf2" # Sending all nf3_ingress packets by nf2_dma (packet_out)
        pkt_app_SUME = pad_pkt(pkt_app_SUME, (DEF_PKT_SIZE+2)) # Ajusting packet length (packet_out)
        pkt_app = pad_pkt(pkt_app, DEF_PKT_SIZE) # Ajusting packet length (packet_out)
    else:
        pkt_app_SUME = pad_pkt(pkt_app_SUME, DEF_PKT_SIZE)
        pkt_app = pad_pkt(pkt_app, DEF_PKT_SIZE)
    applyPkt(pkt_app, pkt_app_SUME, ingress, time)

    egress = inv_nf_id_map[dst_host_map[src_host]]
    if (egress == "nf3"):
        egress = "dma_nf3" # Sending all nf3_egress packets by nf3_dma (packet_in)
        pkt_exp_SUME = pad_pkt(pkt_exp_SUME, (DEF_PKT_SIZE+2)) # Ajusting packet length (packe_in)
        pkt_exp = pad_pkt(pkt_exp, DEF_PKT_SIZE) # Ajusting packet length (packe_in)
    else:
        pkt_exp_SUME = pad_pkt(pkt_exp_SUME, DEF_PKT_SIZE)
        pkt_exp = pad_pkt(pkt_exp, DEF_PKT_SIZE)
    drop = False
    if (drop):
        egress = "none"
    expPkt(pkt_exp, pkt_exp_SUME, egress, drop)

    src_host += 1
    vlan_prio += 1
    if ( src_host > (DEF_HOST_NUM-1) ):
        src_host = 0
        vlan_prio = 0

write_pcap_files()
