#
# Copyright (c)
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

export PVS_FOLDER=${HOME}/projects/pvs-forwarding-engine
export PVS_DEMO=${PVS_FOLDER}/full-reconfig-build

export P4_PROJECT_NAME=l2_router_firewall_int
export SUME_FOLDER=${PVS_FOLDER}/src
export SUME_SDNET=${SUME_FOLDER}/contrib-projects/sume-sdnet-switch
export DRIVER_NAME=sume_riffa_v1_0_0
export DRIVER_FOLDER=${SUME_FOLDER}/lib/sw/std/driver/${DRIVER_NAME}
export APPS_FOLDER=${SUME_FOLDER}/lib/sw/std/apps/${DRIVER_NAME}

export PVS=${SUME_FOLDER}/scripts/settings.sh
export PVS_VSWITCH=l2
export PVS_SCRIPTS=${SUME_FOLDER}/scripts
export PVS_MAKE_LIBRARY=${PVS_SCRIPTS}/tools/make_library.sh
export PVS_INSTALL_DRIVER=${PVS_SCRIPTS}/tools/make_driver.sh
export PVS_TESTER=${PVS_DEMO}/tools/l2_router_tester.py
export PVS_TESTER_VIEW=${PVS_DEMO}/tools/view_packets.py
