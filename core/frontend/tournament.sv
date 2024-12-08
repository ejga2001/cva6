/*
 * Copyright (c) 2024. All rights reserved.
 * Created by enrique, 6/12/24
 */

function automatic void update_saturation_counter(
    input ariane_pkg::bht_t bht,
    input logic check_bht_update_taken,
    ref ariane_pkg::bht_t bht_updated
);
    case (bht.saturation_counter)
        2'b00: begin
            bht_updated.saturation_counter = (check_bht_update_taken == 0) ? 2'b00 :
                bht.saturation_counter + 1;
        end
        2'b01, 2'b10: begin
            bht.saturation_counter = (check_bht_update_taken == 0) ? bht.saturation_counter - 1:
                bht.saturation_counter + 1;
        end
        2'b11: begin
            bht.saturation_counter = (check_bht_update_taken == 1) ? 2'b11 :
                bht.saturation_counter - 1;
        end
        default: begin
            bht_updated.saturation_counter = 2'b00;
        end
    endcase
endfunction

module tournament #(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty,
    parameter type bht_update_t = logic,
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
    output ariane_pkg::bht_prediction_t [CVA6Cfg.INSTR_PER_FETCH-1:0] bht_prediction_o
);

    ariane_pkg::bht_prediction_t [CVA6Cfg.INSTR_PER_FETCH-1:0] mbp_prediction;
    ariane_pkg::bht_prediction_t [CVA6Cfg.INSTR_PER_FETCH-1:0] lbp_prediction;
    ariane_pkg::bht_prediction_t [CVA6Cfg.INSTR_PER_FETCH-1:0] gbp_prediction;

    logic [CVA6Cfg.INSTR_PER_FETCH-1:0] local_correct, global_correct;

    mbp #(
        .CVA6Cfg   (CVA6Cfg),
        .bht_update_t(bht_update_t),
        .NR_ENTRIES(CVA6Cfg.BHTEntries)
    ) i_mbp (
        .clk_i,
        .rst_ni,
        .flush_bp_i      (flush_bp_i),
        .debug_mode_i,
        .vpc_i           (vpc_i),
        .bht_update_i    (bht_update_i),
        .local_correct_i(local_correct),
        .global_correct_i(global_correct),
        .bht_prediction_o(mbp_prediction)
    );
    lbp #(
        .CVA6Cfg   (CVA6Cfg),
        .bht_update_t(bht_update_t),
        .NR_ENTRIES(CVA6Cfg.BHTEntries)
    ) i_lbp (
        .clk_i,
        .rst_ni,
        .flush_bp_i      (flush_bp_i),
        .debug_mode_i,
        .vpc_i           (vpc_i),
        .bht_update_i    (bht_update_i),
        .bht_prediction_o(lbp_prediction),
        .local_correct_o(local_correct)
    );
    gbp #(
        .CVA6Cfg   (CVA6Cfg),
        .bht_update_t(bht_update_t),
        .NR_ENTRIES(CVA6Cfg.BHTEntries)
    ) i_gbp (
        .clk_i,
        .rst_ni,
        .flush_bp_i      (flush_bp_i),
        .debug_mode_i,
        .vpc_i           (vpc_i),
        .bht_update_i    (bht_update_i),
        .bht_prediction_o(gbp_prediction),
        .global_correct_o(global_correct)
    );

    for (genvar i = 0; i < CVA6Cfg.INSTR_PER_FETCH; i++) begin
        assign bht_prediction_o[i] = (mbp_prediction[i].taken == 0) ? lbp_prediction[i] : gbp_prediction[i];
    end

endmodule