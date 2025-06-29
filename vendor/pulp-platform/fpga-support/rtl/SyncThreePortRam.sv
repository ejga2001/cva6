// Copyright 2024 PlanV Technologies
//
// Licensed under the Solderpad Hardware Licence, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.0
// You may obtain a copy of the License at https://solderpad.org/licenses
//
// Inferable, Asynchronous Three-Ports RAM, there are a write port and two read ports
//
//
// This module is designed to work with both Xilinx, Microchip and Altera FPGA tools by following the respective
// guidelines:
// - Xilinx UG901 Vivado Design Suite User Guide: Synthesis
// - Inferring Microchip PolarFire RAM Blocks
// - Altera Quartus II Handbook Volume 1: Design and Synthesis (p. 768)
//
// Current Maintainers:: Angela Gonzalez - PlanV Technologies

 
module SyncThreePortRam
#(
  parameter ADDR_WIDTH = 10,
  parameter DATA_DEPTH = 1024, // usually 2**ADDR_WIDTH, but can be lower
  parameter DATA_WIDTH = 32
)(
  input  logic                    Clk_CI,

  // Write port
  input  logic                    WrEn_SI,
  input  logic [ADDR_WIDTH-1:0]   WrAddr_DI,
  input  logic [DATA_WIDTH-1:0]   WrData_DI,
  
  // Read ports
  input  logic [ADDR_WIDTH-1:0]   RdAddr_DI_0,
  input  logic [ADDR_WIDTH-1:0]   RdAddr_DI_1,
  
  output logic [DATA_WIDTH-1:0]   RdData_DO_0,
  output logic [DATA_WIDTH-1:0]   RdData_DO_1
);

  logic [DATA_WIDTH-1:0] mem [DATA_DEPTH-1:0]= '{default:0};

  // WRITE
  always_ff @(posedge Clk_CI)
  begin
    if (WrEn_SI) begin
      mem[WrAddr_DI] <= WrData_DI;
    end
    
    RdData_DO_0 <= mem[RdAddr_DI_0];
    RdData_DO_1 <= mem[RdAddr_DI_1];
  
  end
  
  ////////////////////////////
  // assertions
  ////////////////////////////

  // pragma translate_off
  assert property
    (@(posedge Clk_CI) (longint'(2)**longint'(ADDR_WIDTH) >= longint'(DATA_DEPTH)))
    else $error("depth out of bounds");
  // pragma translate_on

endmodule 
