/*
 * Copyright (c) 2025. All rights reserved.
 * Created by enrique, 17/05/25
 */

class Environment #(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty,
    parameter type bht_update_t = logic,
    parameter type bht_prediction_t = logic,
    parameter type bp_metadata_t = logic,
    parameter int unsigned MBP_ENTRIES = 256,
    parameter int unsigned GBP_ENTRIES = 256,
    parameter int unsigned LBP_ENTRIES = 256,
    parameter int unsigned LHR_ENTRIES = 256
);
    Agent #(
        .CVA6Cfg(CVA6Cfg),
        .bht_update_t(bht_update_t),
        .bht_prediction_t(bht_prediction_t),
        .bp_metadata_t(bp_metadata_t)
    ) agent;

    Scoreboard #(
        .CVA6Cfg(CVA6Cfg),
        .bht_update_t(bht_update_t),
        .bht_prediction_t(bht_prediction_t),
        .bp_metadata_t(bp_metadata_t),
        .MBP_ENTRIES(MBP_ENTRIES),
        .GBP_ENTRIES(GBP_ENTRIES),
        .LBP_ENTRIES(LBP_ENTRIES),
        .LHR_ENTRIES(LHR_ENTRIES)
    ) scoreboard;

    virtual bht_if #(
        .CVA6Cfg(CVA6Cfg),
        .bht_update_t(bht_update_t),
        .bht_prediction_t(bht_prediction_t)
    ) vif;

    function automatic new (
        int ncycles,
        virtual bht_if #(
            .CVA6Cfg(CVA6Cfg),
            .bht_update_t(bht_update_t),
            .bht_prediction_t(bht_prediction_t)
        ) vif
    );
        mailbox scb_mbx = new;
        this.vif = vif;
        agent = new(ncycles, vif, scb_mbx);
        scoreboard = new(scb_mbx);
    endfunction : new

    task run;
        fork
            agent.run();
            scoreboard.run();
        join_any
    endtask : run
endclass : Environment