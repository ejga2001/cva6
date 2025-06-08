/*
 * Copyright (c) 2025. All rights reserved.
 * Created by enrique, 16/05/25
 */

`timescale 1ns/1ns
interface bht_frontend_if #(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty,
    parameter CLOCK_PERIOD = 20ns
) (
    input logic clk_i,
    input logic rst_ni
);
    // Virtual PC - CACHE
    logic [CVA6Cfg.VLEN-1:0] vpc_i;

    // Prediction from bht - FRONTEND
    ariane_pkg::bht_prediction_t [CVA6Cfg.INSTR_PER_FETCH-1:0] bht_prediction_o;

    clocking cb_drv @(posedge clk_i);
        default input #(CLOCK_PERIOD/2) output #0;
        input bht_prediction_o;
        output vpc_i;
    endclocking : cb_drv

endinterface : bht_frontend_if