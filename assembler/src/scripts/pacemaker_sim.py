from dataclasses import dataclass
from typing import Literal
import subprocess
from time import time
    
GPIO_BASE = 0xA0000000
GPIO_READ_ACK_BASE = 0xA0000008

@dataclass
class Pacemaker:
    # params    
    duty_cycle: float = 0.8
    rate: float = 50/60

    # state
    state: Literal['PA', 'PV'] = 'PA'
    clk: float = 0
    io: int = 0

    def update(self, dt: float):
        self.clk += dt
        self.update_io()
        if self.state == 'PA':
            if self.check_atrial_sense():
                self.state = 'PV'
                self.clk = 0
            elif self.clk > self.duty_cycle/self.rate:
                self.atrial_pace()
                self.state = 'PV'
                self.clk -= self.duty_cycle/self.rate
        if self.state == 'PV':
            if self.check_ventricular_sense():
                self.state = 'PA'
                self.clk = 0
            elif self.clk > (1-self.duty_cycle)/self.rate:
                self.ventricular_pace()
                self.state = 'PA'
                self.clk -= (1-self.duty_cycle)/self.rate

    def write_io(self, value: int):
        subprocess.run(['devmem', f'0x{GPIO_BASE:08x}', '32', f'0x{1<<value:08x}'])
        subprocess.run(['devmem', f'0x{GPIO_BASE:08x}', '32', '0x00000000'])
        # print('written', value)

    def update_io(self):
        self.io = int(subprocess.run(['devmem', f'0x{GPIO_BASE:08x}', '32'], capture_output=True, text=True).stdout, 16)
        # indicate io has been read
        subprocess.run(['devmem', f'0x{GPIO_READ_ACK_BASE:08x}', '1', '1'])
        subprocess.run(['devmem', f'0x{GPIO_READ_ACK_BASE:08x}', '1', '0'])

    def check_atrial_sense(self):
        return bool(self.io & (1 << 30))

    def check_ventricular_sense(self):
        return bool(self.io & (1 << 31))
    
    def atrial_pace(self):
        self.write_io(30)

    def ventricular_pace(self):
        self.write_io(31)


if __name__ == '__main__':
    pacemaker = Pacemaker()
    t = time()
    while True:
        tnew = time() 
        dt = tnew - t
        t = tnew
        pacemaker.update(dt)
        pacemaker.rate += 0.1 * dt