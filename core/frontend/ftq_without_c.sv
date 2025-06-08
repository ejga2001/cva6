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
    parameter type ftq_entry_t = logic,
    parameter int unsigned FTQ_FIFO_DEPTH = 8
)(
    input  logic                                    clk_i,
    input  logic                                    rst_ni,
    input  logic                                    flush_ftq_i,
    input  logic                                    debug_mode_i,
    input  logic [CVA6Cfg.VLEN-1:0]                 vpc_i,
    input  bht_update_t                             bht_update_i,
    input  ftq_entry_t                              ftq_entry_i,
    input  logic                                    instr_queue_overflow_i,
    input  logic                                    is_branch_i,
    output  ftq_entry_t                             ftq_entry_o,
    output logic                                    ftq_overflow_o
);
    // signals to make the predictions
    logic is_replay;
    logic is_valid_branch;

    // fetch target queue signals
    ftq_entry_t ftq_entry_in, ftq_entry_out;
    logic pop_ftq, push_ftq;
    logic full_ftq;

    assign ftq_entry_in = ftq_entry_i;
    assign push_ftq = is_valid_branch;
    assign pop_ftq = bht_update_i.valid;

    assign ftq_entry_o = ftq_entry_out;
    assign ftq_overflow_o = full_ftq & push_ftq;

    // if the incoming instruction is a replay
    assign is_replay = instr_queue_overflow_i;
    // an instruction is a valid branch instruction to push to fetch target queue if:
    // 1) it is a valid branch instruction
    // 2) it is not a replay
    assign is_valid_branch = is_branch_i & ~is_replay;

    fifo_v3 #(
        .DEPTH      (FTQ_FIFO_DEPTH),
        .dtype      (ftq_entry_t)
    ) i_fifo_ftq (
        .clk_i      (clk_i),
        .rst_ni     (rst_ni),
        .flush_i    (flush_ftq_i),
        .testmode_i (1'b0),
        .full_o     (full_ftq),
        .empty_o    (),
        .usage_o    (),
        .data_i     (ftq_entry_i),
        .push_i     (push_ftq & ~full_ftq),
        .data_o     (ftq_entry_o),
        .pop_i      (pop_ftq)
    );
endmodule