/*
 * Copyright (c) 2024. All rights reserved.
 * Created by enrique, 6/12/24
 */

module tournament #(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty,
    parameter type bht_update_t = logic,
    parameter type bht_prediction_t = logic,
    parameter type bp_metadata_t = logic,
    parameter int unsigned MBP_ENTRIES = 256,
    parameter int unsigned GBP_ENTRIES = 256,
    parameter int unsigned LBP_ENTRIES = 256,
    parameter int unsigned LHR_ENTRIES = 256
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
    output bht_prediction_t [CVA6Cfg.INSTR_PER_FETCH-1:0] bht_prediction_o
);
    localparam type gbp_metadata_t = struct packed {
        logic [CVA6Cfg.GlobalPredictorIndexBits-1:0] index;
    };

    localparam type lbp_metadata_t = struct packed {
        logic [CVA6Cfg.LocalPredictorIndexBits-1:0] index;
    };

    localparam type gbp_prediction_t = struct packed {
        logic                    valid;
        logic                    taken;
        gbp_metadata_t           metadata;
    };

    localparam type lbp_prediction_t = struct packed {
        logic                    valid;
        logic                    taken;
        lbp_metadata_t           metadata;
    };

    localparam type gbp_update_t = struct packed {
        logic                    valid;
        logic [CVA6Cfg.VLEN-1:0] pc;     // update at PC
        logic                    taken;
        gbp_metadata_t           metadata;
    };

    localparam type lbp_update_t = struct packed {
        logic                    valid;
        logic [CVA6Cfg.VLEN-1:0] pc;     // update at PC
        logic                    taken;
        lbp_metadata_t           metadata;
    };

    bp_metadata_t metadata;
    gbp_update_t gbp_update;
    lbp_update_t lbp_update;
    gbp_prediction_t [CVA6Cfg.INSTR_PER_FETCH-1:0] gbp_prediction;
    lbp_prediction_t [CVA6Cfg.INSTR_PER_FETCH-1:0] lbp_prediction;
    logic            [CVA6Cfg.INSTR_PER_FETCH-1:0] select_prediction;

    assign metadata = bht_update_i.metadata;
    assign gbp_update = {bht_update_i.valid, bht_update_i.pc, bht_update_i.taken, metadata.gindex};
    assign lbp_update = {bht_update_i.valid, bht_update_i.pc, bht_update_i.taken, metadata.lindex};

    gbp #(
        .CVA6Cfg   (CVA6Cfg),
        .bht_update_t(gbp_update_t),
        .bht_prediction_t(gbp_prediction_t),
        .bp_metadata_t(gbp_metadata_t),
        .NR_ENTRIES(GBP_ENTRIES)
    ) i_gbp (
        .clk_i,
        .rst_ni,
        .flush_bp_i      (flush_bp_i),
        .debug_mode_i,
        .vpc_i           (vpc_i),
        .bht_update_i    (gbp_update),
        .bht_prediction_o(gbp_prediction)
    );

    lbp #(
        .CVA6Cfg   (CVA6Cfg),
        .bht_update_t(lbp_update_t),
        .bht_prediction_t(lbp_prediction_t),
        .bp_metadata_t(lbp_metadata_t),
        .LBP_ENTRIES(LBP_ENTRIES),
        .LHR_ENTRIES(LHR_ENTRIES)
    ) i_lbp (
        .clk_i,
        .rst_ni,
        .flush_bp_i      (flush_bp_i),
        .debug_mode_i,
        .vpc_i           (vpc_i),
        .bht_update_i    (lbp_update),
        .bht_prediction_o(lbp_prediction)
    );

    mbp #(
        .CVA6Cfg   (CVA6Cfg),
        .bht_update_t(bht_update_t),
        .bht_prediction_t(bht_prediction_t),
        .bp_metadata_t(bp_metadata_t),
        .NR_ENTRIES(MBP_ENTRIES)
    ) i_mbp (
        .clk_i,
        .rst_ni,
        .flush_bp_i      (flush_bp_i),
        .debug_mode_i,
        .vpc_i           (vpc_i),
        .bht_update_i    (bht_update_i),
        .select_prediction_o(select_prediction)
    );

    for (genvar i = 0; i < CVA6Cfg.INSTR_PER_FETCH; i++) begin
        assign bht_prediction_o[i].valid = (select_prediction[i] == 0 ? lbp_prediction[i].valid : gbp_prediction[i].valid);
        assign bht_prediction_o[i].taken = (select_prediction[i] == 0 ? lbp_prediction[i].taken : gbp_prediction[i].taken);
        assign bht_prediction_o[i].metadata.gindex = gbp_prediction[i].metadata.index;
        assign bht_prediction_o[i].metadata.gbp_valid = gbp_prediction[i].valid;
        assign bht_prediction_o[i].metadata.gbp_taken = gbp_prediction[i].taken;
        assign bht_prediction_o[i].metadata.lindex = lbp_prediction[i].metadata.index;
        assign bht_prediction_o[i].metadata.lbp_valid = lbp_prediction[i].valid;
        assign bht_prediction_o[i].metadata.lbp_taken = lbp_prediction[i].taken;
    end

endmodule