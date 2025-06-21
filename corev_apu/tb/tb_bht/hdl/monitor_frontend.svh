/*
 * Copyright (c) 2025. All rights reserved.
 * Created by enrique, 17/05/25
 */

class MonitorFrontend #(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty,
    parameter type bht_update_t = logic,
    parameter type bht_prediction_t = logic,
    parameter type bp_metadata_t = logic
);
    virtual bht_frontend_if #(
        .CVA6Cfg(CVA6Cfg),
        .bht_update_t(bht_update_t),
        .bht_prediction_t(bht_prediction_t)
    ) vif;
    mailbox scb_mbx;

    function new (
        virtual bht_frontend_if #(
            .CVA6Cfg(CVA6Cfg),
            .bht_update_t(bht_update_t),
            .bht_prediction_t(bht_prediction_t)
        ) vif,
        mailbox scb_mbx
    );
        this.vif = vif;
        this.scb_mbx = scb_mbx;
    endfunction

    task run;
        $display ("T=%0t [Monitor] starting ...", $time);
        @(vif.cb_drv);
        forever begin
            TransactionFrontend #(
                .CVA6Cfg(CVA6Cfg),
                .bht_update_t(bht_update_t),
                .bht_prediction_t(bht_prediction_t),
                .bp_metadata_t(bp_metadata_t)
            ) trans = new;

            @(vif.cb_drv);
            trans.vpc_i = vif.cb_drv.vpc_i;
            trans.bht_update_i = vif.cb_drv.bht_update_i;
            trans.bht_prediction_o = vif.cb_drv.bht_prediction_o;

            scb_mbx.put(trans);
            trans.display("Monitor");
        end
    endtask : run
endclass : MonitorFrontend