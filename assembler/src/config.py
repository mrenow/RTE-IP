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
from typing import Annotated, Sequence, get_origin
import sys
# Fields are additionally annotated with the bit length


@dataclass
class RTEMConfig:
    # Address of table containing state start addresses
    state_offset: Annotated[int, 8]
    # Start reference address for transition information
    trans_offset: Annotated[int, 8]
    program_length: Annotated[int, 8]  # Time until buffers are flushed - 1
    tick_length: Annotated[int, 16]  # Time until cycle repeats -1
    clock_flags: Annotated[int, 32]
    clock_joins: Annotated[int, 8]
    clock_divider_immediate_values: Annotated[tuple[int, int, int, int], 10]
    main_memory: Annotated[list[int], 8]

    comments: dict[int, list[str]] = field(init=False)

    '''
    
    '''

    def __post_init__(self):
        size = 0
        comments = {}
        for field_name in self.__annotations__:
            if get_origin(self.__annotations__[field_name]) != Annotated:
                continue

            comments[field_name] = size//8

            bit_length = self.__annotations__[field_name].__metadata__[0]
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
        for field_name in self.__annotations__:
            if get_origin(self.__annotations__[field_name]) != Annotated:
                continue
            bit_length = self.__annotations__[field_name].__metadata__[0]
            field_value = getattr(self, field_name)
            print(field_name, field_value, bit_length)
            if isinstance(field_value, Sequence):
                for value in field_value:
                    bytestream += format(value, f'0{bit_length}b')[::-1]
                    print(format(value, f'0{bit_length}b'))
            else:
                bytestream += format(field_value, f'0{bit_length}b')[::-1]
                print(format(field_value, f'0{bit_length}b'))

        # Convert bytestream to bytes in chunks
        byte_array = bytearray()
        for i in range(0, len(bytestream), 8):
            print(bytestream[i:i+8])
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


RTEMConfig(8, 13, 124, 45662, 0b00110011001100110011001100110011, 0b00110011, (0b0000000000,
           0b0000000000, 0b0000000000, 0b0000000000), [0b0010101]*256).to_data_file('test.hex')
