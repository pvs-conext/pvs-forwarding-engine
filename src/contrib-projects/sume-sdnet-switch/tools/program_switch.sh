#!/bin/bash

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

xilinx_tool_path=`which vivado`

if [ $# -ne 2 ]; then
  echo
  echo "Usage: $0 [bistream] [config_writes]"
  echo
  echo " e.g. $0 l2.bit config_writes_l2.sh"
  echo
  echo " This script program the SUME board with the bitstream (full or partial),"
	echo " end initializes the switch tables."
	echo
fi

if [ -z $1 ]; then
	echo
	echo 'Nothing input for bit file.'
	exit 1
fi

if [ -z $2 ]; then
	echo
	echo 'Nothing input for config writes script.'
	exit 1
fi

bitimage=$1
configWrites=$2

echo
echo '      Project name = ' ${P4_PROJECT_NAME}
echo '    Bitstream file = ' $bitimage
echo 'Config writes file = ' $configWrites
echo

rmmod sume_riffa

echo
xsct ${SUME_SDNET}/tools/run_xsct.tcl -tclargs $bitimage
echo

lspci -vxx | grep -i xilinx

${SUME_SDNET}/tools/pci_rescan_run.sh

if [ $? -ne 0 ]; then
	exit 1
fi

rmmod sume_riffa

modprobe sume_riffa

ifconfig nf0 up
ifconfig nf1 up
ifconfig nf2 up
ifconfig nf3 up

sleep 3

bash $configWrites

sleep 3

echo
echo

ifconfig -a
