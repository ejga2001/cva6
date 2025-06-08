/*
 * Copyright (c) 2025. All rights reserved.
 * Created by enrique, 19/03/25
 */

`timescale 1ns/1ns
module tb;
    import tb_pkg::*;

    // LOCAL PARAMETERS

    localparam config_pkg::cva6_cfg_t CVA6Cfg = build_config_pkg::build_config(cva6_config_pkg::cva6_cfg);

    localparam type bht_update_t = struct packed {
        logic                    valid;
        logic [CVA6Cfg.VLEN-1:0] pc;     // update at PC
        logic                    taken;
    };

    localparam int unsigned NR_ENTRIES = 1024;

    localparam CLOCK_PERIOD = 20ns;

    localparam NCYCLES = 10;

    // INPUTS
    logic clk_i;
    logic rst_ni;
    logic flush_bp_i;
    logic debug_mode_i;
    bht_update_t bht_update_i;

    bht_frontend_if #(
        .CVA6Cfg(CVA6Cfg)
    ) intf (
        clk_i,
        rst_ni
    );
    mailbox drv_mbx = new;
    event drv_done;

    Test #(
        .CVA6Cfg(CVA6Cfg)
    ) t = new(NCYCLES, intf);

    tb_pkg::BHTShadow #(
        .CVA6Cfg(CVA6Cfg),
        .bht_update_t(bht_update_t),
        .NR_ENTRIES(NR_ENTRIES)
    ) bht_shadow = new;

    // DUT INSTANTIATION
    bht #(
        .CVA6Cfg(CVA6Cfg),
        .bht_update_t(bht_update_t),
        .NR_ENTRIES(NR_ENTRIES)
    ) dut (
        .clk_i,
        .rst_ni,
        .debug_mode_i,
        .flush_bp_i,
        .vpc_i(intf.vpc_i),
        .bht_update_i(bht_update_i),
        .bht_prediction_o(intf.bht_prediction_o)
    );

    // Clock process
    always #(CLOCK_PERIOD/2) clk_i = ~clk_i;

    initial begin
        clk_i = 0;
        rst_ni = 1'b0;

        #(CLOCK_PERIOD) rst_ni = 1'b1;

        t.run();

        // $display("INTERNAL = %b", dut.gen_fpga_bht.gen_bht_ram[0].gen_async_bht_ram.i_bht_ram.mem[0]);
        $finish();
    end

    initial begin
        $dumpfile("ondas.vcd");
        $dumpvars(0, tb);
    end

endmodule