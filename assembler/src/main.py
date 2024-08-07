from .config import RTEMConfig

from typing import Any, TypeVar, Mapping, TypeVarTuple
from .sections import AssemblerState, Section, EditSection, ByteCode
from .states import *
from . import tokens
from .result import AssemblerResult
from .helpers import grouper, ParsingException, int_map_to_list
import copy


class RTEMAssembler:
    '''
    Assembler instance for the RTEM language. Holds internal state, and parses line by line.
    Todo:
    - Add simple support for sections. Use the section variable to control whether labels are interpreted
    as edit states or trans states. Translate EDI commands.

    General framework:
    The assembler reads line by line. The strategy used to parse the line is determined by the current state.
    Each state is responsible for sending back:
    - The next state
    - Any identifiers that were



    '''

    def __init__(self,
                 initial_state: str,
                 clocks: dict[str, int] | None = None,
                 constants: dict[str, int] | None = None,
                 inputs: dict[str, int] | None = None,
                 **kwargs):

        self.data = AssemblerState(
            constant_map={tokens.RTEMConstant(
                k): v for k, v in constants.items()} if constants else {},
            clock_map={tokens.RTEMClock(k): v for k,
                       v in clocks.items()} if clocks else {},
            input_map={tokens.RTEMVar(k): v for k, v in inputs.items()
                       } if inputs else {},
            state_map={tokens.RTEMState(initial_state): 0},
            **kwargs
        )
        self.curr_section: Section = EditSection(self.data)

    # def parse_file(self, filename: str):
    #     with open(filename, 'r') as f:
    #         for line in f:
    #             self.parse_line(line)
    #     return self.config

    def check_section(self, line: str) -> str | None:
        '''
        Checks if a line is a section. If it is, returns the section name.
        '''
        if line.startswith('.'):
            return line.split()[0].removeprefix('.')
        return None

    def parse_line(self, line: str):
        self.data.current_line += 1
        self.data.code.append(line)
        # Check if there is a new section, and update the section accordingly
        print(line)
        try:
            self.curr_section.parse_line(line)
            if sec := self.check_section(line):
                self.curr_section = Section.class_map[sec](self.data)
                return []

        except ParsingException as e:
            print('Error while parsing:')
            print(f'\tdata={self.data}')
            print(f'\tsection={e.state}')
            print(f'\tstate={e.state}')
            print(f'\tline={e.line}')
            print(f'\tmsg={e.msg}')
            exit()

    ####
    # Resolve functionality
    ####

    def resolve_string(self, line: tokens.UnresolvedCodeline, map: Mapping[Any, int]) -> tokens.CodeLine:
        '''
        Resolve string to bitstring
        '''
        if isinstance(line, str):
            return line
        return line.resolve(map)

    def resolve_clock_flags(self):
        clock_flags = 0
        for idx, v in enumerate(int_map_to_list(self.data.input_map)):
            if isinstance(v, tokens.RTEMClockConstraint):
                clock_flags |= 1 << idx
        return clock_flags

    def resolve_inputs(self):
        final_input_map = self.data.input_map.copy()
        used_inputs = set(self.data.input_map.values())
        i = 0
        for input_var in self.data.input_vars:
            if input_var not in final_input_map:
                while i in used_inputs:
                    i += 1
                final_input_map[input_var] = i
                used_inputs.add(i)
        return final_input_map

    def resolve_positions(self) -> tuple[int, int, int, int]:
        '''
        Returns: (trans_offset, trans_start, state_offset, prog_offset)

        '''
        # Get start positions of each section
        trans_offset = len(self.data.clock_constraints) + \
            (len(self.data.trans_map) + 1) // 2
        print(len(self.data.clock_constraints), len(self.data.trans_map))
        trans_start = len(self.data.clock_constraints)
        state_offset = trans_start + (len(self.data.trans_map) * 3 + 1)//2
        prog_offset = state_offset + len(self.data.state_map)*2
        return trans_offset, trans_start, state_offset, prog_offset

    def resolve_transition_defns(self) -> tokens.Code:
        '''
        Returns (trans_resets, trans_states)
        '''
        trans_resets: tokens.Code = []
        trans_states: tokens.Code = []

        # Resolve state table
        for trans in int_map_to_list(self.data.trans_map):
            if trans is not None:
                sta, rst = trans.resolve_defn(
                    {**self.data.clock_map, **self.data.state_map})
                trans_resets.append(rst)
                trans_states.append(sta)
            else:
                trans_resets.append('00000000')
                trans_states.append('0000')

        if len(trans_states) % 2 == 1:  
            trans_states.append('0000')  # pad with 0s

        # pack trans_states such that the 4-bytes words are swapped in each byte
        packed_trans_states = [word0 + word1 for word0,
                               word1 in grouper(reversed(trans_states), 2, incomplete='strict')]
        return packed_trans_states + trans_resets

    def resolve_state_section(self, context_map: Mapping[Any, int], trans_offset: int) -> tokens.Code:
        '''
        trans_offset: The offset of the transition section, to be subtracted from all addresses in this section,
            as they will be added back during runtime.
        exit_addr: The address of a section of bytes that does nothing and exits the program.
        '''
        code_lines: tokens.Code = []
        for state in int_map_to_list(self.data.state_map):
            if state is not None:
                # check that all states have a transition label
                edit_label = state.label('edit')
                trans_label = state.label('trans')
                if trans_label not in self.data.label_map or edit_label not in self.data.label_map:
                    raise ValueError(f'State {state} has no label')
                # We subtract off the trans offset as part of a hardware optimization, as in the datapath
                # trans_offset is added back. This is never a problem since we always have
                # trans_offset < state address
                code_lines.append(
                    f'{context_map[trans_label] - trans_offset:08b}')
                code_lines.append(
                    f'{context_map[edit_label] - trans_offset:08b}')
            else:
                code_lines.append('00000000')
                code_lines.append('00000000')
        return code_lines

    def resolve_code_section(self, lines: UnresolvedCode, context_map: Mapping[Any, int]):
        resolved: list[str] = []
        for line in lines:
            resolved_code = self.resolve_string(line, context_map)
            print(f'{line} -> {resolved_code}')
            resolved.append(resolved_code)
        return resolved

    def code_to_bytecode(self, lines):
        # Transform to bitstring into a bytestream, aligned on byte boundaries
        bytes_list: ByteCode = []
        current_byte = ''
        for line in lines:
            if len(line) + len(current_byte) > 8:
                bytes_list.append(int(current_byte, 2))
                current_byte = line
            else:
                current_byte = line + current_byte
        bytes_list.append(int(current_byte, 2))
        return bytes_list

    def resolve(self) -> AssemblerResult:

        clock_flags: int = self.resolve_clock_flags()

        final_input_map: dict[tokens.RTEMInput, int] = self.resolve_inputs()

        # Program length has been determined, so we know the location of each state
        trans_offset, trans_start, state_offset, prog_offset = self.resolve_positions()

        # At this point we can resolve all variables. This map is used to resolve all instructions.
        context_map = {
            **self.data.constant_map,  # "aviTicks", "aeiTicks", etc
            **self.data.trans_map,  # "state0, v=0"
            **final_input_map,  # "AP", "V1", "v<aeiTicks", etc
            **self.data.clock_map,  # "v"
            **self.data.state_map,  # "state0"
            **{k: v + prog_offset for k, v in self.data.label_map.items()}}  # "state0:"

        resolved_lines: tokens.Code = []
        '''Finished bitstrings, of arbitrary length. Will be packed into bytes later.'''

        # resolve clock constraints
        resolved_lines.extend(self.data.clock_constraints)

        # resolve transitions
        resolved_lines.extend(self.resolve_transition_defns())

        # resolve states
        resolved_lines.extend(
            self.resolve_state_section(context_map, trans_offset))

        # resolve main code body (without optimization at this point)
        resolved_lines.extend(self.resolve_code_section(
            self.data.lines_unresolved, context_map))

        main_memory = self.code_to_bytecode(resolved_lines)
        return AssemblerResult(
            trans_offset=trans_offset,
            state_offset=state_offset,
            prog_offset=prog_offset,
            trans_start=trans_start,
            clock_flags=clock_flags,
            final_input_map=final_input_map,
            main_memory=main_memory,
            assembler_state=copy.copy(self.data)
        )

    def parse_string(self, code: str) -> AssemblerResult:
        for line in code.split('\n'):
            self.parse_line(line)
        return self.resolve()


