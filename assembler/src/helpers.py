

import itertools
import re

from typing import *


class ParsingException(Exception):
    def __init__(self, state: Any, line: str, msg: str):
        super().__init__(msg)
        self.state = state
        self.line = line
        self.msg = msg


def parse_re(parent, line, regex):
    match = re.match(regex, line)
    if not match:
        raise ParsingException(parent, line, f'Expected {regex}')
    return match.groups()


def regular_tokenizer(line: str) -> list[str]:
    '''
    Tokenizes a line of code. Splits on whitespace and removes comments.
    '''
    # remove comment
    line = re.sub(r' *#.*', '', line)

    return [x for x in re.split(r'[,\s]+', line) if x]


def grouper(iterable, n, *, incomplete='fill', fillvalue=None):
    "Collect data into non-overlapping fixed-length chunks or blocks."
    # grouper('ABCDEFG', 3, fillvalue='x') → ABC DEF Gxx
    # grouper('ABCDEFG', 3, incomplete='strict') → ABC DEF ValueError
    # grouper('ABCDEFG', 3, incomplete='ignore') → ABC DEF
    iterators = [iter(iterable)] * n
    match incomplete:
        case 'fill':
            return itertools.zip_longest(*iterators, fillvalue=fillvalue)
        case 'strict':
            return zip(*iterators, strict=True)
        case 'ignore':
            return zip(*iterators)
        case _:
            raise ValueError('Expected fill, strict, or ignore')


def parse_int(string: str) -> int | None:
    try:
        return int(string)
    except ValueError:
        try:
            return int(string, 16)
        except ValueError:
            try:
                return int(string, 2)
            except ValueError:
                return None
