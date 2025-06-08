/*
* Copyright (c) 2025. All rights reserved.
* Created by enrique, 2025-03-23
*/

virtual class BranchInstruction #(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty
) extends Instruction #(
    CVA6Cfg
);
    protected logic [CVA6Cfg.VLEN-1:0] target_address;

    function automatic new (
        logic [CVA6Cfg.VLEN-1:0] vpc_i
    );
        this.vpc = vpc_i;
    endfunction : new

    function automatic bit is_branch();
        return 1;
    endfunction : is_branch

    pure virtual function automatic bit is_conditional();

    pure virtual function automatic AbstractInstruction #(
        .CVA6Cfg(CVA6Cfg)
    ) get_target_instr();

    function automatic void set_target_address (
        logic [CVA6Cfg.VLEN-1:0] target_address_i
    );
        this.target_address = target_address_i;
    endfunction : set_target_address

    function automatic void print(string tab = "");
        super.print(tab);
        $display({tab, "target_address = %x"}, this.target_address);
        $display(tab, "is_conditional = %x", is_conditional());
    endfunction : print
endclass : BranchInstruction