/*
 * Copyright (c) 2025. All rights reserved.
 * Created by enrique, 19/03/25
 */

`timescale 1ns/1ns
module tb;
    import tb_pkg::*;

    // LOCAL PARAMETERS

    localparam config_pkg::cva6_cfg_t CVA6Cfg = build_config_pkg::build_config(cva6_config_pkg::cva6_cfg);

    localparam type bp_metadata_t = struct packed {
        logic [CVA6Cfg.LocalPredictorIndexBits-1:0] index;
    };

    localparam type bht_update_t = struct packed {
        logic                    valid;
        logic [CVA6Cfg.VLEN-1:0] pc;     // update at PC
        logic                    taken;
        bp_metadata_t            metadata;
    };

    localparam type bht_prediction_t = struct packed {
        logic                    valid;
        logic                    taken;
        bp_metadata_t            metadata;
    };

    localparam int unsigned LBP_ENTRIES = CVA6Cfg.LocalPredictorSize;

    localparam int unsigned LHR_ENTRIES = CVA6Cfg.LocalHistoryTableSize;

    // re-shape the branch history table
    localparam NR_ROWS_LBP = LBP_ENTRIES / CVA6Cfg.INSTR_PER_FETCH;
    // re-shape the LHR table
    localparam NR_ROWS_LHR = LHR_ENTRIES / CVA6Cfg.INSTR_PER_FETCH;

    localparam CLOCK_PERIOD = 20ns;

    localparam NCYCLES = 10000;

    function automatic void preload_array(
        tb_pkg::LBPShadow #(
            .CVA6Cfg(CVA6Cfg),
            .bht_update_t(bht_update_t),
            .bht_prediction_t(bht_prediction_t),
            .bp_metadata_t(bp_metadata_t),
            .LBP_ENTRIES(LBP_ENTRIES),
            .LHR_ENTRIES(LHR_ENTRIES)
        ) lbp_shadow
    );
        for (int i = 0; i < NR_ROWS_LBP; i++) begin
            int lbp_nrand0 = $random();
            int lbp_nrand1 = $random();
            dut.gen_bht_ram[0].i_bht_ram.mem[i] = lbp_nrand0;
            lbp_shadow.set_lbp_data(i, 0, lbp_nrand0);
            dut.gen_bht_ram[1].i_bht_ram.mem[i] = lbp_nrand1;
            lbp_shadow.set_lbp_data(i, 1, lbp_nrand1);
        end
        for (int i = 0; i < NR_ROWS_LHR; i++) begin
            int lhr_nrand0 = $random();
            int lhr_nrand1 = $random();
            dut.gen_bht_ram[0].i_lhr_ram.mem[i] = lhr_nrand0;
            lbp_shadow.set_lhr_data(i, 0, lhr_nrand0);
            dut.gen_bht_ram[1].i_lhr_ram.mem[i] = lhr_nrand1;
            lbp_shadow.set_lhr_data(i, 1, lhr_nrand1);
        end
    endfunction : preload_array

    // INPUTS
    logic clk_i;
    logic rst_ni;
    logic flush_bp_i;
    logic debug_mode_i;

    bht_if #(
        .CVA6Cfg(CVA6Cfg),
        .bht_update_t(bht_update_t),
        .bht_prediction_t(bht_prediction_t)
    ) intf (
        clk_i,
        rst_ni
    );

    Test #(
        .CVA6Cfg(CVA6Cfg),
        .bht_update_t(bht_update_t),
        .bht_prediction_t(bht_prediction_t),
        .bp_metadata_t(bp_metadata_t),
        .LBP_ENTRIES(LBP_ENTRIES),
        .LHR_ENTRIES(LHR_ENTRIES)
    ) t = new(NCYCLES, intf);

    // DUT INSTANTIATION
    lbp #(
        .CVA6Cfg(CVA6Cfg),
        .bht_update_t(bht_update_t),
        .bht_prediction_t(bht_prediction_t),
        .bp_metadata_t(bp_metadata_t),
        .LBP_ENTRIES(LBP_ENTRIES),
        .LHR_ENTRIES(LHR_ENTRIES)
    ) dut (
        .clk_i,
        .rst_ni,
        .debug_mode_i,
        .flush_bp_i,
        .vpc_i(intf.vpc_i),
        .bht_update_i(intf.bht_update_i),
        .bht_prediction_o(intf.bht_prediction_o)
    );

    // Clock process
    always #(CLOCK_PERIOD/2) clk_i = ~clk_i;

    initial begin
        debug_mode_i = 0;
        flush_bp_i = 0;

        clk_i = 1'b0;
        rst_ni = 1'b0;

        preload_array(t.env.scoreboard.lbp_shadow);

        #(CLOCK_PERIOD) rst_ni = 1'b1;

        t.run();
        #(CLOCK_PERIOD) $display("ALL TESTS PASSED");

        $finish();
    end

    initial begin
        $dumpfile("ondas.vcd");
        $dumpvars(0, tb);
    end

endmodule