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
        logic [CVA6Cfg.BHTIndexBits-1:0] index;
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

    localparam int unsigned NR_ENTRIES = CVA6Cfg.BHTEntries;

    localparam int unsigned NR_ROWS = NR_ENTRIES / CVA6Cfg.INSTR_PER_FETCH;

    localparam CLOCK_PERIOD = 20ns;

    localparam NCYCLES = 10000;

    function automatic void preload_array(
        tb_pkg::BHTShadow #(
            .CVA6Cfg(CVA6Cfg),
            .bht_update_t(bht_update_t),
            .bht_prediction_t(bht_prediction_t),
            .bp_metadata_t(bp_metadata_t),
            .NR_ENTRIES(NR_ENTRIES)
        ) bht_shadow
    );
        for (int i = 0; i < NR_ROWS; i++) begin
            int nrand0 = $random();
            int nrand1 = $random();
            dut.gen_bht_ram[0].i_bht_ram.mem[i] = nrand0;
            bht_shadow.set_data(i, 0, nrand0);
            dut.gen_bht_ram[1].i_bht_ram.mem[i] = nrand1;
            bht_shadow.set_data(i, 1, nrand1);
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
        .NR_ENTRIES(NR_ENTRIES)
    ) t = new(NCYCLES, intf);

    // DUT INSTANTIATION
    bht #(
        .CVA6Cfg(CVA6Cfg),
        .bht_update_t(bht_update_t),
        .bht_prediction_t(bht_prediction_t),
        .bp_metadata_t(bp_metadata_t),
        .NR_ENTRIES(NR_ENTRIES)
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

        preload_array(t.env.scoreboard.bht_shadow);

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