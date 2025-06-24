// Copyright 2018 - 2019 ETH Zurich and University of Bologna.
// Copyright 2023 - Thales for additionnal contribution.
// Copyright 2024 - PlanV Technologies for additionnal contribution.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 2.0 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-2.0. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.
//
// Author: Florian Zaruba, ETH Zurich
// Date: 08.02.2018
// Migrated: Luis Vitorio Cargnini, IEEE
// Date: 09.06.2018
// FPGA optimization: Sebastien Jacq, Thales
// Date: 2023-01-30
// FPGA optimization for Altera: Angela Gonzalez, PlanV Technolgies
// Date: 2024-10-16

// branch history table - 2 bit saturation counter

module mbp #(
  parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty,
  parameter type bht_update_t = logic,
  parameter type bht_prediction_t = logic,
  parameter type bp_metadata_t = logic,
  parameter int unsigned NR_ENTRIES = 1024
) (
  // Subsystem Clock - SUBSYSTEM
  input logic clk_i,
  // Asynchronous reset active low - SUBSYSTEM
  input logic rst_ni,
  // Branch prediction flush request - zero
  input logic flush_bp_i,
  // Debug mode state - CSR
  input logic debug_mode_i,
  // Virtual PC - CACHE
  input logic [CVA6Cfg.VLEN-1:0] vpc_i,
  // Update bht with resolved address - EXECUTE
  input bht_update_t bht_update_i,
  // Prediction from bht - FRONTEND
  output logic [CVA6Cfg.INSTR_PER_FETCH-1:0] select_prediction_o
);
  // the last bit is always zero, we don't need it for indexing
  localparam OFFSET = CVA6Cfg.RVC == 1'b1 ? 1 : 2;
  // re-shape the branch history table
  localparam NR_ROWS = NR_ENTRIES / CVA6Cfg.INSTR_PER_FETCH;
  // number of bits needed to index the row
  localparam ROW_ADDR_BITS = $clog2(CVA6Cfg.INSTR_PER_FETCH);
  localparam ROW_INDEX_BITS = CVA6Cfg.RVC == 1'b1 ? $clog2(CVA6Cfg.INSTR_PER_FETCH) : 1;
  // number of bits we should use for prediction
  localparam PREDICTION_BITS = $clog2(NR_ROWS) + OFFSET + ROW_ADDR_BITS;
  localparam CTR_MAX_VAL = (1 << CVA6Cfg.ChoiceCtrBits) - 1;

  typedef struct packed {
    logic [CVA6Cfg.ChoiceCtrBits-1:0] saturation_counter;
  } mbp_t;

  logic [$clog2(NR_ROWS)-1:0] index, update_pc;
  logic [ROW_INDEX_BITS-1:0] update_row_index;
  bp_metadata_t update_metadata;

  assign index     = vpc_i[PREDICTION_BITS-1:ROW_ADDR_BITS+OFFSET];
  assign update_metadata = bht_update_i.metadata;
  assign update_pc = bht_update_i.pc[PREDICTION_BITS-1:ROW_ADDR_BITS+OFFSET];
  if (CVA6Cfg.RVC) begin : gen_update_row_index
    assign update_row_index = bht_update_i.pc[ROW_ADDR_BITS+OFFSET-1:OFFSET];
  end else begin
    assign update_row_index = '0;
  end

  // number of bits par word in the bram
  localparam BRAM_WORD_BITS = $bits(mbp_t);
  logic [CVA6Cfg.INSTR_PER_FETCH-1:0] bht_ram_we;
  logic [CVA6Cfg.INSTR_PER_FETCH*$clog2(NR_ROWS)-1:0] bht_ram_read_address_0;
  logic [CVA6Cfg.INSTR_PER_FETCH*$clog2(NR_ROWS)-1:0] bht_ram_read_address_1;
  logic [CVA6Cfg.INSTR_PER_FETCH*$clog2(NR_ROWS)-1:0] bht_ram_write_address;
  logic [CVA6Cfg.INSTR_PER_FETCH*BRAM_WORD_BITS-1:0] bht_ram_wdata;
  logic [CVA6Cfg.INSTR_PER_FETCH*BRAM_WORD_BITS-1:0] bht_ram_rdata_0;
  logic [CVA6Cfg.INSTR_PER_FETCH*BRAM_WORD_BITS-1:0] bht_ram_rdata_1;

  mbp_t [CVA6Cfg.INSTR_PER_FETCH-1:0] bht;
  mbp_t [CVA6Cfg.INSTR_PER_FETCH-1:0] bht_updated;

  // -------------------------
  // prediction assignment & update Branch History Table
  // -------------------------
  always_comb begin : prediction_update_bht
    bht_ram_we = '0;
    bht_ram_read_address_0 = '0;
    bht_ram_read_address_1 = '0;
    bht_ram_write_address = '0;
    bht_ram_wdata = '0;
    bht_updated = '0;
    bht = '0;

    //Write to RAM
    if (bht_update_i.valid && !debug_mode_i) begin
      for (int i = 0; i < CVA6Cfg.INSTR_PER_FETCH; i++) begin
        if (update_row_index == i) begin
          bht_ram_we[i] = 1'b1;
          bht_ram_write_address[i*$clog2(NR_ROWS)+:$clog2(NR_ROWS)] = update_pc;
        end
      end
    end

    for (int i = 0; i < CVA6Cfg.INSTR_PER_FETCH; i++) begin
      if (update_row_index == i) begin
        bht_ram_read_address_1[i*$clog2(NR_ROWS)+:$clog2(NR_ROWS)] = update_pc;
        bht[i].saturation_counter = bht_ram_rdata_1[i*BRAM_WORD_BITS+:CVA6Cfg.ChoiceCtrBits];
        case (bht[i].saturation_counter)
          (CVA6Cfg.ChoiceCtrBits)'(0): begin
            if ((!update_metadata.lbp_valid || (bht_update_i.taken != update_metadata.lbp_taken))
                && (update_metadata.gbp_valid && (bht_update_i.taken == update_metadata.gbp_taken)))
                bht_updated[i].saturation_counter = bht[i].saturation_counter + 1;
            else
                bht_updated[i].saturation_counter = (CVA6Cfg.ChoiceCtrBits)'(0);
          end
          (CVA6Cfg.ChoiceCtrBits)'(CTR_MAX_VAL): begin
            if ((!update_metadata.gbp_valid || (bht_update_i.taken != update_metadata.gbp_taken))
                && (update_metadata.lbp_valid && (bht_update_i.taken == update_metadata.lbp_taken)))
                bht_updated[i].saturation_counter = bht[i].saturation_counter - 1;
            else
                bht_updated[i].saturation_counter = CTR_MAX_VAL;
          end
          default: begin
            if ((!update_metadata.gbp_valid || (bht_update_i.taken != update_metadata.gbp_taken))
                && (update_metadata.lbp_valid && (bht_update_i.taken == update_metadata.lbp_taken)))
                bht_updated[i].saturation_counter = bht[i].saturation_counter - 1;
            else if ((!update_metadata.lbp_valid || (bht_update_i.taken != update_metadata.lbp_taken))
                && (update_metadata.gbp_valid && (bht_update_i.taken == update_metadata.gbp_taken)))
                bht_updated[i].saturation_counter = bht[i].saturation_counter + 1;
            else
                bht_updated[i].saturation_counter = bht[i].saturation_counter;
          end
        endcase
        //The data written in the RAM will have the valid bit from current input (async RAM) or the one from one clock cycle before (sync RAM)
        bht_ram_wdata[i*BRAM_WORD_BITS+:BRAM_WORD_BITS] = {bht_updated[i].saturation_counter};
      end

      if (!rst_ni) begin
        //initialize output
        select_prediction_o[i] = '0;
      end else begin
        bht_ram_read_address_0[i*$clog2(NR_ROWS)+:$clog2(NR_ROWS)] = index;
        select_prediction_o[i] = bht_ram_rdata_0[i*BRAM_WORD_BITS+(CVA6Cfg.ChoiceCtrBits-1)];
      end
    end
  end

  for (genvar i = 0; i < CVA6Cfg.INSTR_PER_FETCH; i++) begin : gen_bht_ram
    AsyncThreePortRam #(
      .ADDR_WIDTH($clog2(NR_ROWS)),
      .DATA_DEPTH(NR_ROWS),
      .DATA_WIDTH(BRAM_WORD_BITS)
    ) i_bht_ram (
      .Clk_CI     (clk_i),
      .WrEn_SI    (bht_ram_we[i]),
      .WrAddr_DI  (bht_ram_write_address[i*$clog2(NR_ROWS)+:$clog2(NR_ROWS)]),
      .WrData_DI  (bht_ram_wdata[i*BRAM_WORD_BITS+:BRAM_WORD_BITS]),
      .RdAddr_DI_0(bht_ram_read_address_0[i*$clog2(NR_ROWS)+:$clog2(NR_ROWS)]),
      .RdAddr_DI_1(bht_ram_read_address_1[i*$clog2(NR_ROWS)+:$clog2(NR_ROWS)]),
      .RdData_DO_0(bht_ram_rdata_0[i*BRAM_WORD_BITS+:BRAM_WORD_BITS]),
      .RdData_DO_1(bht_ram_rdata_1[i*BRAM_WORD_BITS+:BRAM_WORD_BITS])
    );
  end
endmodule
