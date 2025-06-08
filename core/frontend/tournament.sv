/*
 * Copyright (c) 2024. All rights reserved.
 * Created by enrique, 6/12/24
 */

module tournament #(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty,
    parameter type bht_update_t = logic,
    parameter type bht_prediction_t = logic,
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
    // Update gbp with saved metadata - FTQ
    input logic [CVA6Cfg.GlobalPredictorIndexBits-1:0] update_gindex_i,
    input bht_prediction_t [CVA6Cfg.INSTR_PER_FETCH-1:0] update_gbp_pred_i,
    // Update lbp with saved metadata - FTQ
    input logic [CVA6Cfg.LocalPredictorIndexBits-1:0] update_lindex_i,
    input bht_prediction_t [CVA6Cfg.INSTR_PER_FETCH-1:0] update_lbp_pred_i,
    // Prediction from bht - FRONTEND
    output bht_prediction_t [CVA6Cfg.INSTR_PER_FETCH-1:0] bht_prediction_o,
    // GBP metadata to store it for a future update - FTQ
    output logic [CVA6Cfg.GlobalPredictorIndexBits-1:0] gindex_o,
    output bht_prediction_t [CVA6Cfg.INSTR_PER_FETCH-1:0] gbp_pred_o,
    // LBP metadata to store it for a future update - FTQ
    output logic [CVA6Cfg.LocalPredictorIndexBits-1:0] lindex_o,
    output bht_prediction_t [CVA6Cfg.INSTR_PER_FETCH-1:0] lbp_pred_o
);

    bht_prediction_t [CVA6Cfg.INSTR_PER_FETCH-1:0] gbp_prediction;
    bht_prediction_t [CVA6Cfg.INSTR_PER_FETCH-1:0] lbp_prediction;
    logic            [CVA6Cfg.INSTR_PER_FETCH-1:0] select_prediction;

    gbp #(
        .CVA6Cfg   (CVA6Cfg),
        .bht_update_t(bht_update_t),
        .bht_prediction_t(bht_prediction_t),
        .NR_ENTRIES(GBP_ENTRIES)
    ) i_gbp (
        .clk_i,
        .rst_ni,
        .flush_bp_i      (flush_bp_i),
        .debug_mode_i,
        .vpc_i           (vpc_i),
        .bht_update_i    (bht_update_i),
        .update_index_i(update_gindex_i),
        .bht_prediction_o(gbp_prediction),
        .index_o(gindex_o)
    );
    lbp #(
        .CVA6Cfg   (CVA6Cfg),
        .bht_update_t(bht_update_t),
        .bht_prediction_t(bht_prediction_t),
        .LBP_ENTRIES(LBP_ENTRIES),
        .LHR_ENTRIES(LHR_ENTRIES)
    ) i_lbp (
        .clk_i,
        .rst_ni,
        .flush_bp_i      (flush_bp_i),
        .debug_mode_i,
        .vpc_i           (vpc_i),
        .bht_update_i    (bht_update_i),
        .update_index_i(update_lindex_i),
        .bht_prediction_o(lbp_prediction),
        .index_o(lindex_o)
    );
    mbp #(
        .CVA6Cfg   (CVA6Cfg),
        .bht_update_t(bht_update_t),
        .bht_prediction_t(bht_prediction_t),
        .NR_ENTRIES(MBP_ENTRIES)
    ) i_mbp (
        .clk_i,
        .rst_ni,
        .flush_bp_i      (flush_bp_i),
        .debug_mode_i,
        .vpc_i           (vpc_i),
        .bht_update_i    (bht_update_i),
        .update_gbp_pred_i(update_gbp_pred_i),
        .update_lbp_pred_i(update_lbp_pred_i),
        .select_prediction_o(select_prediction)
    );

    for (genvar i = 0; i < CVA6Cfg.INSTR_PER_FETCH; i++) begin
        assign gbp_pred_o[i] = gbp_prediction[i];
        assign lbp_pred_o[i] = lbp_prediction[i];
        assign bht_prediction_o[i] = (select_prediction[i] == 0 ? lbp_prediction[i] : gbp_prediction[i]);
    end

endmodule