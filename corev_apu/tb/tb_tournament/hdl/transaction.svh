/*
 * Copyright (c) 2025. All rights reserved.
 * Created by enrique, 16/05/25
 */

class Transaction #(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty,
    parameter type bht_update_t = logic,
    parameter type bht_prediction_t = logic,
    parameter type bp_metadata_t = logic
);
    // INPUTS
    logic [CVA6Cfg.VLEN-1:0] vpc_i;
    bht_update_t bht_update_i;

    // OUTPUTS
    bht_prediction_t [CVA6Cfg.INSTR_PER_FETCH-1:0] bht_prediction_o;

    function automatic new ();

    endfunction : new

    function automatic void display (string name);
        $display("T=%0t %s", $time, name);
        $display("\tInputs:");
        $display("\t\tvpc_i = 0x%0h", vpc_i);
        $display("\t\tbht_update_i.valid = %x", bht_update_i.valid);
        $display("\t\tbht_update_i.pc = 0x%0h", bht_update_i.pc);
        $display("\t\tbht_update_i.taken = %x", bht_update_i.taken);
        $display("\t\tbht_update_i.metadata.gindex = 0x%0h", bht_update_i.metadata.gindex);
        $display("\t\tbht_update_i.metadata.gbp_valid = 0x%0h", bht_update_i.metadata.gbp_valid);
        $display("\t\tbht_update_i.metadata.gbp_taken = 0x%0h", bht_update_i.metadata.gbp_taken);
        $display("\t\tbht_update_i.metadata.lindex = 0x%0h", bht_update_i.metadata.lindex);
        $display("\t\tbht_update_i.metadata.lbp_valid = 0x%0h", bht_update_i.metadata.lbp_valid);
        $display("\t\tbht_update_i.metadata.lbp_taken = 0x%0h", bht_update_i.metadata.lbp_taken);
        $display("\tOutputs:");
        for (int i = 0; i < CVA6Cfg.INSTR_PER_FETCH; i++) begin
            $display("\t\tbht_prediction_o[%0d].valid = %x", i, bht_prediction_o[i].valid);
            $display("\t\tbht_prediction_o[%0d].taken = %x", i, bht_prediction_o[i].taken);
            $display("\t\tbht_prediction_o[%0d].metadata.gindex = 0x%0h", i, bht_prediction_o[i].metadata.gindex);
            $display("\t\tbht_prediction_o[%0d].metadata.gbp_valid = 0x%0h", i, bht_prediction_o[i].metadata.gbp_valid);
            $display("\t\tbht_prediction_o[%0d].metadata.gbp_taken = 0x%0h", i, bht_prediction_o[i].metadata.gbp_taken);
            $display("\t\tbht_prediction_o[%0d].metadata.lindex = 0x%0h", i, bht_prediction_o[i].metadata.lindex);
            $display("\t\tbht_prediction_o[%0d].metadata.lbp_valid = 0x%0h", i, bht_prediction_o[i].metadata.lbp_valid);
            $display("\t\tbht_prediction_o[%0d].metadata.lbp_taken = 0x%0h", i, bht_prediction_o[i].metadata.lbp_taken);
        end
    endfunction : display
endclass : Transaction