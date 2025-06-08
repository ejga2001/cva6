/*
 * Copyright (c) 2025. All rights reserved.
 * Created by enrique, 17/05/25
 */

class MonitorFrontend #(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty
);
    virtual bht_frontend_if #(
        .CVA6Cfg(CVA6Cfg)
    ) vif;
    mailbox scb_mbx;

    function new (
        mailbox scb_mbx,
        bht_frontend_if vif
    );
        this.vif = vif;
        this.scb_mbx = scb_mbx;
    endfunction

    task run;
        $display ("T=%0t [Monitor] starting ...", $time);
        forever begin
            TransactionFrontend #(
                .CVA6Cfg(CVA6Cfg)
            ) trans = new;

            @(vif.cb_drv);
            trans.vpc_i = vif.vpc_i;
            $display("T=%0t [Monitor] First part over", $time);

            @(vif.cb_drv);
            trans.bht_prediction_o = vif.bht_prediction_o;
            $display("T=%0t [Monitor] Second part over", $time);

            scb_mbx.put(trans);
            trans.print("Monitor");
        end
    endtask : run
endclass : MonitorFrontend