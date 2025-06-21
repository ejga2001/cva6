/*
 * Copyright (c) 2025. All rights reserved.
 * Created by enrique, 17/05/25
 */

class AgentFrontend #(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty,
    parameter type bht_update_t = logic,
    parameter type bht_prediction_t = logic,
    parameter type bp_metadata_t = logic,
    parameter NR_ENTRIES = 1024
);
    GeneratorFrontend #(
        .CVA6Cfg(CVA6Cfg),
        .bht_update_t(bht_update_t),
        .bht_prediction_t(bht_prediction_t),
        .bp_metadata_t(bp_metadata_t)
    ) generator;
    DriverFrontend #(
        .CVA6Cfg(CVA6Cfg),
        .bht_update_t(bht_update_t),
        .bht_prediction_t(bht_prediction_t)
    ) driver;
    MonitorFrontend #(
        .CVA6Cfg(CVA6Cfg),
        .bht_update_t(bht_update_t),
        .bht_prediction_t(bht_prediction_t)
    ) monitor;
    ScoreboardFrontend #(
        .CVA6Cfg(CVA6Cfg),
        .bht_update_t(bht_update_t),
        .bht_prediction_t(bht_prediction_t),
        .bp_metadata_t(bp_metadata_t),
        .NR_ENTRIES(NR_ENTRIES)
    ) scoreboard;

    mailbox drv_mbx, scb_mbx;
    event drv_done;

    virtual bht_frontend_if #(
        .CVA6Cfg(CVA6Cfg),
        .bht_update_t(bht_update_t),
        .bht_prediction_t(bht_prediction_t)
    ) vif;

    function automatic new(
        int ncycles,
        virtual bht_frontend_if #(
            .CVA6Cfg(CVA6Cfg),
            .bht_update_t(bht_update_t),
            .bht_prediction_t(bht_prediction_t)
        ) vif
    );
        this.vif = vif;
        drv_mbx = new;
        scb_mbx = new;
        generator = new(ncycles, drv_mbx, drv_done);
        driver = new(vif, drv_mbx, drv_done);
        monitor = new(vif, scb_mbx);
        scoreboard = new(scb_mbx);
    endfunction : new

    task run;
        fork
            generator.run();
            driver.run();
            monitor.run();
            scoreboard.run();
        join_any
    endtask : run
endclass : AgentFrontend