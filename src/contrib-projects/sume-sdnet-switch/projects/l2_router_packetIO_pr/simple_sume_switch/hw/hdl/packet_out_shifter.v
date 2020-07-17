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
// Module: packet_out_shifter.v
// Description: A tvalid sensitive shifter to tdata. The selection left (packet
//              in) or right (packet out) is based in dst_port or src_port,
//              respectively. Packet in add vS metadata (vSwitch id and vSwitch
//              port) to the packet begin. Packet out remove vS metadata from
//              the packet begin.
//
///////////////////////////////////////////////////////////////////////////////
`timescale 1ns/1ps

module packet_out_shifter
#(
  // Master AXI Stream Data Width
  parameter C_M_AXIS_DATA_WIDTH=256,
  parameter C_M_AXIS_TUSER_WIDTH=128,
  // Slave AXI Stream Data Width
  parameter C_S_AXIS_DATA_WIDTH=256,
  parameter C_S_AXIS_TUSER_WIDTH=128,
  parameter VLAN_THRESHOLD_BGN=128,
  parameter VLAN_THRESHOLD_END=96,
  parameter VLAN_WIDTH=32,
  parameter VLAN_WIDTH_ID=12

)
(
  // Master Stream Ports (interface to IvSI)
  output [C_M_AXIS_DATA_WIDTH - 1:0]                            m_axis_tdata,
  output [((C_M_AXIS_DATA_WIDTH / 8)) - 1:0]                    m_axis_tkeep,
  output [C_M_AXIS_TUSER_WIDTH-1:0]                             m_axis_tuser,
  output                                                        m_axis_tvalid,
  input                                                         m_axis_tready,
  output                                                        m_axis_tlast,
  // Slave Stream Ports (interface to RX queues)
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
  localparam WR_PKT_SHIFT_RIGHT = 1;
  // If shift overflow axis bus, create last new packet's part and
  // manage the control signals
  localparam LAST_PKT_SHIFT_RIGHT = 2;
  // If I did the shift and the packet has lenght <= 256, so I need keep
  // the signalsswtable by one more clock
  localparam LAST_SMALL_PKT = 3;

  // ------------- Regs/ wires -----------
  wire [15:0] indbg_pkt_len           = s_axis_tuser[15:0];
  wire [7:0]  indbg_src_port          = s_axis_tuser[23:16];
  wire [7:0]  indbg_dst_port          = s_axis_tuser[31:24];
  wire [7:0]  indbg_drop              = s_axis_tuser[39:32];
  wire [7:0]  indbg_send_dig          = s_axis_tuser[47:40];
  wire [15:0] outdbg_pkt_len          = m_axis_tuser[15:0];
  // Parser packet_metadata
  wire [7:0]  vSwitch_id              = s_axis_tdata[15:8]; // 2st byte of packet
  wire [7:0]  vSwitch_port            = s_axis_tdata [7:0]; // 1st byte of packet
  wire [15:0] vSwitch_metadata        = {vSwitch_port, vSwitch_id};

  reg [C_M_AXIS_DATA_WIDTH-1:0]         axis_tdata;
  reg [((C_M_AXIS_DATA_WIDTH/8))-1:0]   axis_tkeep;
  reg [C_M_AXIS_TUSER_WIDTH-1:0]        axis_tuser;
  reg                                   axis_tvalid;
  reg                                   axis_tready;
  reg                                   axis_tlast;
  // tkeep determines the valid bytes in tdata, possible values in hexa are: 0, 1, 3, 7 or F
  reg [C_M_AXIS_DATA_WIDTH - 1:0]       axis_tdata_next;
  reg [((C_M_AXIS_DATA_WIDTH/8))-1:0]   axis_tkeep_next;
  reg [C_M_AXIS_TUSER_WIDTH-1:0]        axis_tuser_next;
  reg                                   axis_tlast_next;
  reg                                   axis_tvalid_old;
  reg                                   doing_shifth_right;
  reg                                   small_packet;
  reg [7:0]                             vSwitch_id_reg;
  reg [7:0]                             vSwitch_port_reg;
  reg [15:0]                            vSwitch_metadata_reg;
  reg [15:0]                            shifted_data;
  reg [1:0]                             state;

  // ------------- Logic ------------
  assign m_axis_tdata  = axis_tdata;
  assign m_axis_tuser  = axis_tuser;
  assign m_axis_tkeep  = axis_tkeep;
  assign m_axis_tvalid = axis_tvalid;
  assign m_axis_tlast  = axis_tlast;
  assign s_axis_tready = axis_tready;

  always @(*)
  begin
    if (~resetn) begin
      doing_shifth_right <= 0;
      shifted_data <= 'h0;
      axis_tvalid_old <= 0;
      vSwitch_id_reg <= 'h0;
      vSwitch_port_reg <= 'h0;
      vSwitch_metadata_reg <= 'h0;
    end
    else begin
      shifted_data <= s_axis_tdata [15:0];
      if (indbg_src_port == 8'h20 && s_axis_tvalid) begin
        doing_shifth_right <= 1;
      end
      if (doing_shifth_right && ~s_axis_tvalid) begin
        doing_shifth_right <= 0;
      end //
      axis_tvalid_old <= s_axis_tvalid;
      if (~axis_tvalid_old && s_axis_tvalid) begin
        vSwitch_id_reg <= vSwitch_id;
        vSwitch_port_reg <= vSwitch_port;
        vSwitch_metadata_reg <= vSwitch_metadata;
      end else if (axis_tvalid_old && ~s_axis_tvalid) begin
        vSwitch_id_reg <= 'h0;
        vSwitch_port_reg <= 'h0;
        vSwitch_metadata_reg <= 'h0;
      end // if (~axis_tvalid_old && s_axis_tvalid)
    end // if (~resetn)
  end // always

  always @(posedge clk)
  begin
    if (~resetn) begin
      axis_tdata = 'h0;
      axis_tuser = 'h0;
      axis_tkeep = 'h0;
      axis_tdata_next = 'h0;
      axis_tkeep_next = 'h0;
      axis_tuser_next = 'h0;
      axis_tvalid = 0;
      axis_tlast = 0;
      axis_tready = 0;
      small_packet = 0;
      state = 0;
    end else begin

      axis_tvalid = 0;
      axis_tready = 1;
      axis_tlast = 0;
      case (state)
        WAIT_PKT: begin
          if (s_axis_tvalid) begin // The queues only up the tready when the tvalid was asserted
            if (m_axis_tready) begin
              if (indbg_src_port == 8'h20) begin
                small_packet = 1;
                if (s_axis_tlast) begin
                  axis_tvalid = 1;
                  axis_tlast = 1;
                  axis_tdata = s_axis_tdata >> 16;
                  axis_tkeep = s_axis_tkeep >> 2;
                  axis_tuser = {s_axis_tuser[C_M_AXIS_TUSER_WIDTH-1:16], (indbg_pkt_len - 16'h0002)};
                  axis_tdata_next = 'h0;
                  axis_tkeep_next = 'h0;
                  axis_tuser_next = 'h0;
                  state = LAST_SMALL_PKT;
                end else begin
                  axis_tvalid = 0;
                  axis_tlast = 0;
                  axis_tdata = axis_tdata;
                  axis_tkeep = axis_tkeep;
                  axis_tuser = axis_tuser;
                  axis_tdata_next = s_axis_tdata >> 16; // only load the atual tdata and tkeep
                  axis_tkeep_next = s_axis_tkeep;
                  axis_tuser_next = {s_axis_tuser[C_M_AXIS_TUSER_WIDTH-1:16], (indbg_pkt_len - 16'h0002)};
                  state <= WR_PKT_SHIFT_RIGHT;
                end // if (s_axis_tlast)
              end else begin // Only pass the input to output when we don't have shift
                axis_tdata = s_axis_tdata;
                axis_tuser = s_axis_tuser;
                axis_tkeep = s_axis_tkeep;
                axis_tlast = s_axis_tlast;
                axis_tvalid = 1;
                state = WAIT_PKT;
              end // if (indbg_dst_port == 8'h20)
            end // if (m_axis_tready)
          end else begin
            axis_tdata = 'h0;
            axis_tuser = 'h0;
            axis_tkeep = 'h0;
            axis_tdata_next = 'h0;
            axis_tkeep_next = 'h0;
            axis_tuser_next = 'h0;
          end // if (s_axis_tvalid)
        end // WAIT_PKT

        WR_PKT_SHIFT_RIGHT: begin
          axis_tvalid = 1;
          axis_tdata = {shifted_data, axis_tdata_next[C_S_AXIS_DATA_WIDTH-17:0]};
          axis_tdata_next = s_axis_tdata >> 16;
          axis_tuser = axis_tuser_next;
          axis_tuser_next = 'h0;
          if (s_axis_tlast) begin
            if (s_axis_tkeep == 32'h00000003) begin // cover the case when tdata loses 1 clock (the last packet part have 2 bytes)
              axis_tlast = 1;
              axis_tkeep = axis_tkeep_next;
              axis_tkeep_next = 'h0;
              if (small_packet) begin
                state = LAST_SMALL_PKT;
              end else begin
                state = WAIT_PKT;
              end
            end else if (s_axis_tkeep == 32'h00000001) begin // cover the case when tdata loses 1 clock (the last packet part have 2 bytes)
              axis_tlast = 1;
              axis_tkeep = axis_tkeep_next >> 1;
              axis_tkeep_next =  'h0;
              if (small_packet) begin
                state = LAST_SMALL_PKT;
              end else begin
                state = WAIT_PKT;
              end
            end else begin
              axis_tlast = 0;
              axis_tkeep = axis_tkeep_next;
              axis_tkeep_next =  s_axis_tkeep >> 2;
              state = LAST_PKT_SHIFT_RIGHT;
            end // (s_axis_tkeep == 32'h00000003)
          end else begin
            axis_tkeep = axis_tkeep_next;
            axis_tkeep_next = s_axis_tkeep;
          end // if (s_axis_tlast)
          small_packet = 0;
        end // WR_PKT_SHIFT_RIGHT

        LAST_PKT_SHIFT_RIGHT: begin // adds the last packet part
          axis_tvalid = 1;
          axis_tlast = 1;
          axis_tdata = {16'h0, axis_tdata_next[C_S_AXIS_DATA_WIDTH-17:0]};
          axis_tdata_next = 'h0;
          axis_tuser = axis_tuser_next;
          axis_tuser_next = 'h0;
          axis_tkeep = axis_tkeep_next;
          axis_tkeep_next = 'h0;
          state <= WAIT_PKT;
        end // LAST_PKT_SHIFT_RIGHT

        LAST_SMALL_PKT: begin // adds the last packet part
          axis_tvalid = 1;
          axis_tlast = 1;
          axis_tdata = axis_tdata;
          axis_tdata_next = 'h0;
          axis_tuser = axis_tuser;
          axis_tuser_next = 'h0;
          axis_tkeep = axis_tkeep;
          axis_tkeep_next = 'h0;
          small_packet = 0;
          state <= WAIT_PKT;
        end // LAST_PKT_SHIFT_RIGHT
      endcase

    end // if (~resetn)
  end // always @(posedge clk)

endmodule // packet_out_shifter
