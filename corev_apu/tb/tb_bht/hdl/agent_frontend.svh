/*
 * Copyright (c) 2025. All rights reserved.
 * Created by enrique, 17/05/25
 */

class AgentFrontend #(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty
);
    GeneratorFrontend #(
        .CVA6Cfg(CVA6Cfg)
    ) generator;
    DriverFrontend #(
        .CVA6Cfg(CVA6Cfg)
    ) driver;

    mailbox drv_mbx;
    event drv_done;

    virtual bht_frontend_if #(
        .CVA6Cfg(CVA6Cfg)
    ) vif;

    function automatic new(
        int ncycles,
        virtual bht_frontend_if #(
            .CVA6Cfg(CVA6Cfg)
        ) vif
    );
        this.vif = vif;
        drv_mbx = new;
        generator = new(ncycles, drv_mbx, drv_done);
        driver = new(vif, drv_mbx, drv_done);
    endfunction : new

    task run;
        fork
            generator.run();
            driver.run();
        join_any
    endtask : run
endclass : AgentFrontend