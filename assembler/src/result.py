

from .code_printer import CodePrinter
from .sections import AssemblerState
from .tokens import ByteCode, RTEMInput
from dataclasses import dataclass


@dataclass
class AssemblerResult:
    trans_offset: int
    state_offset: int
    prog_offset: int
    trans_start: int
    clock_flags: int
    final_input_map: dict[RTEMInput, int]
    main_memory: ByteCode

    assembler_state: AssemblerState
    '''
    The assember state at the time of this result.
    '''

    def print_corresponence(self):
        printer = CodePrinter(self.main_memory)
        lines: list[str] = []
        lines.extend(printer.accept(self.trans_start*8, '.ClockConstraints'))
        lines.extend(printer.accept(
            8*(self.trans_offset - self.trans_start), '.Transitions'))
        lines.extend(printer.accept(
            8*(self.state_offset - self.trans_offset), '.trans_offset'))
        lines.extend(printer.accept(0, '.StateAddresses'))
        lines.extend(printer.accept(
            8*(self.prog_offset - self.state_offset), '.state_offset'))

        self.assembler_state.code_correspondence.sort()
        prev_end = 0
        for start, length, line in self.assembler_state.code_correspondence:
            assert prev_end <= start
            if prev_end < start:
                lines.extend(printer.accept(start - prev_end, ''))
            lines.extend(printer.accept(length, line))
            prev_end = start + length
        return '\n'.join(lines)
