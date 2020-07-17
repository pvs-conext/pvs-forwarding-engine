Copyright (c) 2019

All rights reserved.

Part of this software was developed by Stanford University and the University of Cambridge Computer Laboratory under National Science Foundation under Grant No. CNS-0855268,
the University of Cambridge Computer Laboratory under EPSRC INTERNET Project EP/H040536/1 and
by the University of Cambridge Computer Laboratory under DARPA/AFRL contract FA8750-11-C-0249 ("MRC2"),
as part of the DARPA MRC research programme.

@NETFPGA_LICENSE_HEADER_START@

Licensed to NetFPGA C.I.C. (NetFPGA) under one or more contributor
license agreements.  See the NOTICE file distributed with this work for
additional information regarding copyright ownership.  NetFPGA licenses this
file to you under the NetFPGA Hardware-Software License, Version 1.0 (the
"License"); you may not use this file except in compliance with the
License.  You may obtain a copy of the License at:

  http://www.netfpga-cic.org

Unless required by applicable law or agreed to in writing, Work distributed
under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
CONDITIONS OF ANY KIND, either express or implied.  See the License for the
specific language governing permissions and limitations under the License.

@NETFPGA_LICENSE_HEADER_END@



## PvS Forwarding Engine

Source code of the PvS forwarding engine. Kindly note that this code is under development and may be unstable. For a running example of PvS forwarding engine, please consider using the code in the full-reconfig-build/ or partial-reconfig-build/ folder.

### Installation Ubuntu 16.04

How to clone this repository:

```sh
$  git clone https://github.com/pvs-conext/pvs-forwarding-engine.git
$  cd pvs-forwarding-engine
$  git pull --tags
```

Add these lines at your environment variables file: `vi ~/.bashrc`

```sh
export PVS=~/projects/pvs-forwarding-engine/src/scripts/settings.sh
source $PVS
```

Updating environment:

```sh
$  source ~/.bashrc
```

Instaling all dependencies:

```sh
$  sudo $PVS_SCRIPTS/tools/setup_SUME.sh  
```

Making the library and installing the SUME driver:

```sh
$  $PVS_MAKE_LIBRARY
$  $PVS_INSTALL_DRIVER
```

### Usage

How to create a new PvS project:

```sh
$  $PVS_NEWPROJ <project_name>
```

Update environment variables, change the `$PVS_SCRIPTS/settings.sh` with the correct project name: `vi $PVS`

```sh
...
export P4_PROJECT_NAME=<project_name>
...
```

Then update the environment with the new project name:

```sh
$  source $PVS
```

#### Building a project - P4 switches Flow

Enter in the project folder to create virtual switches:

```sh
$  cd $P4_PROJECT_DIR
```

Write:
  - The virtual switch in P4 code (.p4), for example, on `src/` folder.
  - The commands file `commands_<name_p4_switch>.txt` with switch tables.
  - The script generator for data tes on `testdata/` folder. **Warning:** *each switch should have a test data named: `gen_testdata_<switch_name>.py` and your project must have your propely test data named: gen_testdata_<project_name>.py*

#### Running the Project - P4 switches Flow

Generate your test data, you can run this option with `--pp` option to see the packets:

```sh
cd $PVS_SCRIPTS

$  ./pvs.py <virtual_switch_0> <virtual_switch_1> .. <virtual_switch_N> -name <project_name> -t
```

Verify your P4 Code sintaxe:

```sh
$  ./pvs.py <virtual_switch_0> <virtual_switch_1> .. <virtual_switch_N> -name <project_name> -c
```

Run the P4 switch simulation, you can run `-v` flag to see in terminal, the standart output is the log file in `$P4_PROJECT_DIR/log/`:

```sh
$  ./pvs.py <virtual_switch_0> <virtual_switch_1> .. <virtual_switch_N> -name <project_name> -s
```

Run the SUME simulation to all virtual switches:

```sh
$  ./pvs.py <virtual_switch_0> <virtual_switch_1> .. <virtual_switch_N> -name <project_name>
```

Implement your design:

```sh
$  ./pvs.py <virtual_switch_0> <virtual_switch_1> .. <virtual_switch_N> -name <project_name> --imp
```

Programming the SUME board:

```sh
$  sudo $PVS_PROGSUME
```
