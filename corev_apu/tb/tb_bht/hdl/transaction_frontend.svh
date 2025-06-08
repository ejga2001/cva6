/*
 * Copyright (c) 2025. All rights reserved.
 * Created by enrique, 16/05/25
 */

class TransactionFrontend #(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty
) extends Transaction;
    AbstractInstruction #(
        .CVA6Cfg(CVA6Cfg)
    ) instr;
    bit taken;
    ariane_pkg::bht_prediction_t [CVA6Cfg.INSTR_PER_FETCH-1:0] bht_prediction_o;

    function automatic new ();
        taken = 0;
    endfunction : new

    function automatic void display (string name);
        super.display(name);
        $display ("T=%0t %s vpc_i=0x%0h taken=%x bht_prediction_o=%x", $time, name, instr.get_vpc(), taken, bht_prediction_o);
    endfunction : display
endclass : TransactionFrontend