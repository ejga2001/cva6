/*
* Copyright (c) 2025. All rights reserved.
* Created by enrique, 2025-03-23
*/

class NormalInstruction #(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty
) extends Instruction #(
    CVA6Cfg
);
    function automatic new (
        logic [CVA6Cfg.VLEN-1:0] vpc_i
    );
        this.vpc = vpc_i;
    endfunction : new

    function automatic bit is_branch();
        return 0;
    endfunction : is_branch

    function automatic bit is_conditional();
        return 0;
    endfunction : is_conditional

    function automatic bit is_terminal();
        return 0;
    endfunction : is_terminal

    function automatic AbstractInstruction #(
        .CVA6Cfg(CVA6Cfg)
    ) get_target_instr();
        return null;
    endfunction : get_target_instr

    function automatic void print(string tab = "");
        super.print(tab);
    endfunction : print
endclass : NormalInstruction