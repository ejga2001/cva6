/*
 * Copyright (c) 2025. All rights reserved.
 * Created by enrique, 17/05/25
 */

class Environment #(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty,
    parameter type bht_update_t = logic,
    parameter type bht_prediction_t = logic,
    parameter type bp_metadata_t = logic,
    parameter MIN_N_STREAMS = 6,
    parameter MAX_N_STREAMS = 12,
    parameter MIN_STREAM_LEN = 7,
    parameter MAX_STREAM_LEN = 12,
    parameter P_COMPRESSED_INSTR = 50,
    parameter P_NOT_A_BRANCH = 75,
    parameter P_FORWARD_BRANCH = 50,
    parameter P_FORWARD_TAKEN = 50,
    parameter P_BACKWARD_TAKEN = 90,
    parameter NR_ENTRIES = 1024
);
    Agent #(
        .CVA6Cfg(CVA6Cfg),
        .bht_update_t(bht_update_t),
        .bht_prediction_t(bht_prediction_t),
        .bp_metadata_t(bp_metadata_t),
        .MIN_N_STREAMS(MIN_N_STREAMS),
        .MAX_N_STREAMS(MAX_N_STREAMS),
        .MIN_STREAM_LEN(MIN_STREAM_LEN),
        .MAX_STREAM_LEN(MAX_STREAM_LEN),
        .P_COMPRESSED_INSTR(P_COMPRESSED_INSTR),
        .P_NOT_A_BRANCH(P_NOT_A_BRANCH),
        .P_FORWARD_BRANCH(P_FORWARD_BRANCH),
        .P_FORWARD_TAKEN(P_FORWARD_TAKEN),
        .P_BACKWARD_TAKEN(P_BACKWARD_TAKEN)
    ) agent;

    Scoreboard #(
        .CVA6Cfg(CVA6Cfg),
        .bht_update_t(bht_update_t),
        .bht_prediction_t(bht_prediction_t),
        .bp_metadata_t(bp_metadata_t),
        .NR_ENTRIES(NR_ENTRIES)
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