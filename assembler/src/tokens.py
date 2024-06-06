
from dataclasses import dataclass
import re

from typing import Literal, TypeVar, Callable, Mapping
from .helpers import parse_int


class RTEMTok:
    '''
    Represents an unresolved symbol in the RTEM language.

    '''

    def __hash__(self):
        ...

    def __repr__(self):
        ...


_TokenT = TypeVar('_TokenT', bound=RTEMTok)


@dataclass
class R:
    '''
    An unresolved reference.
    Comprised of a tuple of requested (hashable) objects, and a resolution function, which
    inserts the resolved values into a string.
    '''
    requests: tuple[RTEMTok]
    resolve_fn: Callable[[tuple[int, ...]], 'CodeLine']

    def resolve(self, map: Mapping[RTEMTok, int]) -> 'CodeLine':
        return self.resolve_fn(tuple(map[r] for r in self.requests))

    def __repr__(self) -> str:
        return f'R({",".join(map(str, self.requests))} -> {self.resolve_fn(tuple(0 for _ in self.requests))})'


# Types for better semantic readability
CodeLine = str
'''String of 1's and 0's'''
Code = list[CodeLine]
UnresolvedCodeline = str | R
UnresolvedCode = list[str | R]
'''List of arbitrary length strings of 1's and 0's'''
ByteCode = list[int]


def resolve_to_int(tok: _TokenT, token_mapping: Mapping[_TokenT, int]) -> int:
    # try token_mapping
    if tok in token_mapping:
        return token_mapping[tok]
    parsed = parse_int(str(tok))
    assert parsed is not None
    return parsed


@dataclass
class RTEMClock(RTEMTok):
    name: str

    def __post_init__(self):
        self.name = self.name.strip()
        assert self.name.isidentifier(), f'Invalid label name {self.name}'

    def __hash__(self):
        return hash((self.__class__, self.name))

    def __repr__(self):
        return f'{self.name}'


@dataclass
class RTEMConstant(RTEMTok):
    name: str
    
    def __post_init__(self):
        self.name = self.name.strip()
        assert self.name.isidentifier(), f'Invalid label name {self.name}'

    def __hash__(self):
        return hash((self.__class__, self.name))

    def __repr__(self):
        return f'{self.name}'


@dataclass
class RTEMState(RTEMTok):
    name: str

    def __post_init__(self):
        self.name = self.name.strip()
        assert self.name.isidentifier(), f'Invalid state name {self.name}'

    def __hash__(self):
        return hash((self.__class__, self.name))

    def __repr__(self):
        return f'{self.name}'

    def label(self, section: Literal['edit', 'trans']):
        return RTEMLabel(self.name, section)


@dataclass
class RTEMTransition(RTEMTok):
    next_state: RTEMState
    resets: set[RTEMClock]

    def __hash__(self) -> int:
        return hash((self.__class__, self.next_state, tuple(sorted(self.resets, key=lambda x: x.name))))

    def resolve_defn(self, token_mapping: dict[RTEMState | RTEMClock, int]) -> tuple[CodeLine, CodeLine]:
        '''
        Returns state, resets
        '''
        reset_string = [0 for _ in range(8)]
        for r in self.resets:
            reset_string[7-token_mapping[r]] = 1
        return f'{token_mapping[self.next_state]:04b}', ''.join(map(str, reset_string))

    def __repr__(self):
        return f'TRN({self.next_state},[{",".join(str(r) for r in sorted(self.resets, key=lambda x: x.name))}])'


class RTEMInput(RTEMTok):
    ...


@dataclass
class RTEMClockConstraint(RTEMInput):
    op: str
    clk: RTEMClock
    imm: RTEMConstant

    def __hash__(self):
        return hash((self.__class__, self.op, self.clk, self.imm))

    def __repr__(self):
        return f'CLK({self.clk}{self.op}{self.imm})'

    def resolve_defn(self, clks: Mapping[RTEMClock, int], constants: Mapping[RTEMConstant, int]) -> Code:
        imm = resolve_to_int(self.imm, constants)
        clk = resolve_to_int(self.clk, clks)
        match self.op:
            case '<':
                op = 0
            case '<=':
                op = 0
                imm += 1
            case '==' | '=':
                op = 1
        if clk < 4 and imm > 16:
            assert False, f'Low clocks cannot have immediate values greater than 16. {clk} {imm}'
        assert clk < 8 and imm < 2**12
        if clk % 2 == 0:
            return [f'0{op:01b}{clk//2:02b}{imm%16:04b}']
        else:
            return [f'1{op:01b}{clk//2:02b}{imm%16:04b}', f'{imm>>4:08b}']


@dataclass
class RTEMVar(RTEMInput):
    name: str

    def __post_init__(self):
        self.name = self.name.strip()
        assert self.name.isidentifier(), f'Invalid label name {self.name}'

    def __hash__(self):
        return hash((self.__class__, self.name))

    def __repr__(self):
        return f'{self.name}'


@dataclass
class RTEMLabel(RTEMTok):
    name: str
    section: Literal['edit', 'trans']

    def __post_init__(self):
        self.name = self.name.strip()
        assert self.name.isidentifier(), f'Invalid label name {self.name}'

    def __hash__(self):
        return hash((self.__class__, self.name))

    def __repr__(self):
        return f'{self.name}'