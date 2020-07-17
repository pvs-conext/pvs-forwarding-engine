## Programming SUME:

To load the full programmable design with partial reconfiguration suport 2 virtual switches: l2 and router, please run with sudo permission:

```sh
$  ./run_me.sh l2_router_full.bit
```

To load a replace a partial design, please run with sudo permission:

```sh
$  ./run_me.sh l2_router_part_l2.bit
```

### The Bitstream Name

The name of bitstream composition:

| Project | Type | Virtual Switch |  
|---------|------|----------------|
| l2_router | Full | - - - - - - - - - - - |
| l2_router | Partial | l2 |
| l2_router | Partial | router |
