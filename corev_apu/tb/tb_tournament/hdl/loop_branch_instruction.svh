/*
* Copyright (c) 2025. All rights reserved.
* Created by enrique, 2025-03-24
*/

class LoopBranchInstruction #(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty
) extends BranchInstruction #(
    CVA6Cfg
);
    Instruction #(
        .CVA6Cfg(CVA6Cfg)
    ) target_instr;

    function new(
        logic[CVA6Cfg.VLEN-1:0] vpc_i
    );
        super.new(vpc_i);
    endfunction : new

    function automatic bit is_conditional();
        return 0;
    endfunction : is_conditional

    function automatic bit is_terminal();
        return 0;
    endfunction : is_terminal

    function automatic AbstractInstruction #(
        .CVA6Cfg(CVA6Cfg)
    ) get_target_instr();
        return target_instr;
    endfunction : get_target_instr

    function automatic void set_target_instr(
        Instruction #(
            .CVA6Cfg(CVA6Cfg)
        ) target_instr_i
    );
        this.target_instr = target_instr_i;
    endfunction : set_target_instr
endclass : LoopBranchInstruction