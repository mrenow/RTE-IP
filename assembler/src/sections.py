from .code_printer import CodePrinter
import re

from typing import Any, ClassVar, TypeVar, Mapping, TypeVarTuple
from .states import State, STD, TAB, EDIT, Commands
from .tokens import RTEMClock, RTEMConstant, RTEMInput, RTEMTransition, RTEMVar, R, RTEMClockConstraint, RTEMLabel, RTEMState, ByteCode
from .helpers import grouper, parse_re, ParsingException, parse_int
from dataclasses import dataclass, field
import copy

T = TypeVar('T')
TT = TypeVarTuple('TT')




def should_ignore_line(line: str, ignore_metadata: bool = False):
    line = line.split('#')[0].strip()
    return not line or (ignore_metadata and (line.startswith('.') or line.endswith(':')))


@dataclass
class AssemblerState:
    constant_map: dict[RTEMConstant, int] = field(default_factory=dict)
    '''Static user-defined map for constants, clocks'''

    clock_map: dict[RTEMClock, int] = field(default_factory=dict)

    input_map: dict[RTEMInput, int] = field(default_factory=dict)
    '''Map between an input (actual input OR clock constraint) and its index'''

    input_vars: list[RTEMVar] = field(default_factory=list)
    '''Unbound inputs'''

    trans_map: dict[RTEMTransition, int] = field(default_factory=dict)
    '''Map between transition and it's index'''

    label_map: dict[RTEMLabel, int] = field(default_factory=dict)
    '''Map between label and it's address RELATIVE to the first instruction'''

    state_map: dict[RTEMState, int] = field(default_factory=dict)
    '''Map between state and it's id'''

    # self.trans_map_adjacency: dict[int, list[int]] = {}
    # For each transition, store the index of the other transitions it is found with
    # we need to store this in or

    state: State = field(default_factory=STD)

    lines_unresolved: list[str | R] = field(default_factory=list)

    current_address: int = 0
    current_line: int = 0
    current_bit: int = 0

    byte_pos: int = 0

    nclock_constraints: int = 0

    clock_constraints: list[str] = field(default_factory=list)

    code: list[str] = field(default_factory=list)
    '''Each line of code'''

    code_correspondence: list[tuple[int, int, str]
                              ] = field(default_factory=list)
    '''
    (start, length, line)
    Gives a correspondence between sections of bitstring and a line of code.
    Guaranteed that the sections are non-overlapping.
    '''

    # Other config
    clock_divider_immediate_values: tuple[int, int, int, int] = (0, 0, 0, 0)
    clock_joins: int = 0
    program_length: int = 0  # 12
    tick_length: int = 0  # 24


class Section:
    name: ClassVar[str]
    ass: AssemblerState

    class_map: ClassVar[dict[str, type['Section']]] = {}

    def __init_subclass__(cls) -> None:
        if hasattr(cls, 'name'):
            assert cls.name not in cls.class_map, f"Error while creating {cls} subclassing Section: class name {cls.name} is already defined for class {cls.class_map[cls.name]}"
            cls.class_map[cls.name] = cls

    def __init__(self, data: AssemblerState):
        self.ass = data

    def parse_line(self, line: str):
        ...


class CodeSection(Section):
    is_edit: ClassVar[bool]

    def check_label(self, line: str) -> str | None:
        '''
        Checks if a line is a label. If it is, returns the label name.
        '''
        match = re.match(r'([A-Za-z0-9_]+):', line.strip())
        if match:
            return match.group(1)
        return None

    def advance(self, bits: int):
        # assured that bits < 7
        rem = self.ass.current_bit % 8
        if rem and rem + bits > 8:
            self.ass.current_bit = ((self.ass.current_bit + 7) // 8) * 8

        self.ass.current_bit += bits
        self.ass.current_address = self.ass.current_bit // 8
        self.ass.byte_pos = self.ass.current_bit % 8
        print(f'addr {self.ass.current_address}:{self.ass.byte_pos}')

    def add_clock_constraint(self, identity: RTEMClockConstraint):
        if identity in self.ass.input_map:
            return
        self.ass.input_map[identity] = len(self.ass.clock_constraints)
        self.ass.nclock_constraints += 1
        # Clock constraints can be resolved directly to bytes
        self.ass.clock_constraints.extend(
            identity.resolve_defn(self.ass.clock_map, self.ass.constant_map))

    def process_ref(self, ref: R):
        for r in ref.requests:
            if isinstance(r, RTEMClockConstraint):
                self.add_clock_constraint(r)
            if isinstance(r, RTEMTransition):
                if r not in self.ass.trans_map:
                    self.ass.trans_map[r] = len(self.ass.trans_map)
                if r.next_state not in self.ass.state_map:
                    self.ass.state_map[r.next_state] = len(
                        self.ass.state_map)
            if isinstance(r, RTEMVar):
                if r.name not in self.ass.input_map:
                    self.ass.input_vars.append(r)

    def parse_line(self, line: str):
        if should_ignore_line(line) or line.startswith('.'):
            self.ass.code_correspondence.append(
                (self.ass.current_bit, 0, line))
            return

        if lab := self.check_label(line):
            # note down the address of the label, relative to the first intruction.
            # Note that this is not the absolute address, as there is a preamble before the first instruciton.
            # this will be resolved in the final pass.
            self.ass.label_map[RTEMLabel(
                lab, 'edit' if self.is_edit else 'trans')] = self.ass.current_address
            self.ass.code_correspondence.append(
                (self.ass.current_bit, 0, line))
            return

        self.ass.state, res, n = self.ass.state.ingest(line)
        if self.is_edit:
            if isinstance(self.ass.state, TAB):
                raise ParsingException(
                    self.ass.state, line, "NXT instructions not allowed in edit section")
        else:
            if isinstance(self.ass.state, EDIT):
                raise ParsingException(
                    self.ass.state, line, "EDI instructions not allowed in trans section")

        print(':::', res)
        # Register all the tokens we saw along the way.
        for s in res:
            if isinstance(s, R):
                self.process_ref(s)
        self.ass.lines_unresolved.extend(res)
        self.ass.code_correspondence.append((self.ass.current_bit, n, line))
        self.advance(n)


class EditSection(CodeSection):
    is_edit = True
    name = 'NextEdits'


class TransSection(CodeSection):
    is_edit = False
    name = 'NextTrans'


class ConstSection(Section):
    name = 'Constants'

    def parse_line(self, line: str):
        if should_ignore_line(line, ignore_metadata=True):
            return
        name, val = parse_re(self, line.strip(), r"^(\w+)\s*=\s*(\w+)$")
        val = parse_int(val)
        if val is None:
            raise ParsingException(
                self, line, "Value of rhs of declaration unrecognized")
        constant = RTEMConstant(name)
        if constant in self.ass.constant_map:
            raise ParsingException(
                self, line, 'Duplicate constant declaration detected.')
        self.ass.constant_map[constant] = val
