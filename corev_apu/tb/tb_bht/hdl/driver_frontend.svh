/*
 * Copyright (c) 2025. All rights reserved.
 * Created by enrique, 17/05/25
 */

class DriverFrontend #(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty
);
    virtual bht_frontend_if #(
        .CVA6Cfg(CVA6Cfg)
    ) vif;
    local mailbox drv_mbx;
    event drv_done;

    function automatic new(
        virtual bht_frontend_if #(
            .CVA6Cfg(CVA6Cfg)
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
            TransactionFrontend #(
                .CVA6Cfg(CVA6Cfg)
            ) trans;

            $display ("T=%0t [Driver] waiting for item ...", $time);
            drv_mbx.get(trans);
            vif.cb_drv.vpc_i <= trans.instr.get_vpc();
            @(vif.cb_drv);

            trans.bht_prediction_o <= vif.cb_drv.bht_prediction_o;
            @(vif.cb_drv);

            trans.display("Driver");

            -> drv_done;
        end
    endtask : run
endclass : DriverFrontend

