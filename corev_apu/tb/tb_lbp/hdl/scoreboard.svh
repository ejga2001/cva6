/*
 * Copyright (c) 2025. All rights reserved.
 * Created by enrique, 20/06/25
 */

class Scoreboard #(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty,
    parameter type bht_update_t = logic,
    parameter type bht_prediction_t = logic,
    parameter type bp_metadata_t = logic,
    parameter int unsigned LBP_ENTRIES = 512,
    parameter int unsigned LHR_ENTRIES = 512
);
    mailbox scb_mbx;
    tb_pkg::LBPShadow #(
        .CVA6Cfg(CVA6Cfg),
        .bht_update_t(bht_update_t),
        .bht_prediction_t(bht_prediction_t),
        .bp_metadata_t(bp_metadata_t),
        .LBP_ENTRIES(LBP_ENTRIES),
        .LHR_ENTRIES(LHR_ENTRIES)
    ) lbp_shadow;

    function automatic new (
        mailbox scb_mbx
    );
        this.scb_mbx = scb_mbx;
        this.lbp_shadow = new;
    endfunction : new

    task run;
        forever begin
            Transaction #(
                .CVA6Cfg(CVA6Cfg),
                .bht_update_t(bht_update_t),
                .bht_prediction_t(bht_prediction_t),
                .bp_metadata_t(bp_metadata_t)
            ) trans;

            scb_mbx.get(trans);
            trans.display("Scoreboard");

            for (int i = 0; i < CVA6Cfg.INSTR_PER_FETCH; i++) begin
                bht_prediction_t expected_output = lbp_shadow.output_bht(trans.vpc_i, i);
                assert (trans.bht_prediction_o[i] === expected_output)
                    else begin
                        $error("They are NOT identical: expected 0x%x got 0x%x",
                            expected_output,
                            trans.bht_prediction_o[i]);
                        $finish(1);
                    end
            end
            lbp_shadow.update_bht(trans.bht_update_i);
        end
    endtask : run
endclass : Scoreboard