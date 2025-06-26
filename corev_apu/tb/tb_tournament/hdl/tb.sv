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
        logic [CVA6Cfg.GlobalPredictorIndexBits-1:0] gindex;
        logic                                        gbp_valid;
        logic                                        gbp_taken;
        logic [CVA6Cfg.LocalPredictorIndexBits-1:0]  lindex;
        logic                                        lbp_valid;
        logic                                        lbp_taken;
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

    localparam int unsigned MIN_N_STREAMS = 6;
    localparam int unsigned MAX_N_STREAMS = 12;
    localparam int unsigned MIN_STREAM_LEN = 7;
    localparam int unsigned MAX_STREAM_LEN = 12;
    localparam int unsigned P_COMPRESSED_INSTR = 50;
    localparam int unsigned P_NOT_A_BRANCH = 75;
    localparam int unsigned P_FORWARD_BRANCH = 50;
    localparam int unsigned P_FORWARD_TAKEN = 50;
    localparam int unsigned P_BACKWARD_TAKEN = 90;

    localparam int unsigned MBP_ENTRIES = CVA6Cfg.ChoicePredictorSize;

    localparam int unsigned GBP_ENTRIES = CVA6Cfg.GlobalPredictorSize;

    localparam int unsigned LBP_ENTRIES = CVA6Cfg.LocalPredictorSize;

    localparam int unsigned LHR_ENTRIES = CVA6Cfg.LocalHistoryTableSize;

    localparam int unsigned NR_ROWS_MBP = MBP_ENTRIES / CVA6Cfg.INSTR_PER_FETCH;

    localparam int unsigned NR_ROWS_GBP = GBP_ENTRIES / CVA6Cfg.INSTR_PER_FETCH;

    localparam int unsigned NR_ROWS_LBP = LBP_ENTRIES / CVA6Cfg.INSTR_PER_FETCH;

    localparam int unsigned NR_ROWS_LHR = LHR_ENTRIES / CVA6Cfg.INSTR_PER_FETCH;

    localparam CLOCK_PERIOD = 20ns;

    localparam NCYCLES = 10000;

    function automatic void preload_array(
        tb_pkg::TournamentShadow #(
            .CVA6Cfg   (CVA6Cfg),
            .bht_update_t(bht_update_t),
            .bht_prediction_t(bht_prediction_t),
            .bp_metadata_t(bp_metadata_t),
            .MBP_ENTRIES(MBP_ENTRIES),
            .GBP_ENTRIES(GBP_ENTRIES),
            .LBP_ENTRIES(LBP_ENTRIES),
            .LHR_ENTRIES(LHR_ENTRIES)
        ) tournament_shadow
    );
        for (int i = 0; i < NR_ROWS_MBP; i++) begin
            int nrand0 = $random();
            int nrand1 = $random();
            dut.i_mbp.gen_bht_ram[0].i_bht_ram.mem[i] = nrand0;
            tournament_shadow.set_mbp_data(i, 0, nrand0);
            dut.i_mbp.gen_bht_ram[1].i_bht_ram.mem[i] = nrand1;
            tournament_shadow.set_mbp_data(i, 1, nrand1);
        end
        for (int i = 0; i < NR_ROWS_GBP; i++) begin
            int nrand0 = $random();
            int nrand1 = $random();
            dut.i_gbp.gen_bht_ram[0].i_bht_ram.mem[i] = nrand0;
            tournament_shadow.set_gbp_data(i, 0, nrand0);
            dut.i_gbp.gen_bht_ram[1].i_bht_ram.mem[i] = nrand1;
            tournament_shadow.set_gbp_data(i, 1, nrand1);
        end
        for (int i = 0; i < NR_ROWS_LBP; i++) begin
            int nrand0 = $random();
            int nrand1 = $random();
            dut.i_lbp.gen_bht_ram[0].i_bht_ram.mem[i] = nrand0;
            tournament_shadow.set_lbp_data(i, 0, nrand0);
            dut.i_lbp.gen_bht_ram[1].i_bht_ram.mem[i] = nrand1;
            tournament_shadow.set_lbp_data(i, 1, nrand1);
        end
        for (int i = 0; i < NR_ROWS_LHR; i++) begin
            int nrand0 = $random();
            int nrand1 = $random();
            dut.i_lbp.gen_bht_ram[0].i_lhr_ram.mem[i] = nrand0;
            tournament_shadow.set_lhr_data(i, 0, nrand0);
            dut.i_lbp.gen_bht_ram[1].i_lhr_ram.mem[i] = nrand1;
            tournament_shadow.set_lhr_data(i, 1, nrand1);
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
        .MIN_N_STREAMS(MIN_N_STREAMS),
        .MAX_N_STREAMS(MAX_N_STREAMS),
        .MIN_STREAM_LEN(MIN_STREAM_LEN),
        .MAX_STREAM_LEN(MAX_STREAM_LEN),
        .P_COMPRESSED_INSTR(P_COMPRESSED_INSTR),
        .P_NOT_A_BRANCH(P_NOT_A_BRANCH),
        .P_FORWARD_BRANCH(P_FORWARD_BRANCH),
        .P_FORWARD_TAKEN(P_FORWARD_TAKEN),
        .P_BACKWARD_TAKEN(P_BACKWARD_TAKEN),
        .MBP_ENTRIES(MBP_ENTRIES),
        .GBP_ENTRIES(GBP_ENTRIES),
        .LBP_ENTRIES(LBP_ENTRIES),
        .LHR_ENTRIES(LHR_ENTRIES)
    ) t = new(NCYCLES, intf);

    // DUT INSTANTIATION
    tournament #(
        .CVA6Cfg   (CVA6Cfg),
        .bht_update_t(bht_update_t),
        .bht_prediction_t(bht_prediction_t),
        .bp_metadata_t(bp_metadata_t),
        .MBP_ENTRIES(MBP_ENTRIES),
        .GBP_ENTRIES(GBP_ENTRIES),
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

        preload_array(t.env.scoreboard.tournament_shadow);

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