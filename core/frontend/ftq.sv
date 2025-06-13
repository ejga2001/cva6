// Copyright 2018 - 2019 ETH Zurich and University of Bologna.
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

module ftq #(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty,
    parameter type bht_update_t = logic,
    parameter type bp_metadata_t = logic,
    parameter int unsigned FTQ_FIFO_DEPTH = 8
)(
    input  logic                                    clk_i,
    input  logic                                    rst_ni,
    input  logic                                    flush_ftq_i,
    input  logic                                    debug_mode_i,
    input  logic [CVA6Cfg.VLEN-1:0]                 instr_queue_replay_addr_i,
    input  logic                                    serving_unaligned_i, // we have an unalinged instruction at the beginning
    input  bht_update_t                             bht_update_i,
    input  bp_metadata_t                            bp_metadata_i,
    input  logic                                    instr_queue_overflow_i,
    input  logic [CVA6Cfg.INSTR_PER_FETCH-1:0]      valid_i,
    input  logic [CVA6Cfg.INSTR_PER_FETCH-1:0]      is_branch_i,
    input  logic [CVA6Cfg.INSTR_PER_FETCH-1:0]      taken_rvi_cf_i,
    input  logic [CVA6Cfg.INSTR_PER_FETCH-1:0]      taken_rvc_cf_i,
    output bp_metadata_t                            bp_metadata_o,
    output logic                                    is_unaligned_o,
    output logic                                    ftq_overflow_o
);
    localparam type ftq_entry_t = struct packed {
        bp_metadata_t bp_metadata;
        logic         is_unaligned;
        logic [CVA6Cfg.LOG2_INSTR_PER_FETCH:0] bp_count;
    };

    // signals to make the predictions
    logic [CVA6Cfg.INSTR_PER_FETCH-1:0] valid_taken_cf;
    logic [CVA6Cfg.INSTR_PER_FETCH-1:0] is_replay;  // replay logic per instruction
    logic [CVA6Cfg.INSTR_PER_FETCH-1:0] is_valid_branch;
    logic [CVA6Cfg.LOG2_INSTR_PER_FETCH-1:0] replay_pos;

    // fetch target queue signals
    ftq_entry_t ftq_entry_in, ftq_entry_out;
    logic pop_ftq, push_ftq;
    logic full_ftq, empty_ftq;

    // count the number of rest valid predictions in that entry
    logic [CVA6Cfg.LOG2_INSTR_PER_FETCH:0] bp_count_d, bp_count_q;
    logic [CVA6Cfg.LOG2_INSTR_PER_FETCH:0] pop_count;

    // check if the instructions are valid control flows
    assign valid_taken_cf = valid_i & (taken_rvc_cf_i | taken_rvi_cf_i);

    assign push_ftq = (|is_valid_branch);
    assign pop_ftq = bht_update_i.valid & ((bp_count_q == 1) || ftq_entry_out.bp_count == 1);

    assign ftq_entry_in = {bp_metadata_i, serving_unaligned_i, pop_count};
    assign bp_metadata_o = ftq_entry_out.bp_metadata;
    assign is_unaligned_o = ftq_entry_out.is_unaligned;
    assign ftq_overflow_o = full_ftq & push_ftq;

    // if replay starts from an unaglined address, replay position should be 0.
    assign replay_pos = serving_unaligned_i ? 0 : instr_queue_replay_addr_i[CVA6Cfg.LOG2_INSTR_PER_FETCH:1];
    // if the incoming instruction is a replay at the replay address, then the rest of the fetched
    // instruction should also be replay. For example, in 64 bit fetch if the replay starts from 0x42,
    // the replay mask should be 1 1 1 0 from the highest to lowest.
    assign is_replay = {CVA6Cfg.INSTR_PER_FETCH{instr_queue_overflow_i}} << replay_pos;
    // an instruction is a valid branch instruction to push to fetch target queue if:
    // 1) it is a valid branch instruction
    // 2) it is not a replay
    // 3) no taken control flow before it in the same fetch block
    for (genvar i = 0; i < CVA6Cfg.INSTR_PER_FETCH; i++) begin
        if (i == 0) begin
            assign is_valid_branch[i] = is_branch_i[i] & ~is_replay[i];
        end else begin
            assign is_valid_branch[i] = is_branch_i[i] & ~(|valid_taken_cf[i-1:0]) & ~is_replay[i];
        end
    end

    // count the numbers of valid branch predictions in this fetch
    popcount #(
        .INPUT_WIDTH(CVA6Cfg.INSTR_PER_FETCH)
    ) i_popcount_bp (
        .data_i(is_valid_branch),
        .popcount_o(pop_count)
    );

    cva6_fifo_v3 #(
        .DEPTH      (FTQ_FIFO_DEPTH),
        .dtype      (ftq_entry_t)
    ) i_fifo_ftq (
        .clk_i      (clk_i),
        .rst_ni     (rst_ni),
        .flush_i    (flush_ftq_i),
        .testmode_i (1'b0),
        .full_o     (full_ftq),
        .empty_o    (empty_ftq),
        .usage_o    (),
        .data_i     (ftq_entry_in),
        .push_i     (push_ftq & ~full_ftq & ~instr_queue_overflow_i),
        .data_o     (ftq_entry_out),
        .pop_i      (pop_ftq)
    );

    always_comb begin : update_bp_counter
        // update the valid branch prediction counter
        // if the count is decreased to zero due to the previous bp, then the counter should be updated
        // to the number of the new ftq entry. Else the counter should be decreased by 1.
        if (bp_count_q == '0) begin
            bp_count_d = (bht_update_i.valid & ~debug_mode_i) ? ftq_entry_out.bp_count - 1 : empty_ftq ? '0 : ftq_entry_out.bp_count;
        end
        else begin
            bp_count_d = (bht_update_i.valid & ~debug_mode_i) ? bp_count_q - 1 : bp_count_q;
        end
    end : update_bp_counter

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni || flush_ftq_i) begin
            bp_count_q <= '0;
        end else begin
            bp_count_q <= bp_count_d;
        end
    end
endmodule