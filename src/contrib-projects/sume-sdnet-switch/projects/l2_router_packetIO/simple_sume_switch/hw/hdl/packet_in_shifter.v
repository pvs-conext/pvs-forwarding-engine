//-
// Copyright (c) 2015 University of Cambridge
// All rights reserved.
//
// This software was developed by
// Stanford University and the University of Cambridge Computer Laboratory
// under National Science Foundation under Grant No. CNS-0855268,
// the University of Cambridge Computer Laboratory under EPSRC INTERNET Project EP/H040536/1 and
// by the University of Cambridge Computer Laboratory under DARPA/AFRL contract FA8750-11-C-0249 ("MRC2"),
// as part of the DARPA MRC research programme.
//
// @NETFPGA_LICENSE_HEADER_START@
//
// Licensed to NetFPGA C.I.C. (NetFPGA) under one or more contributor
// license agreements.  See the NOTICE file distributed with this work for
// additional information regars_axis_tdatag copyright ownership.  NetFPGA licenses this
// file to you under the NetFPGA Hardware-Software License, Version 1.0 (the
// "License"); you may not use this file except in compliance with the
// License.  You may obtain a copy of the License at:
//
//   http://www.netfpga-cic.org
//
// Unless required by applicable law or agreed to in writing, Work distributed
// under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations under the License.
//
// @NETFPGA_LICENSE_HEADER_END@
//
///////////////////////////////////////////////////////////////////////////////
//
// Module: packet_in_shifter.v
// Description: A tvalid sensitive shifter to tdata. The selection left (packet
//              in) or right (packet out) is based in dst_port or src_port,
//              respectively. Packet in add vS metadata (vSwitch id and vSwitch
//              port) to the packet begin. Packet out remove vS metadata from
//              the packet begin.
//
///////////////////////////////////////////////////////////////////////////////
`timescale 1ns/1ps

module packet_in_shifter
#(
  // Master AXI Stream Data Width
  parameter C_M_AXIS_DATA_WIDTH=256,
  parameter C_M_AXIS_TUSER_WIDTH=304,
  // Slave AXI Stream Data Width
  parameter C_S_AXIS_DATA_WIDTH=256,
  parameter C_S_AXIS_TUSER_WIDTH=304,
  parameter VLAN_THRESHOLD_BGN=128,
  parameter VLAN_THRESHOLD_END=96,
  parameter VLAN_WIDTH=32,
  parameter VLAN_WIDTH_ID=12

)
(
  // Master Stream Ports (interface to TX queues)
  output [C_M_AXIS_DATA_WIDTH - 1:0]                            m_axis_tdata,
  output [((C_M_AXIS_DATA_WIDTH / 8)) - 1:0]                    m_axis_tkeep,
  output [C_M_AXIS_TUSER_WIDTH-1:0]                             m_axis_tuser,
  output                                                        m_axis_tvalid,
  input                                                         m_axis_tready,
  output                                                        m_axis_tlast,
  // Slave Stream Ports (interface to OvSI)
  input [C_S_AXIS_DATA_WIDTH - 1:0]                             s_axis_tdata,
  input [((C_S_AXIS_DATA_WIDTH / 8)) - 1:0]                     s_axis_tkeep,
  input [C_S_AXIS_TUSER_WIDTH-1:0]                              s_axis_tuser,
  input                                                         s_axis_tvalid,
  output                                                        s_axis_tready,
  input                                                         s_axis_tlast,
  // Global Ports
  input                                                         resetn,
  input                                                         clk
);

  // Wait packets to shift and forwarding non shifted packets
  // to shited packet, add metadata information and ajust the packet length
  localparam WAIT_PKT = 0;
  // Do the shift in the rest of packet and wait for tlast signal
  localparam WR_PKT_SHIFT_LEFT = 1;
  // If shift overflow axis bus, create last new packet's part and
  // manage the control signals
  localparam LAST_PKT_SHIFT_LEFT = 2;

  // ------------- Regs/ wires -----------
  wire [15:0] indbg_pkt_len           = s_axis_tuser[15:0];
  wire [7:0]  indbg_src_port          = s_axis_tuser[23:16];
  wire [7:0]  indbg_dst_port          = s_axis_tuser[31:24];
  wire [7:0]  indbg_drop              = s_axis_tuser[39:32];
  wire [7:0]  indbg_send_dig          = s_axis_tuser[47:40];
  wire [15:0] outdbg_pkt_len          = m_axis_tuser[15:0];
  // Parser packet_metadata (vlan total width = 32 bits | vlan_id = 12 bites)
  wire [31:0] vlan_tdata              = s_axis_tdata [127:96];
  wire [15:0] vlan_prot_id            = vlan_tdata [15:0];
  wire [15:0] vlan_info               = vlan_tdata [31:16];
  wire        vlan_info_drop          = vlan_info [4];
  wire [7:0]  vSwitch_id              = vlan_info[15:8]; // vlan_info_id = {vlan_info[3:0], vlan_info[15:8]};
  wire [2:0]  vSwitch_port            = vlan_info [7:5]; // vlan_info_prio
  wire [15:0] vSwitch_metadata        = {5'b0, vSwitch_port[2:0], vSwitch_id[7:0]}; // in little endian

  reg [C_M_AXIS_DATA_WIDTH-1:0]         axis_tdata;
  reg [((C_M_AXIS_DATA_WIDTH/8))-1:0]   axis_tkeep;
  reg [C_M_AXIS_TUSER_WIDTH-1:0]        axis_tuser;
  reg                                   axis_tvalid;
  reg                                   axis_tready;
  reg                                   axis_tlast;
  // tkeep determines the valid bytes in tdata, possible values in hexa are: 0, 1, 3, 7 or F
  reg [C_M_AXIS_DATA_WIDTH - 1:0]       s_axis_tdata_old;
  reg [C_M_AXIS_TUSER_WIDTH-1:0]        axis_tkeep_next;
  reg                                   doing_shifth_left;
  reg [15:0]                            shifted_data;
  reg [1:0]                             state;

  // ------------- Logic ------------
  // assign s_axis_tready = (m_axis_tready == 0) ? 0 : 1;
  assign m_axis_tdata = axis_tdata;
  assign m_axis_tuser = axis_tuser;
  assign m_axis_tkeep = axis_tkeep;
  assign m_axis_tvalid = axis_tvalid;
  assign m_axis_tlast = axis_tlast;
  assign s_axis_tready = axis_tready;

  always @(posedge clk)
  begin
    if (~resetn) begin
      s_axis_tdata_old <= 'h0;
      doing_shifth_left <= 0;
      shifted_data <= 'h0;
    end
    else begin
      shifted_data <= s_axis_tdata [C_M_AXIS_DATA_WIDTH - 1:C_M_AXIS_DATA_WIDTH - 16];
      if (indbg_dst_port == 8'h80 && s_axis_tvalid) begin
        doing_shifth_left <= 1;
      end
      if (doing_shifth_left && ~s_axis_tvalid) begin
        doing_shifth_left <= 0;
      end //
      if (s_axis_tdata != s_axis_tdata_old) begin // if input tdata changes, make the shift
        s_axis_tdata_old <= s_axis_tdata;
      end
    end // if (~resetn)
  end // always

  always @(posedge clk)
  begin
    if (~resetn) begin
      axis_tdata <= 'h0;
      axis_tuser <= 'h0;
      axis_tkeep <= 'h0;
      axis_tkeep_next <= 'h0;
      axis_tvalid <= 0;
      axis_tlast <= 0;
      axis_tready <= 0;
      state <= 0;
    end else begin

      case (state)
        WAIT_PKT: begin
          if (s_axis_tvalid) begin // The queues only up the tready when the tvalid was asserted
            if (indbg_dst_port == 8'h80) begin
              axis_tvalid <= 1;
              axis_tready <= 1;
              axis_tdata <= {s_axis_tdata[C_S_AXIS_DATA_WIDTH-16:0], vSwitch_metadata}; // does the shift left of 16 bits and add pkt_metadata to the packet begin
              axis_tuser <= {s_axis_tuser[C_M_AXIS_TUSER_WIDTH-1:16], (indbg_pkt_len + 16'h0002)}; // adds 16 bits to pkt_len
              axis_tkeep <= s_axis_tkeep;
              state <= WR_PKT_SHIFT_LEFT;
            end else begin // Only pass the input to output when we don't have shift
              axis_tdata <= s_axis_tdata;
              axis_tuser <= s_axis_tuser;
              axis_tkeep <= s_axis_tkeep;
              axis_tlast <= s_axis_tlast;
              axis_tvalid <= 1;
              axis_tready <= 1;
              state <= WAIT_PKT;
            end // if (indbg_dst_port == 8'h80)
          end else begin
            axis_tdata <= 'h0;
            axis_tuser <= 'h0;
            axis_tkeep <= 'h0;
            axis_tlast <= 0;
            axis_tvalid <= 0;
            axis_tready <= 0;
            axis_tkeep_next <= 'h0;
          end // if (s_axis_tvalid)
        end // WAIT_PKT

        WR_PKT_SHIFT_LEFT: begin
          if (s_axis_tdata != s_axis_tdata_old) begin // if input tdata changes, make the shift
            axis_tdata <= {s_axis_tdata[C_S_AXIS_DATA_WIDTH-16:0], shifted_data};
          end
          if (s_axis_tlast) begin
            if (s_axis_tkeep == 32'hffffffff) begin // cover tdata full valid data (tdata=0xffffffffffffffffff...)
              state <= LAST_PKT_SHIFT_LEFT;
              axis_tkeep <= s_axis_tkeep;
              axis_tkeep_next <= 32'h00000003;
              axis_tlast <= 0;
              axis_tready <= 0;
            end else if (s_axis_tkeep == 32'h7fffffff) begin // cover tdata without 1 byte of valid data (tdata=0x00ffffffffffffffff...)
              state <= LAST_PKT_SHIFT_LEFT;
              axis_tkeep <= (s_axis_tkeep << 1)+1'b1;
              axis_tkeep_next <= 32'h00000001;
              axis_tlast <= 0;
              axis_tready <= 0;
            end else begin
              axis_tkeep <= (s_axis_tkeep << 2)+2'b11; // cover the other options. Ajusting tkeep to map tdata shifted (16 bytes more of tdata are valid)
              axis_tlast <= 1;
              axis_tvalid <= 1;
              axis_tready <= 0;
              state <= WAIT_PKT;
            end // (s_axis_tkeep == 32'h7fffffff)
          end else begin
            axis_tkeep <= s_axis_tkeep;
            axis_tlast <= 0;
            axis_tready <= 1;
          end // if (s_axis_tlast)
          axis_tuser <= axis_tuser;
          axis_tvalid <= 1;
        end // WR_PKT_SHIFT_LEFT

        LAST_PKT_SHIFT_LEFT: begin // adds the last shifted data to packet adding one more clk of data
          axis_tdata <= {s_axis_tdata[C_S_AXIS_DATA_WIDTH-16:0], shifted_data};
          axis_tuser <= axis_tuser;
          axis_tkeep <= axis_tkeep_next;
          axis_tlast <= 1;
          axis_tvalid <= 1;
          axis_tready <= 0;
          state <= WAIT_PKT;
        end // LAST_PKT_SHIFT_LEFT
      endcase

    end // if (~resetn)
  end // always @(posedge clk)

endmodule // packet_in_shifter
