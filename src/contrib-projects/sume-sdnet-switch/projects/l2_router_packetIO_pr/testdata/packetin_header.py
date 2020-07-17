from scapy.all import *
import sys, os

PKTIN_TYPE = 0x1212

class Metadata(Packet):
	name = "Metadata"
	fields_desc = [
		XByteField("metadata_id", 1),
		XByteField("port", 1)
	]

bind_layers(Metadata, Ether)
bind_layers(Ether, Raw)
