/*
 * Copyright (c) 2025. All rights reserved.
 * Created by enrique, 18/05/25
 */

class TransactionBackend #(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty,
    parameter type bht_update_t = logic
) extends Transaction;
    bht_update_t bht_update_i;  // OUTPUT to DUT
    ariane_pkg::bht_prediction_t [CVA6Cfg.INSTR_PER_FETCH-1:0] bht_prediction_o;    // INPUT from DUT

    function automatic new;

    endfunction : new

    function automatic void display (string name);
        super.display(name);
        $display ("T=%0t %s bht_update_i=%x bht_prediction_o=%x", $time, name, bht_update_i, bht_prediction_o);
    endfunction : display
endclass : TransactionBackend