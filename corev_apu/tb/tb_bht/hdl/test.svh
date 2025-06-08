/*
 * Copyright (c) 2025. All rights reserved.
 * Created by enrique, 17/05/25
 */

class Test #(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty
);
    Environment #(
        .CVA6Cfg(CVA6Cfg)
    ) env;

    virtual bht_frontend_if #(
        .CVA6Cfg(CVA6Cfg)
    ) vif;

    function automatic new (
        int ncycles,
        virtual bht_frontend_if #(
            .CVA6Cfg(CVA6Cfg)
        ) vif
    );
        env = new(ncycles, vif);
        this.vif = vif;
    endfunction : new

    task run;
        fork
            env.run();
        join_any
    endtask : run

endclass : Test