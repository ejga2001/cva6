/*
 * Copyright (c) 2025. All rights reserved.
 * Created by enrique, 17/05/25
 */

class Driver #(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty,
    parameter type bht_update_t = logic,
    parameter type bht_prediction_t = logic,
    parameter type bp_metadata_t = logic
);
    virtual bht_if #(
        .CVA6Cfg(CVA6Cfg),
        .bht_update_t(bht_update_t),
        .bht_prediction_t(bht_prediction_t)
    ) vif;
    local mailbox drv_mbx;
    event drv_done;

    function automatic new(
        virtual bht_if #(
            .CVA6Cfg(CVA6Cfg),
            .bht_update_t(bht_update_t),
            .bht_prediction_t(bht_prediction_t)
        ) vif,
        mailbox drv_mbx,
        ref event drv_done
    );
        this.vif = vif;
        this.drv_mbx = drv_mbx;
        this.drv_done = drv_done;
    endfunction : new

    task run;
        $display ("T=%0t [Driver] starting ...", $time);
        @(vif.cb_drv);
        forever begin
            Transaction #(
                .CVA6Cfg(CVA6Cfg),
                .bht_update_t(bht_update_t),
                .bht_prediction_t(bht_prediction_t),
                .bp_metadata_t(bp_metadata_t)
            ) trans;

            $display("T=%0t [Driver] waiting for item ...", $time);
            drv_mbx.get(trans);
            vif.cb_drv.vpc_i <= trans.vpc_i;
            vif.cb_drv.bht_update_i <= trans.bht_update_i;
            @(vif.cb_drv);

            trans.select_prediction_o = vif.cb_drv.select_prediction_o;

            trans.display("Driver");

            -> drv_done;
        end
    endtask : run
endclass : Driver

