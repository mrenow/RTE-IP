

from dataclasses import dataclass
import re
from typing import Any

from .tokens import UnresolvedCode, R, RTEMClock, RTEMClockConstraint, RTEMConstant, RTEMVar, RTEMTransition, RTEMState
from .helpers import regular_tokenizer, parse_int, ParsingException



def parse_extensions(line: str) -> UnresolvedCode:
    '''
    Takes input in the form
    "| VS | VP | AS | AP"
    '''
    toks = regular_tokenizer(line)
    assert len(toks) % 2 == 0
    ncommands = len(toks) // 2
    out: UnresolvedCode = []

    op_map = {
        '|': 0,
        '!|': 1,
        '|!': 2,
        '!|!': 3,
    }

    def create_closure(op, i, ncommands):
        return lambda t: f'{op:02b}{(i<ncommands-1):01b}{t[0]:05b}'

    for i in range(ncommands):
        op = toks[2*i].replace(' ', '')
        op = op_map.get(op)
        assert op is not None, f'Invalid operator {toks}'
        tok1 = parse_input(toks[2*i+1])
        if isinstance(tok1, int):
            out.append(f'{op:02b}{(i<ncommands-1):01b}{tok1:05b}')
        else:
            out.append(
                R((tok1,), create_closure(op, i, ncommands)))
    return out


def parse_input(token: str) -> RTEMClockConstraint | RTEMVar | int:
    '''
    Deermine the type of the given input.
    This will be used in some instructions to resol
    '''
    token = token.strip()
    if (m := re.search(r'(?P<clk>[A-z_][\w_]*)(?P<op>(>|<|=|<=|>=|!=|==))(?P<imm>[A-z_][\w_]*)', token)):
        clk = m.group('clk')
        imm = m.group('imm')
        op = m.group('op')
        return RTEMClockConstraint(op, RTEMClock(clk), RTEMConstant(imm))
    val = parse_int(token)
    if val is not None:
        return val
    return RTEMVar(token)  # Symbol to be resolved


def parse_transition(line: str) -> RTEMTransition:
    toks = regular_tokenizer(line)
    return RTEMTransition(
        RTEMState(toks[0]),
        set(RTEMClock(tok.replace('=0', '').strip()) for tok in toks[1:])
    )


class State():
    def parse_re(self, line, regex):
        match = re.match(regex, line)
        if not match:
            raise ParsingException(self, line, f'Expected {regex}')
        return match.groups()[1:]

    def ingest(self, line: str) -> tuple['State', UnresolvedCode, int]:
        '''
        Ingests a line of code and returns a new state object to be used at the next line.
        '''
        ...


class Command():
    __nargs: int
    __permit_extension: bool

    @classmethod
    def state(cls, *args: int):
        pass


