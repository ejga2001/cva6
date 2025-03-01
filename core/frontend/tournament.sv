/*
 * Copyright (c) 2024. All rights reserved.
 * Created by enrique, 6/12/24
 */

module tournament #(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty,
    parameter type bht_update_t = logic,
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
    output ariane_pkg::bht_prediction_t [CVA6Cfg.INSTR_PER_FETCH-1:0] bht_prediction_o
);

    ariane_pkg::bht_prediction_t [CVA6Cfg.INSTR_PER_FETCH-1:0] mbp_prediction;
    ariane_pkg::bht_prediction_t [CVA6Cfg.INSTR_PER_FETCH-1:0] lbp_prediction;
    ariane_pkg::bht_prediction_t [CVA6Cfg.INSTR_PER_FETCH-1:0] gbp_prediction;

    mbp #(
        .CVA6Cfg   (CVA6Cfg),
        .bht_update_t(bht_update_t),
        .NR_ENTRIES(MBP_ENTRIES)
    ) i_mbp (
        .clk_i,
        .rst_ni,
        .flush_bp_i      (flush_bp_i),
        .debug_mode_i,
        .vpc_i           (vpc_i),
        .bht_update_i    (bht_update_i),
        .lbp_prediction_i(lbp_prediction),
        .gbp_prediction_i(gbp_prediction),
        .select_prediction_o(mbp_prediction)
    );
    gbp #(
        .CVA6Cfg   (CVA6Cfg),
        .bht_update_t(bht_update_t),
        .NR_ENTRIES(GBP_ENTRIES)
    ) i_gbp (
        .clk_i,
        .rst_ni,
        .flush_bp_i      (flush_bp_i),
        .debug_mode_i,
        .vpc_i           (vpc_i),
        .bht_update_i    (bht_update_i),
        .bht_prediction_o(gbp_prediction)
    );
    lbp #(
        .CVA6Cfg   (CVA6Cfg),
        .bht_update_t(bht_update_t),
        .LBP_ENTRIES(LBP_ENTRIES),
        .LHR_ENTRIES(LHR_ENTRIES)
    ) i_lbp (
        .clk_i,
        .rst_ni,
        .flush_bp_i      (flush_bp_i),
        .debug_mode_i,
        .vpc_i           (vpc_i),
        .bht_update_i    (bht_update_i),
        .bht_prediction_o(lbp_prediction)
    );

    for (genvar i = 0; i < CVA6Cfg.INSTR_PER_FETCH; i++) begin
        assign bht_prediction_o[i] = (mbp_prediction[i].taken == 0 ? lbp_prediction[i] : gbp_prediction[i]);
    end

endmodule