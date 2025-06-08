/*
 * Copyright (c) 2025. All rights reserved.
 * Created by enrique, 17/05/25
 */

class Environment #(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty
);
    AgentFrontend #(
        .CVA6Cfg(CVA6Cfg)
    ) agent_frontend;

    virtual bht_frontend_if #(
        .CVA6Cfg(CVA6Cfg)
    ) vif;

    function automatic new (
        int ncycles,
        virtual bht_frontend_if #(
            .CVA6Cfg(CVA6Cfg)
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