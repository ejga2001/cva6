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

module lbp #(
  parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty,
  parameter type bht_update_t = logic,
  parameter type bht_prediction_t = logic,
  parameter type bp_metadata_t = logic,
  parameter int unsigned LBP_ENTRIES = 512,
  parameter int unsigned LHR_ENTRIES = 512
) (
  // Subsystem Clock - SUBSYSTEM
  input logic clk_i,
  // Asynchronous reset active low - SUBSYSTEM
  input logic rst_ni,
  // Branch prediction flush request - zero
  input logic flush_bp_i,
  // Debug mode state - CSR
  input logic debug_mode_i,
  // Virtual PC - CACHEA
  input logic [CVA6Cfg.VLEN-1:0] vpc_i,
  // Update bht with resolved address - EXECUTE
  input bht_update_t bht_update_i,
  // Prediction from bht - FRONTEND
  output bht_prediction_t [CVA6Cfg.INSTR_PER_FETCH-1:0] bht_prediction_o
);
  // the last bit is always zero, we don't need it for indexing
  localparam OFFSET = CVA6Cfg.RVC == 1'b1 ? 1 : 2;
  // re-shape the branch history table
  localparam NR_ROWS_LBP = LBP_ENTRIES / CVA6Cfg.INSTR_PER_FETCH;
  // re-shape the LHR table
  localparam NR_ROWS_LHR = LHR_ENTRIES / CVA6Cfg.INSTR_PER_FETCH;
  // number of bits needed to index the row
  localparam ROW_ADDR_BITS = $clog2(CVA6Cfg.INSTR_PER_FETCH);
  localparam ROW_INDEX_BITS = CVA6Cfg.RVC == 1'b1 ? $clog2(CVA6Cfg.INSTR_PER_FETCH) : 1;
  // number of bits we should use for local history
  localparam HISTORY_BITS = $clog2(NR_ROWS_LHR) + OFFSET + ROW_ADDR_BITS;

  localparam CTR_MAX_VAL = (1 << CVA6Cfg.LocalCtrBits) - 1;

  // Branch Prediction Register bits
  localparam LHR_WORD_BITS = $clog2(NR_ROWS_LBP);

  typedef struct packed {
    logic                            valid;
    logic [CVA6Cfg.LocalCtrBits-1:0] saturation_counter;
  } lbp_t;

  struct packed {
    logic       valid;
    logic [1:0] saturation_counter;
  } bht_d[NR_ROWS_LBP-1:0][CVA6Cfg.INSTR_PER_FETCH-1:0], bht_q[NR_ROWS_LBP-1:0][CVA6Cfg.INSTR_PER_FETCH-1:0];

  logic [$clog2(NR_ROWS_LHR)-1:0] index, update_pc;
  logic [ROW_INDEX_BITS-1:0] update_row_index, update_row_index_q, check_update_row_index;
  bp_metadata_t metadata, update_metadata;

  assign index           = vpc_i[HISTORY_BITS-1:ROW_ADDR_BITS+OFFSET];
  assign update_metadata = bht_update_i.metadata;
  assign update_pc       = bht_update_i.pc[HISTORY_BITS-1:ROW_ADDR_BITS+OFFSET];
  if (CVA6Cfg.RVC) begin : gen_update_row_index
    assign update_row_index = bht_update_i.pc[ROW_ADDR_BITS+OFFSET-1:OFFSET];
  end else begin
    assign update_row_index = '0;
  end

  if (!CVA6Cfg.FpgaEn) begin : gen_asic_bht  // ASIC TARGET

    logic [1:0] saturation_counter;
    // prediction assignment
    for (genvar i = 0; i < CVA6Cfg.INSTR_PER_FETCH; i++) begin : gen_bht_output
      assign bht_prediction_o[i].valid = bht_q[index][i].valid;
      assign bht_prediction_o[i].taken = bht_q[index][i].saturation_counter[1] == 1'b1;
    end

    always_comb begin : update_bht
      bht_d = bht_q;
      saturation_counter = bht_q[update_pc][update_row_index].saturation_counter;

      if ((bht_update_i.valid && CVA6Cfg.DebugEn && !debug_mode_i) || (bht_update_i.valid && !CVA6Cfg.DebugEn)) begin
        bht_d[update_pc][update_row_index].valid = 1'b1;

        if (saturation_counter == 2'b11) begin
          // we can safely decrease it
          if (!bht_update_i.taken)
              bht_d[update_pc][update_row_index].saturation_counter = saturation_counter - 1;
          // then check if it saturated in the negative regime e.g.: branch not taken
        end else if (saturation_counter == 2'b00) begin
          // we can safely increase it
          if (bht_update_i.taken)
              bht_d[update_pc][update_row_index].saturation_counter = saturation_counter + 1;
        end else begin  // otherwise we are not in any boundaries and can decrease or increase it
          if (bht_update_i.taken)
              bht_d[update_pc][update_row_index].saturation_counter = saturation_counter + 1;
          else bht_d[update_pc][update_row_index].saturation_counter = saturation_counter - 1;
        end
      end
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
      if (!rst_ni) begin
        for (int unsigned i = 0; i < NR_ROWS_LBP; i++) begin
          for (int j = 0; j < CVA6Cfg.INSTR_PER_FETCH; j++) begin
            bht_q[i][j] <= '0;
          end
        end
      end else begin
        // evict all entries
        if (flush_bp_i) begin
          for (int i = 0; i < NR_ROWS_LBP; i++) begin
            for (int j = 0; j < CVA6Cfg.INSTR_PER_FETCH; j++) begin
              bht_q[i][j].valid <= 1'b0;
              bht_q[i][j].saturation_counter <= 2'b10;
            end
          end
        end else begin
          bht_q <= bht_d;
        end
      end
    end

  end else begin : gen_fpga_bht  //FPGA TARGETS

    // number of bits par word in the bram
    localparam BRAM_WORD_BITS = $bits(lbp_t);
    logic [ROW_INDEX_BITS-1:0] row_index, row_index_q, check_row_index;
    logic [CVA6Cfg.INSTR_PER_FETCH-1:0] bht_ram_we, bht_ram_we_q;
    logic [CVA6Cfg.INSTR_PER_FETCH*$clog2(NR_ROWS_LBP)-1:0] bht_ram_read_address_0;
    logic [CVA6Cfg.INSTR_PER_FETCH*$clog2(NR_ROWS_LBP)-1:0] bht_ram_read_address_1;
    logic [CVA6Cfg.INSTR_PER_FETCH*$clog2(NR_ROWS_LBP)-1:0] bht_ram_write_address, bht_ram_write_address_q;
    logic [CVA6Cfg.INSTR_PER_FETCH*BRAM_WORD_BITS-1:0] bht_ram_wdata, bht_ram_wdata_q;
    logic [CVA6Cfg.INSTR_PER_FETCH*BRAM_WORD_BITS-1:0] bht_ram_rdata_0;
    logic [CVA6Cfg.INSTR_PER_FETCH*BRAM_WORD_BITS-1:0] bht_ram_rdata_1;

    logic [CVA6Cfg.INSTR_PER_FETCH-1:0] lhr_ram_we;
    logic [CVA6Cfg.INSTR_PER_FETCH*$clog2(NR_ROWS_LHR)-1:0] lhr_ram_write_address;
    logic [CVA6Cfg.INSTR_PER_FETCH*LHR_WORD_BITS-1:0] lhr_ram_wdata;
    logic [CVA6Cfg.INSTR_PER_FETCH*$clog2(NR_ROWS_LHR)-1:0] lhr_ram_read_address_0;
    logic [CVA6Cfg.INSTR_PER_FETCH*$clog2(NR_ROWS_LHR)-1:0] lhr_ram_read_address_1;
    logic [CVA6Cfg.INSTR_PER_FETCH*LHR_WORD_BITS-1:0] lhr_ram_rdata_0;
    logic [CVA6Cfg.INSTR_PER_FETCH*LHR_WORD_BITS-1:0] lhr_ram_rdata_1;

    lbp_t [CVA6Cfg.INSTR_PER_FETCH-1:0] bht;
    lbp_t [CVA6Cfg.INSTR_PER_FETCH-1:0] bht_updated;
    logic [CVA6Cfg.INSTR_PER_FETCH-1:0][LHR_WORD_BITS-1:0] lhr;
    logic [CVA6Cfg.INSTR_PER_FETCH-1:0][LHR_WORD_BITS-1:0] lhr_updated;

    logic [CVA6Cfg.INSTR_PER_FETCH-1:0][1:0] bht_updated_valid;
    logic [CVA6Cfg.INSTR_PER_FETCH-1:0][1:0][CVA6Cfg.VLEN-1:0] bht_updated_pc;
    logic bht_update_taken, check_bht_update_taken;
    logic [CVA6Cfg.VLEN-1:0] vpc_q;

    if (CVA6Cfg.RVC) begin : gen_row_index
      assign row_index = vpc_i[ROW_ADDR_BITS+OFFSET-1:OFFSET];
    end else begin
      assign row_index = '0;
    end

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

      lhr_ram_we = '0;
      lhr_ram_read_address_0 = '0;
      lhr_ram_read_address_1 = '0;
      lhr_ram_write_address = '0;
      lhr_ram_wdata = '0;
      lhr_updated = '0;
      lhr = '0;

      //Write to RAM
      if (bht_update_i.valid && !debug_mode_i) begin
        for (int i = 0; i < CVA6Cfg.INSTR_PER_FETCH; i++) begin
          if (update_row_index == i) begin
            lhr_ram_we[i] = 1'b1;
            bht_updated[i].valid = 1'b1;
            bht_ram_we[i] = 1'b1;
            lhr_ram_write_address[i*$clog2(NR_ROWS_LHR)+:$clog2(NR_ROWS_LHR)] = update_pc;
            bht_ram_write_address[i*$clog2(NR_ROWS_LBP)+:$clog2(NR_ROWS_LBP)] = update_metadata.index;
          end
        end
      end

      for (int i = 0; i < CVA6Cfg.INSTR_PER_FETCH; i++) begin
        if (check_update_row_index == i) begin
          //When asynchronous RAM is used, the address can be updated on the cycle when data is read
          if (!CVA6Cfg.FpgaAlteraEn) begin
            lhr_ram_read_address_1[i*$clog2(NR_ROWS_LHR)+:$clog2(NR_ROWS_LHR)] = update_pc;
            bht_ram_read_address_1[i*$clog2(NR_ROWS_LBP)+:$clog2(NR_ROWS_LBP)] = update_metadata.index;
          end
          lhr[i] = lhr_ram_rdata_1[i*LHR_WORD_BITS+:LHR_WORD_BITS];
          bht[i].saturation_counter = bht_ram_rdata_1[i*BRAM_WORD_BITS+:CVA6Cfg.LocalCtrBits];
          if (bht[i].saturation_counter == CTR_MAX_VAL) begin
            // we can safely decrease it
            if (!check_bht_update_taken)
                bht_updated[i].saturation_counter = bht[i].saturation_counter - 1;
            else bht_updated[i].saturation_counter = CTR_MAX_VAL;
            // then check if it saturated in the negative regime e.g.: branch not taken
          end else if (bht[i].saturation_counter == (CVA6Cfg.LocalCtrBits)'(0)) begin
            // we can safely increase it
            if (check_bht_update_taken)
                bht_updated[i].saturation_counter = bht[i].saturation_counter + 1;
            else bht_updated[i].saturation_counter = (CVA6Cfg.LocalCtrBits)'(0);
          end else begin  // otherwise we are not in any boundaries and can decrease or increase it
            if (check_bht_update_taken)
                bht_updated[i].saturation_counter = bht[i].saturation_counter + 1;
            else bht_updated[i].saturation_counter = bht[i].saturation_counter - 1;
          end
          lhr_updated[i] = {lhr[i][LHR_WORD_BITS-2:0], check_bht_update_taken};
          //The data written in the RAM will have the valid bit from current input (async RAM) or the one from one clock cycle before (sync RAM)
          lhr_ram_wdata[i*LHR_WORD_BITS+:LHR_WORD_BITS] = lhr_updated[i];
          bht_ram_wdata[i*BRAM_WORD_BITS+:BRAM_WORD_BITS] = CVA6Cfg.FpgaAlteraEn ? {bht_updated_valid[i][0], bht_updated[i].saturation_counter} :
              {bht_updated[i].valid, bht_updated[i].saturation_counter};
        end

        if (!rst_ni) begin
          //initialize output
          bht_prediction_o[i] = '0;
        end else begin
          //When asynchronous RAM is used, addresses can be calculated on the same cycle as data is read
          if (!CVA6Cfg.FpgaAlteraEn) begin
            lhr_ram_read_address_0[i*$clog2(NR_ROWS_LHR)+:$clog2(NR_ROWS_LHR)] = index;
            bht_ram_read_address_0[i*$clog2(NR_ROWS_LBP)+:$clog2(NR_ROWS_LBP)] = lhr_ram_rdata_0[i*LHR_WORD_BITS+:LHR_WORD_BITS];
          end
          //When synchronous RAM is used and data is read right after writing, we need some buffering
          // This is one cycle of buffering
          if (CVA6Cfg.FpgaAlteraEn && bht_updated_valid[i][0] && vpc_q == bht_updated_pc[i][0]) begin
            bht_prediction_o[i].valid = bht_ram_wdata[i*BRAM_WORD_BITS+CVA6Cfg.LocalCtrBits];
            bht_prediction_o[i].taken = bht_ram_wdata[i*BRAM_WORD_BITS+(CVA6Cfg.LocalCtrBits-1)];
            //This is two cycles of buffering
          end else if (CVA6Cfg.FpgaAlteraEn && bht_updated_valid[i][1] && vpc_q == bht_updated_pc[i][1]) begin
            bht_prediction_o[i].valid = bht_ram_wdata_q[i*BRAM_WORD_BITS+CVA6Cfg.LocalCtrBits];
            bht_prediction_o[i].taken = bht_ram_wdata_q[i*BRAM_WORD_BITS+(CVA6Cfg.LocalCtrBits-1)];
            //In any other case we can safely read from the RAM as data is available
          end else begin
            metadata.index = lhr_ram_rdata_0[i*LHR_WORD_BITS+:LHR_WORD_BITS];
            bht_prediction_o[i].valid = bht_ram_rdata_0[i*BRAM_WORD_BITS+CVA6Cfg.LocalCtrBits];
            bht_prediction_o[i].taken = bht_ram_rdata_0[i*BRAM_WORD_BITS+(CVA6Cfg.LocalCtrBits-1)];
            bht_prediction_o[i].metadata = metadata;
          end
        end
      end
    end

    for (genvar i = 0; i < CVA6Cfg.INSTR_PER_FETCH; i++) begin : gen_bht_ram
      if (CVA6Cfg.FpgaAlteraEn) begin : gen_sync_ram
        SyncThreePortRam #(
          .ADDR_WIDTH($clog2(NR_ROWS_LBP)),
          .DATA_DEPTH(NR_ROWS_LBP),
          .DATA_WIDTH(BRAM_WORD_BITS)
        ) i_bht_ram (
          .Clk_CI     (clk_i),
          .WrEn_SI    (bht_ram_we_q[i]),
          .WrAddr_DI  (bht_ram_write_address_q[i*$clog2(NR_ROWS_LBP)+:$clog2(NR_ROWS_LBP)]),
          .WrData_DI  (bht_ram_wdata[i*BRAM_WORD_BITS+:BRAM_WORD_BITS]),
          .RdAddr_DI_0(bht_ram_read_address_0[i*$clog2(NR_ROWS_LBP)+:$clog2(NR_ROWS_LBP)]),
          .RdAddr_DI_1(bht_ram_read_address_1[i*$clog2(NR_ROWS_LBP)+:$clog2(NR_ROWS_LBP)]),
          .RdData_DO_0(bht_ram_rdata_0[i*BRAM_WORD_BITS+:BRAM_WORD_BITS]),
          .RdData_DO_1(bht_ram_rdata_1[i*BRAM_WORD_BITS+:BRAM_WORD_BITS])
        );
      end else begin : gen_async_ram
        AsyncThreePortRam #(
          .ADDR_WIDTH($clog2(NR_ROWS_LBP)),
          .DATA_DEPTH(NR_ROWS_LBP),
          .DATA_WIDTH(BRAM_WORD_BITS)
        ) i_bht_ram (
          .Clk_CI     (clk_i),
          .WrEn_SI    (bht_ram_we[i]),
          .WrAddr_DI  (bht_ram_write_address[i*$clog2(NR_ROWS_LBP)+:$clog2(NR_ROWS_LBP)]),
          .WrData_DI  (bht_ram_wdata[i*BRAM_WORD_BITS+:BRAM_WORD_BITS]),
          .RdAddr_DI_0(bht_ram_read_address_0[i*$clog2(NR_ROWS_LBP)+:$clog2(NR_ROWS_LBP)]),
          .RdAddr_DI_1(bht_ram_read_address_1[i*$clog2(NR_ROWS_LBP)+:$clog2(NR_ROWS_LBP)]),
          .RdData_DO_0(bht_ram_rdata_0[i*BRAM_WORD_BITS+:BRAM_WORD_BITS]),
          .RdData_DO_1(bht_ram_rdata_1[i*BRAM_WORD_BITS+:BRAM_WORD_BITS])
        );
        AsyncThreePortRam #(
          .ADDR_WIDTH($clog2(NR_ROWS_LHR)),
          .DATA_DEPTH(NR_ROWS_LHR),
          .DATA_WIDTH(LHR_WORD_BITS)
        ) i_lhr_ram (
          .Clk_CI     (clk_i),
          .WrEn_SI    (lhr_ram_we[i]),
          .WrAddr_DI  (lhr_ram_write_address[i*$clog2(NR_ROWS_LHR)+:$clog2(NR_ROWS_LHR)]),
          .WrData_DI  (lhr_ram_wdata[i*LHR_WORD_BITS+:LHR_WORD_BITS]),
          .RdAddr_DI_0(lhr_ram_read_address_0[i*$clog2(NR_ROWS_LHR)+:$clog2(NR_ROWS_LHR)]),
          .RdAddr_DI_1(lhr_ram_read_address_1[i*$clog2(NR_ROWS_LHR)+:$clog2(NR_ROWS_LHR)]),
          .RdData_DO_0(lhr_ram_rdata_0[i*LHR_WORD_BITS+:LHR_WORD_BITS]),
          .RdData_DO_1(lhr_ram_rdata_1[i*LHR_WORD_BITS+:LHR_WORD_BITS])
        );
      end
    end

    // Extra buffering signals needed when synchronous RAM is used

    always_ff @(posedge clk_i or negedge rst_ni) begin
      if (CVA6Cfg.FpgaAlteraEn) begin
        if (!rst_ni) begin
          bht_updated_valid <= '0;
          bht_update_taken <= '0;
          bht_ram_wdata_q <= '0;
          row_index_q <= '0;
          bht_ram_we_q <= '0;
          bht_ram_write_address_q <= '0;
          update_row_index_q <= '0;
        end else begin
          for (int i = 0; i < CVA6Cfg.INSTR_PER_FETCH; i++) begin
            bht_updated_valid[i][1] <= bht_updated_valid[i][0];
            bht_updated_valid[i][0] <= bht_updated[i].valid;
            bht_updated_pc[i][1] <= bht_updated_pc[i][0];
            bht_updated_pc[i][0] <= bht_update_i.pc;
          end
          vpc_q <= vpc_i;
          bht_update_taken <= bht_update_i.taken;
          bht_ram_wdata_q <= bht_ram_wdata;
          bht_ram_we_q <= bht_ram_we;
          bht_ram_write_address_q <= bht_ram_write_address;
          update_row_index_q <= update_row_index;
          row_index_q <= row_index;
        end
      end
    end

    // Assignment of indexes checked to generate data written in the RAM. When synchronous RAM is used these signals need to be delayed
    assign check_update_row_index = CVA6Cfg.FpgaAlteraEn ? update_row_index_q : update_row_index;
    assign check_bht_update_taken = CVA6Cfg.FpgaAlteraEn ? bht_update_taken : bht_update_i.taken;
    assign check_row_index        = CVA6Cfg.FpgaAlteraEn ? row_index_q : row_index;

  end
endmodule
