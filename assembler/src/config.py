'''
Provide a convenient with which to generate hex files for
the RTEM.
'''
# Memory structure:
# 0: State Offsets #4
# 1: Transition Offsets #4
# 2: Program Length #8
# 3: Tick Length #16
# 4: Clock Flags #32
# 5: Clock Joins #8
# 6: Clock Divider Immediate Values #10
# 7: Clock Divider Immediate Values #10
# 8: Clock Divider Immediate Values #10
# 9: Clock Divider Immediate Values #10
# 10: Main Memory #8x256
from dataclasses import dataclass, field
import itertools
from typing import Annotated, Any, ClassVar, Sequence, get_origin
import sys
# Fields are additionally annotated with the bit length


@dataclass
class RTEMConfigFieldMeta:
    reg_size: int
    cell: str


@dataclass
class RTEMConfig:
    # Address of table containing state start addresses

    state_offset: Annotated[int, RTEMConfigFieldMeta(
        8, 'cfg_state_offs_reg/scan_reg_reg')]
    # Start reference address for transition information
    trans_offset: Annotated[int, RTEMConfigFieldMeta(
        8, 'cfg_trans_offs_reg/scan_reg_reg')]
    program_length_sub1: Annotated[int, RTEMConfigFieldMeta(
        8, 'cfg_prog_len_reg/scan_reg_reg')]
    '''Time until buffers are flushed - 1'''
    tick_length_sub1: Annotated[int, RTEMConfigFieldMeta(
        32, 'cfg_tick_len_reg/scan_reg_reg')]
    '''Time until cycle repeats -1'''
    clock_flags: Annotated[int, RTEMConfigFieldMeta(
        32, 'cfg_clk_flags_reg/scan_reg_reg')]
    clock_joins: Annotated[int, RTEMConfigFieldMeta(
        8, 'cfg_clk_joins_reg/scan_reg_reg')]

    # Cycle time - 1
    clock_divider_immediate_values: Annotated[tuple[int, int, int, int], RTEMConfigFieldMeta(
        10, 'genblk1[*].cfg_clk_div_imm_reg/scan_reg_reg')]
    main_memory: Annotated[list[int], RTEMConfigFieldMeta(
        8, 'cfg_main_memory/memory_reg[*]')]


    config_root_cell: str = 'design_1_i/top_0/inst/cfg/'
    comments: dict[int, list[str]] = field(init=False)
    '''
    
    '''
    @classmethod
    def get_meta(cls, field: str) -> RTEMConfigFieldMeta:
        return cls.__annotations__[field].__metadata__[0]

    @classmethod
    def get_type(cls, field: str) -> type[int] | type[Sequence[int]]:
        return cls.__annotations__[field].__metadata__[0]

    @classmethod
    def iter_fields(cls):
        for field_name in cls.__annotations__:
            if get_origin(cls.__annotations__[field_name]) != Annotated:
                continue
            yield field_name

    def __post_init__(self):
        size = 0
        comments = {}
        for field_name in self.iter_fields():
            comments[field_name] = size//8
            meta = self.get_meta(field_name)
            bit_length = meta.reg_size
            field_value = getattr(self, field_name)
            if isinstance(field_value, Sequence):
                size += bit_length * len(field_value)
            else:
                size += bit_length

        comments['.ClockConstraints'] = comments['main_memory']
        comments['trans_offset:'] = comments['main_memory'] + self.trans_offset
        comments['.StateAddresses'] = comments['main_memory'] + \
            self.state_offset
        comments['state_offset:'] = comments['main_memory'] + self.state_offset

        self.comments = {}
        for k, v in comments.items():
            if v not in self.comments:
                self.comments[v] = [k]
            else:
                self.comments[v].append(k)

    '''

    A2 BA98
    A2 7654
    A1 3210
    '''

    def to_bytestream(self) -> bytes:
        '''
        Generates a bytestream from this object. Bit lengths of each field are
        inferred from the annotation
        '''
        bytestream = ''
        for field_name in self.iter_fields():
            meta = self.get_meta(field_name)
            bit_length = meta.reg_size
            field_value = getattr(self, field_name)
            if isinstance(field_value, Sequence):
                for value in field_value:
                    bytestream += format(value, f'0{bit_length}b')[::-1]
            else:
                bytestream += format(field_value, f'0{bit_length}b')[::-1]

        # Convert bytestream to bytes in chunks
        byte_array = bytearray()
        for i in range(0, len(bytestream), 8):
            byte_array.append(int(bytestream[i:i+8], 2))

        return bytes(byte_array)

    def to_data_file(self, filename: None | str = None):
        '''
        Writes the bytestream to a verilog data file. If filename is None, the bytestream is printed
        '''

        if filename is None:
            file = sys.stdout
        else:
            file = open(filename, 'w')
        byte_array = self.to_bytestream()
        for idx, byte in enumerate(byte_array):
            if self.comments.get(idx) is not None:
                file.write(f"{byte:02x} // {' '.join(self.comments[idx])}\n")
            else:
                file.write(f"{byte:02x}\n")

        if filename is not None:
            file.close()

    def to_xdc(self, filename: None | str = None):
        '''
        Writes the bytestream to a xdc file. If filename is None, the bytestream is printed
        '''

        if filename is None:
            file = sys.stdout
        else:
            file = open(filename, 'w')

        def init_line(bit, cell):
            return [f"set_property INIT 1'b{bit} [get_cells {self.config_root_cell + cell}]"]
    
        # keep constraints
        lines = []
        for field_name in self.iter_fields():
            meta = self.get_meta(field_name)
            lines.append(f'set_property KEEP 1 [get_cells {self.config_root_cell}{meta.cell}[*]]')
            
        for field_name in self.iter_fields():
            meta = self.get_meta(field_name)
            field_value = getattr(self, field_name)
            
            if isinstance(field_value, Sequence):
                for idx, value in enumerate(field_value):
                    for idx2, bit in enumerate(reversed(f"{{:0{meta.reg_size}b}}".format(value))):
                        lines.extend(init_line(int(bit), meta.cell.replace('*', str(idx)) + f'[{idx2}]'))

            else:
                for idx, bit in enumerate(reversed(f"{{:0{meta.reg_size}b}}".format(field_value))):
                    lines.extend(init_line(int(bit), meta.cell + f'[{idx}]'))

        file.write("\n".join(lines))
                    

RTEMConfig(8, 13, 124, 45662, 0b00110011001100110011001100110011, 0b00110011, (0b0000000000,
           0b0000000000, 0b0000000000, 0b0000000000), [0b0010101]*256).to_data_file('test.hex')
