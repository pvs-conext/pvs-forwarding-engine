## Build of the Partial Reconfiguration

This folder contains a functional build of the PvS Forwarding bitstream ready for use with the control engine build available in the pvs-control-engine repo, for use with a l2 and a router virtual switch. There are bitstreams in the bitfiles/ folder and a simple python tester in tools/ folder.

### Requirements
In order to run this build is necessary a SUME board properly installed on a host. **Only** if the SUME driver isn't available, run with root permission:

```sh
$  source settings.sh
$  cd tools
$  ./setup_env.sh
```

### Usage
In order to program the SUME board, issue the following command:

```sh
$  source settings.sh
$  cd bitfiles
$  ./run_me.sh l2_router_full.bit
```

To load a partial bitstream with a virtual switch, you can run to l2:

```sh
$  ./run_me.sh l2_router_part_l2.bit
```

*Now we have two virtual switches l2 running in parallel*

To change one l2 to a router, you can run:

```sh
$  ./run_me.sh l2_router_part_router.bit
```
*Now we have an l2 and a router running in parallel*

#### Test

To test the design, is requirement another machine send and receiving packets from 10G NIC, another SUME board with reference_nic design loaded or a bridge switch to translate electrical signals to optical.

In order to view packets from SUME board, issue the following command and type help to more information(require tcpdump installed):

```sh
$  cd tools
$  ./view_packets.py
```

To send packets, run and type help to more information:

```sh
$  ./l2_router_tester.py
```

Or to send packets in design with two virtual switches l2:

```sh
$  ./l2_l2_tester.py
```