class Commands():
    class PSH(State):
        def ingest(self, line: str) -> tuple[State, UnresolvedCode, int]:
            toks = regular_tokenizer(line)
            extensions = parse_extensions(" ".join(toks[1:]))
            ex = f'{bool(extensions):01b}'
            tok0 = parse_input(toks[0])
            psh: UnresolvedCode
            if not isinstance(tok0, int):
                psh = [R((tok0,), lambda t: f'10{ex}{t[0]:05b}')] + extensions
            else:
                psh = [f'{tok0:05b}']
            return STD(), psh, 8 + 8*len(extensions)

    class OP2(State):
        op_map = {
            'T': 0b1111,
            'F': 0b0000,
            '[0]': 0b0101,
            '[1]': 0b1010,
            '![0]': 0b0101,
            '![1]': 0b1010,
            '|': 0b1110,
            '&': 0b1000,
            '>': 0b0010,
            '<': 0b0100,
            '!|': 0b0001,
            '!&': 0b0111,
            '!>': 0b1101,
            '!<': 0b1011,
            '!^': 0b1001,
            '^': 0b0110,
            '==': 0b1001,
            '!=': 0b0110,
        }

        def ingest(self, line: str) -> tuple[State, UnresolvedCode, int]:
            toks = regular_tokenizer(line)
            pos = 0
            pop = 0
            op = self.op_map[toks[pos]]
            pos += 1
            if len(toks) <= pos:
                return STD(), [f'010{pop:01b}{op:04b}'], 8
            if toks[pos] == 'pop':
                pop = 1
                pos += 1
            if len(toks) <= pos:
                return STD(), [f'010{pop:01b}{op:04b}'], 8
            extensions = parse_extensions(" ".join(toks[pos:]))
            ex = bool(extensions)
            return STD(), [f'01{ex:01b}{pop:01b}{op:04b}'] + extensions, 8 + 8*len(extensions)

    class NXT(State):
        def ingest(self, line: str) -> tuple[State, UnresolvedCode, int]:
            toks = regular_tokenizer(line)
            pos = 0
            nargs = len(toks)
            type = (nargs == 2)
            if type:  # type 1
                up = int(toks[pos])
                pos += 1
                n = int(toks[pos])
                return TAB(up, 2**n), [f'001{up:01b}{2**n:04b}'], 8
            else:  # type 0
                tok = parse_int(toks[pos])
                if len(toks[pos:]) > 1 or tok is None:
                    transition = parse_transition(' '.join(toks[pos:]))
                    cmd = R((transition,), lambda t: f'000{t[0]:05b}')
                else:
                    cmd = f'000{tok:05b}'
                return STD(), [cmd], 8

    class EDI(State):
        '''
        EDI pop $0 & $1 

        '''
        @staticmethod
        def parse_stack_logic_expr(expr: str):
            '''
            Converts a stack logic expression (such as "$0 & $1") to it's corresponding bitstring 
            '''
            expr = expr.replace('$0', 'a').replace('$1', 'b').replace(
                '&', ' and ').replace('|', ' or ').replace('~', ' not ').replace('!', ' not ').strip()
            return ''.join((str(int(eval(expr, {'a': i & 1, 'b': bool(i & 2)}))) for i in range(3, -1, -1)))

        def ingest(self, line: str) -> tuple[State, UnresolvedCode, int]:
            regex = r"^(pop)?(.*?)(\|.+)?$"
            toks = re.match(regex, line.strip())
            if not toks:
                raise ParsingException(self, line, f'Expected {regex}')
            pop = bool(toks.group(1))
            bits = self.parse_stack_logic_expr(toks.group(2))
            ex = bool(toks.group(3))
            if ex:
                extensions = parse_extensions(toks.group(3).strip())
            else:
                extensions = []
            return EDIT(), [f'00{ex:01b}{pop:01b}{bits}', *extensions], 8


class STD(State):
    def ingest(self, line: str) -> tuple[State, UnresolvedCode, int]:
        toks = regular_tokenizer(line)
        return getattr(Commands, toks[0])().ingest(' '.join(toks[1:]))


class EDIT(State):
    '''
    <Var>:=[01] (END)?

    '''

    def ingest(self, line: str) -> tuple[State, UnresolvedCode, int]:
        regex = r"^([A-z0-9_]+)\s*=\s*([01])\s*(END)?\s*(,)?$"
        toks = re.match(regex, line.strip())
        if not toks:
            raise ParsingException(self, line, f'Expected {regex}')
        nxt = bool(toks.group(4))
        end = bool(toks.group(3))
        val = parse_int(toks.group(2))
        var = RTEMVar(toks.group(1))
        if not toks:
            raise ParsingException(
                self, line, f'Captured group(2) "{toks.group(2)}" from {regex} is not an integer')
        assert val is not None
        assert not (
            nxt and end), "Asserting END & NXT at the same time dissaloweed."
        next_state = EDIT() if nxt else STD()

        return next_state, [R((var,), lambda x: f'{end:01b}{val:01b}{nxt:01b}{x[0]:05b}')], 8


@dataclass
class TAB(State):
    up: int
    count: int

    def ingest(self, line: str) -> tuple[State, UnresolvedCode, int]:
        toks = regular_tokenizer(line)
        if self.count == 1:
            next_state = STD()
        else:
            next_state = TAB(self.up, self.count-1)
        transition = parse_transition(' '.join(toks))
        return next_state, [R((transition,), lambda t: f'{t[0]:04b}')], 4

    # '''
    # If no token matches the input string, return the string itself as a variable
    # to be resolved by the main system.
    # '''

    # def encode_token(self, pos: int, tokens: list[str]) -> int | str:
    #     pass
    # def encode_instruction(self, tokens: list[str]) -> tuple[list[int],]:

