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

##########
# define #
##########

TABLE_NUM = 7          # total tables number
DEF_PKT_NUM = 24       # default packets number to simulation
DEF_PKT_SIZE = 256     # default packet size (in bytes)
HEADER_SIZE = 46       # headers size: Ether/IP/UDP
DEF_HOST_NUM = 4       # default hosts number in network topology
INI_DELAY = TABLE_NUM  # initial delay to begin to send packets, needed to initialize tables in board simulation
src_host = 0           # packets sender host
vlan_id = 0            # vlan identifier to matching with IPI architecture and nf_datapath.v
vlan_prio = 0          # vlan priority

dst_host_map = {0:0, 1:1, 2:3, 3:2}                     # map the sender and receiver Hosts H[0, 1, 2, 3] based in network topology
inv_nf_id_map = {0:"nf0", 1:"nf1", 2:"nf2", 3:"nf3"}    # map the keys of dictionary nf_id_map
vlan_id_map = {"l2_switch":1, "router":2, "firewall":3} # map the vlans of parrallel switches

port_slicing = {}                                       # map the slicing of ports of SUME nf[0, 1, 2, 3] based in network topology
port_slicing[0] = "l2_switch"
port_slicing[1] = "router"
port_slicing[2] = "firewall"
port_slicing[3] = "firewall"

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

nf_port_map = {"nf0":0b00000001, "nf1":0b00000100, "nf2":0b00010000, "nf3":0b01000000, "none":0b00000000}
nf_id_map = {"nf0":0, "nf1":1, "nf2":2, "nf3":3}

sss_sdnet_tuples.clear_tuple_files()

def applyPkt(pkt, ingress, time):
    pktsApplied.append(pkt)
    sss_sdnet_tuples.sume_tuple_in['pkt_len'] = len(pkt)
    sss_sdnet_tuples.sume_tuple_in['src_port'] = nf_port_map[ingress]
    sss_sdnet_tuples.sume_tuple_expect['pkt_len'] = len(pkt)
    sss_sdnet_tuples.sume_tuple_expect['src_port'] = nf_port_map[ingress]
    pkt.time = time + INI_DELAY
    nf_applied[nf_id_map[ingress]].append(pkt)

def expPkt(pkt, egress, drop):
    pktsExpected.append(pkt)
    sss_sdnet_tuples.sume_tuple_expect['dst_port'] = nf_port_map[egress]
    sss_sdnet_tuples.sume_tuple_expect['drop'] = drop
    sss_sdnet_tuples.write_tuples()
    if egress in ["nf0","nf1","nf2","nf3"] and drop == False:
        nf_expected[nf_id_map[egress]].append(pkt)
    elif egress == 'bcast' and drop == False:
        nf_expected[0].append(pkt)
        nf_expected[1].append(pkt)
        nf_expected[2].append(pkt)
        nf_expected[3].append(pkt)

def write_pcap_files():
    wrpcap("src.pcap", pktsApplied)
    wrpcap("dst.pcap", pktsExpected)

    for i in nf_applied.keys():
        if (len(nf_applied[i]) > 0):
            wrpcap('nf{0}_applied.pcap'.format(i), nf_applied[i])

    for i in nf_expected.keys():
        if (len(nf_expected[i]) > 0):
            wrpcap('nf{0}_expected.pcap'.format(i), nf_expected[i])

    for i in nf_applied.keys():
        print "nf{0}_applied times: ".format(i), [p.time for p in nf_applied[i]]

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

BLOCK_SPORT = 1234
BLOCK_DPORT = 8888

def get_rand_port():
    return random.randint(1, 0xffff)

def get_rand_block():
    rand_sport = get_rand_port()
    rand_dport = get_rand_port()
    while ((rand_sport == BLOCK_SPORT) or (rand_dport == BLOCK_DPORT)):
        rand_sport = get_rand_port()
        rand_dport = get_rand_port()
    rand_block = bool(random.getrandbits(1))
    if ( rand_block ):
        if ( bool(random.getrandbits(1)) ):
            rand_sport = BLOCK_SPORT
        else:
            rand_dport = BLOCK_DPORT

    return (rand_sport, rand_dport, rand_block)


# create some packets
for time in range(DEF_PKT_NUM):
    vlan_id = vlan_id_map[port_slicing[src_host]]
    src_IP = IP_addr_H[src_host]
    dst_IP = IP_addr_H[dst_host_map[src_host]]
    drop = False

    if ( vlan_id == vlan_id_map["l2_switch"] ):
        sport = get_rand_port()
        dport = get_rand_port()
        src_MAC = MAC_addr_H[src_host]
        dst_MAC = MAC_addr_H[dst_host_map[src_host]]
        pkt_exp = pkt_app = Ether(src=src_MAC, dst=dst_MAC) / Dot1Q(vlan=vlan_id, prio=vlan_prio) / IP(src=src_IP, dst=dst_IP, ttl=64, chksum=0x7ce7) / UDP(sport=sport, dport=dport) / ((DEF_PKT_SIZE - HEADER_SIZE)*"A")
        drop = False
    elif( vlan_id == vlan_id_map["router"] ):
        sport = get_rand_port()
        dport = get_rand_port()
        src_MAC = MAC_addr_H[src_host]
        dst_MAC = MAC_addr_S[src_host]
        pkt_app = Ether(src=src_MAC, dst=dst_MAC) / Dot1Q(vlan=vlan_id, prio=vlan_prio) / IP(src=src_IP, dst=dst_IP, ttl=64, chksum=0x7ce7) / UDP(sport=sport, dport=dport) / ((DEF_PKT_SIZE - HEADER_SIZE)*"A")
        src_MAC = MAC_addr_S[dst_host_map[src_host]]
        dst_MAC = MAC_addr_H[dst_host_map[src_host]]
        pkt_exp = Ether(src=src_MAC, dst=dst_MAC) / Dot1Q(vlan=vlan_id, prio=vlan_prio) / IP(src=src_IP, dst=dst_IP, ttl=63, chksum=0x7ce7) / UDP(sport=sport, dport=dport) / ((DEF_PKT_SIZE - HEADER_SIZE)*"A")
        drop = False
    elif ( vlan_id == vlan_id_map["firewall"] ):
        src_MAC = MAC_addr_H[src_host]
        dst_MAC = MAC_addr_H[dst_host_map[src_host]]
        (sport, dport, drop) = get_rand_block()
        pkt_app = Ether(src=src_MAC, dst=dst_MAC) / Dot1Q(vlan=vlan_id, prio=vlan_prio) / IP(src=src_IP, dst=dst_IP, ttl=20) / UDP(sport=sport, dport=dport) / ((DEF_PKT_SIZE - HEADER_SIZE)*"A")
        pkt_exp = Ether(src=src_MAC, dst=dst_MAC) / Dot1Q(vlan=vlan_id, prio=vlan_prio) / IP(src=src_IP, dst=dst_IP, ttl=20) / UDP(sport=sport, dport=dport) / ((DEF_PKT_SIZE - HEADER_SIZE)*"A")
    else:
        print("\nERROR: vlan_id not mapped!\n")
        exit(1)

    pkt_app = pad_pkt(pkt_app, DEF_PKT_SIZE)
    ingress = inv_nf_id_map[src_host]
    applyPkt(pkt_app, ingress, time)
    pkt_exp = pad_pkt(pkt_exp, DEF_PKT_SIZE)
    egress = inv_nf_id_map[dst_host_map[src_host]]
    if (drop):
        egress = "none"
    expPkt(pkt_exp, egress, drop)

    src_host += 1
    vlan_prio += 1
    if ( src_host > (DEF_HOST_NUM-1) ):
        src_host = 0
        vlan_prio = 0

write_pcap_files()
