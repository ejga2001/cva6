/*
* Copyright (c) 2025. All rights reserved.
* Created by enrique, 2025-03-24
*/

virtual class AbstractInstruction #(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty
);
    protected logic [CVA6Cfg.VLEN-1:0] vpc;
    protected bit rvc;

    pure virtual function automatic bit is_branch();

    pure virtual function automatic bit is_conditional();

    pure virtual function automatic bit is_terminal();

    pure virtual function automatic AbstractInstruction #(
        .CVA6Cfg(CVA6Cfg)
    ) getNextInstr();

    pure virtual function automatic void setNextInstr(
        AbstractInstruction #(
            .CVA6Cfg(CVA6Cfg)
        ) instruction_i
    );

    pure virtual function automatic AbstractInstruction #(
        .CVA6Cfg(CVA6Cfg)
    ) get_target_instr();

    function automatic logic [CVA6Cfg.VLEN-1:0] get_vpc ();
        return vpc;
    endfunction : get_vpc

    function automatic bit is_rvc ();
        return rvc;
    endfunction : is_rvc

    function automatic void set_rvc (bit rvc);
        this.rvc = rvc;
    endfunction : set_rvc

    virtual function automatic void print(string tab = "");
        $display({tab, "----------------------"});
        $display({tab, "Compressed = %x"}, rvc);
        $display({tab, "Virtual PC = %x"}, vpc);
    endfunction : print
endclass : AbstractInstruction