def verilog_translate_symbols(name: str, bit_len: int, map: dict[Any, int], file=None):
    tab = '    '
    print(f'function string {name}(input [{bit_len-1}:0] bits);', file=file)
    print(f'{tab}case(bits)', file=file)
    for k, v in map.items():
        print(f"{tab}{tab}{bit_len}'d{v}: {name} = \"{k}\";", file=file)
    print(f"{tab}{tab}default: {name} = $sformatf(\"<UNRECOGNIZED %d>\", bits);", file=file)
    print(f'{tab}endcase', file=file)
    print('endfunction', file=file)


def verilog_translate_ids(name: str, bit_len: int, map: dict[Any, int], file=None):
    tab = '    '
    print(f'function [{bit_len-1}:0] {name}(input string symbol);', file=file)
    print(f'{tab}case(symbol)', file=file)
    for v, k in map.items():
        print(f"{tab}{tab}\"{v}\": {name} = {bit_len}'d{k};", file=file)
    print(f"{tab}{tab}default: {name} = {{{bit_len}{{1'bx}}}};", file=file)
    print(f'{tab}endcase', file=file)
    print('endfunction', file=file)


def verilog_set_defines(map: dict[str, int], prefix: str = "", file=None):
    for k, v in map.items():
        print(f'`define {prefix}{k} {v}', file=file)


