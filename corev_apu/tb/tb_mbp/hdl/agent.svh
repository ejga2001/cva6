/*
 * Copyright (c) 2025. All rights reserved.
 * Created by enrique, 17/05/25
 */

class Agent #(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty,
    parameter type bht_update_t = logic,
    parameter type bht_prediction_t = logic,
    parameter type bp_metadata_t = logic
);
    Generator #(
        .CVA6Cfg(CVA6Cfg),
        .bht_update_t(bht_update_t),
        .bht_prediction_t(bht_prediction_t),
        .bp_metadata_t(bp_metadata_t)
    ) generator;
    Driver #(
        .CVA6Cfg(CVA6Cfg),
        .bht_update_t(bht_update_t),
        .bht_prediction_t(bht_prediction_t),
        .bp_metadata_t(bp_metadata_t)
    ) driver;
    Monitor #(
        .CVA6Cfg(CVA6Cfg),
        .bht_update_t(bht_update_t),
        .bht_prediction_t(bht_prediction_t),
        .bp_metadata_t(bp_metadata_t)
    ) monitor;

    event drv_done;

    virtual bht_if #(
        .CVA6Cfg(CVA6Cfg),
        .bht_update_t(bht_update_t),
        .bht_prediction_t(bht_prediction_t)
    ) vif;

    function automatic new(
        int ncycles,
        virtual bht_if #(
            .CVA6Cfg(CVA6Cfg),
            .bht_update_t(bht_update_t),
            .bht_prediction_t(bht_prediction_t)
        ) vif,
        mailbox scb_mbx
    );
        mailbox drv_mbx = new;
        this.vif = vif;
        generator = new(ncycles, drv_mbx, drv_done);
        driver = new(vif, drv_mbx, drv_done);
        monitor = new(vif, scb_mbx);
    endfunction : new

    task run;
        fork
            generator.run();
            driver.run();
            monitor.run();
        join_any
    endtask : run
endclass : Agent