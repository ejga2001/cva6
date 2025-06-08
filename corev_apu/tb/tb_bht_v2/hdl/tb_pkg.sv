/*
 * Copyright (c) 2025. All rights reserved.
 * Created by enrique, 22/03/25
 */

package tb_pkg;
    typedef enum bit {
        JUMP, CONDITIONAL
    } branch_type;
    `include "abstract_instruction.svh"
    `include "exit_instruction.svh"
    `include "instruction.svh"
    `include "normal_instruction.svh"
    `include "branch_instruction.svh"
    `include "cond_branch_instruction.svh"
    `include "loop_branch_instruction.svh"
    `include "instr_stream.svh"
    `include "instr_stream_gen.svh"
    `include "bht_shadow.svh"
endpackage