ass = RTEMAssembler(
    'pre_ASAP',
    inputs=dict(
        AS=28,
        VS=29,
        AP=30,
        VP=31
    ),
    clocks=dict(
        # clocks
        vevent=0,
        v=5
    ),
    constants=dict(
        # aviTicks=3, #x500x10000
        # aeiTicks=17, #x500x10000
        # uriTicks=4, #x1000x10000
        # lriTicks=10  #x1000x10000
    )
)
f = open('examples/rtem/pacemaker.rtem')
test = f.read()
f.close()
for line in test.split('\n'):
    ass.parse_line(line)

print(ass.data.clock_constraints)
result = ass.resolve()
print('Correspondence')
print(result.print_corresponence())
print('clock_flags', f'{result.clock_flags: 032b}')
print(result.final_input_map)
print(result.assembler_state.constant_map)


# config = RTEMConfig(
#     state_offset=result.state_offset,
#     trans_offset=result.trans_offset,
#     clock_flags=result.clock_flags,
#     clock_divider_immediate_values=(999, 0, 0, 499),
#     clock_joins=0,
#     program_length_sub1=12,
#     tick_length_sub1=9999,
#     main_memory=result.main_memory)

config = RTEMConfig(
    state_offset=result.state_offset,
    trans_offset=result.trans_offset,
    clock_flags=result.clock_flags,
    clock_divider_immediate_values=(9, 0, 0, 4),
    clock_joins=0,
    program_length_sub1=12,
    # tick_length_sub1=4999999*5*5,
    tick_length_sub1=49,
    main_memory=result.main_memory,
    config_root_cell='*/top_0/inst/cfg/'
)


# config = RTEMConfig(
#     state_offset=result.state_offset,
#     trans_offset=result.trans_offset,
#     clock_flags=result.clock_flags,
#     clock_divider_immediate_values=(9, 0, 0, 4),
#     clock_joins=0,
#     program_length_sub1=12,
#     tick_length_sub1=99,
#     main_memory=result.main_memory)

symbol_translation_file = open("../hdl/sim/symbol_translation.sv", 'w')
config.to_data_file('../hdl/sim/pacemaker.txt')
verilog_set_defines({
    "TICK_LENGTH": config.tick_length_sub1 + 1,
    "TICK_LENGTH_NS": (config.tick_length_sub1 + 1)*20,
    "PROGRAM_LENGTH": config.program_length_sub1 + 1
}, file=symbol_translation_file)

verilog_translate_symbols('get_input_symbol', 5,
                          result.final_input_map, file=symbol_translation_file)
verilog_translate_symbols('get_clock_symbol', 3,
                          ass.data.clock_map, file=symbol_translation_file)
verilog_translate_symbols('get_imm_symbol', 12,
                          ass.data.constant_map, file=symbol_translation_file)
verilog_translate_symbols('get_trans_symbol', 5,
                          ass.data.trans_map, file=symbol_translation_file)
verilog_translate_symbols('get_state_symbol', 4,
                          ass.data.state_map, file=symbol_translation_file)
verilog_translate_ids('get_input_id', 5, result.final_input_map, file=symbol_translation_file)

config2 = RTEMConfig(
    state_offset=result.state_offset,
    trans_offset=result.trans_offset,
    clock_flags=result.clock_flags,
    clock_divider_immediate_values=(999, 0, 0, 499),
    clock_joins=0,
    program_length_sub1=12,
    tick_length_sub1=5000-1,
    main_memory=result.main_memory,
    config_root_cell='*/top_0/inst/cfg/'
)

config2.to_xdc('examples/pacemaker.xdc')