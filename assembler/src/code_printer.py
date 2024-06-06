
class CodePrinter:
    def __init__(self, mem: list[int], line_offset: int = 0):
        self.mem = mem  # assumed each string is length 8
        self.curr_bit = 0
        self.line_offset = line_offset

    def accept(self, n: int, line: str = '') -> list[str]:
        line_str = ' |' + line if line else ''
        if n == 0:
            return [' '*21 + line_str]
        st_line = self.curr_bit // 8
        st_bit = self.curr_bit % 8
        self.curr_bit += n
        end_line = (self.curr_bit - 1) // 8
        end_bit = (self.curr_bit - 1) % 8 + 1
        lines = list[str]()
        for i in range(st_line, end_line+1):
            bit_string = f'{self.mem[i]:08b}'

            start = st_bit if i == st_line else 0
            end = end_bit if i == end_line else 8

            prefix = f'::: {i + self.line_offset: 03d}: ' if start == 0 else ' '*9
            suffix = ' :::' if end == 8 else ' '*4

            out_line = prefix + ' '*(8-end_bit) + \
                f'{bit_string[8-end_bit:8-st_bit]}' + \
                ' '*(st_bit) + suffix
            if i == st_line:
                out_line += line_str
            lines.append(out_line)
        return lines