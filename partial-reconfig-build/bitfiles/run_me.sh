#!/bin/bash

# Copyright (c) 2019
# All rights reserved.
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

if [ $# -ne 1 ]; then
  echo
  echo "Usage: $0 [bistream_file]"
  echo
  echo " e.g. $0 l2_router_full.bit"
  echo " e.g. $0 l2_router_part_l2.bit"
  echo " e.g. $0 l2_router_part_router.bit"
  echo
  echo " This script program the SUME board with the bitstream,"
	echo " end initializes the switch tables."
	echo
  exit 1
fi

bitimage=$1
projNameFull=${1%_full.bit}
part=${1#*_part_}
partName=${part%.bit}

if [ $projNameFull == "l2_router" ]; then
  ${SUME_SDNET}/tools/program_switch.sh $bitimage config_writes_${projNameFull}.sh
else
  ${SUME_SDNET}/tools/program_switch.sh $bitimage config_writes_${partName}.sh
fi
