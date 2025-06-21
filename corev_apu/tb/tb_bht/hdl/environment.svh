/*
 * Copyright (c) 2025. All rights reserved.
 * Created by enrique, 17/05/25
 */

class Environment #(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty,
    parameter type bht_update_t = logic,
    parameter type bht_prediction_t = logic,
    parameter type bp_metadata_t = logic,
    parameter NR_ENTRIES = 1024
);
    AgentFrontend #(
        .CVA6Cfg(CVA6Cfg),
        .bht_update_t(bht_update_t),
        .bht_prediction_t(bht_prediction_t),
        .bp_metadata_t(bp_metadata_t),
        .NR_ENTRIES(NR_ENTRIES)
    ) agent_frontend;

    virtual bht_frontend_if #(
        .CVA6Cfg(CVA6Cfg),
        .bht_update_t(bht_update_t),
        .bht_prediction_t(bht_prediction_t)
    ) vif;

    function automatic new (
        int ncycles,
        virtual bht_frontend_if #(
            .CVA6Cfg(CVA6Cfg),
            .bht_update_t(bht_update_t),
            .bht_prediction_t(bht_prediction_t)
        ) vif
    );
        this.vif = vif;
        agent_frontend = new(ncycles, vif);
    endfunction : new

    task run;
        fork
            agent_frontend.run();
        join_any
    endtask : run
endclass : Environment