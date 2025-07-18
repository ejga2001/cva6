/*
 * Copyright (c) 2025. All rights reserved.
 * Created by enrique, 16/05/25
 */

`timescale 1ns/1ns
interface bht_if #(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty,
    parameter type bht_update_t = logic,
    parameter type bht_prediction_t = logic,
    parameter CLOCK_PERIOD = 20ns
) (
    input logic clk_i,
    input logic rst_ni
);
    // Virtual PC - CACHE
    logic [CVA6Cfg.VLEN-1:0] vpc_i;
    // Update bht with resolved address - EXECUTE
    bht_update_t bht_update_i;
    // Prediction from bht - FRONTEND
    logic [CVA6Cfg.INSTR_PER_FETCH-1:0] select_prediction_o;

    clocking cb_drv @(posedge clk_i);
        default input #(CLOCK_PERIOD/2) output #0;
        input select_prediction_o;
        inout vpc_i;
        inout bht_update_i;
    endclocking : cb_drv

endinterface : bht_if