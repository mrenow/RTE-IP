# Description



|SETUP  |FLUSH
|
|[      ]




## Registers
**Instruction Pieces**
`DATA[7:5]`: opcode, and extension code typically.
`DATA[4]`: Sometimes the highest bit of a 5-bit address.
`DATA[3:0]`: Usually an address.
`HI(1)`: Affects Whether to select the high or low half nibble of the byte to load into `DATA[3:0]`.
**Program Flow**
`EC(4)`: One-hot encoded execution cycle for the multi-cycle design.
`ES(?)`: Execution State. Exact size of this register may be to the disgression of the HDL synthesis tool. 
`PC(8)`: Program Counter
`RA(8)`: Return Address.
`JC(3)`: Jump Counter. Counts down after each instruction, loading `PC<=RA` once it reaches 0. 
**Resources**
`CLKS(8, (4 or 12))`: Clocks
`MEM(256, 8)`: Main memory
`IN(32)`: Set of input variables
`IN_INVALID(32)`: Indicates which clock constraints are not yet calculated on this policy state
**Output**
`EDIT_D(32)`: Edit data
`NEXT_STATE(4)`
**Static Config**
`cfg_trans_offs(8)`: Address around which transition data is defined.
`cfg_state_offs(8)`: Address after which the starting addresses for each state are defined.
`cfg_prog_len(PROG_LEN_SIZE)`: Number of ticks until buffer flush
`cfg_tick_len(TICK_LEN_SIZE)`: Number of ticks between transitions
`cfg_clk_flags(32)`: Indicates which rows of memory are clocks
`cfg_clk_joins(8)`: Indicates which clocks are joined to the previous clock
`cfg_clk_div_imm(40)`: Indicates 

# Signals
Signals are either boolean values read from pins, or clock constraints (i.e. the boolean value returned when comparing one clock to a fixed constant). Signals are stored in a 5-bit addressed memory with two bits: `{data, valid}`. Now only the pin-signals are loaded in upon entry to a policy state, and their valid bits are set to 1 (which signals are from pins is configured using the `cfg_clk_flags` config). If the input address refers to a clock constraint, it is not loaded until it is requested. Whether or not to request a variable is determined through the valid bit in the memory. The value of the clock constraint is then determined by instructions in main memory which correspond to the signal address.

## Memory Structure
Main memory is shared between Transition and Edit machines.
### Clock Constraints
The start of memory is home to clock constraints (CLK0, CLK1). This is so that we can naturally map the clock constraint at `MEM[x]` to `IN[x]`, where `x` is between 0 and 31. For these addresses only, we implement double reading of instructions, as 12-bit clock constraints span two bytes.

Clock constraints are calculated on-demand only. When a clock constraint is to be calculated, it will be calculated on the next A cycle, before returning to the same functionality as the B cycle.
### Transitions
Transitions are actions defined as a next state, and a set of clock resets. State is 4 bits, and clock resets are 8 bits, one for each clock. We aim to pack the data without holes, so state will be packed two-to-a-byte, while clock resets take a byte each.

We configure the address `cfg_trans_offs` *around* which the transition information is placed. The state is packed in the increasing direction, while resets are packed in the decreasing direction. For a transition with id `x`, it's state will be found in `cfg_trans_offs + x >> 1`, while it's clock resets are found at `cfg_trans_offs + ~x` .

### Nominal offsets
Some configuration variables are offset from their nominal values. This is so that the execution scheme is uniform.
- State address table. Each address is the `addr_nom - cfg_trans_offs`
- progam length, tick length and clock dividers are all 1 less than the nominal lengths.


### State Addresses
Starting PC for each states is defined after the address `cfg_state_offs`. They are defined in pairs for the Transition Machine and Edit machine.
### Example Memory

```
0:  0{op:1}{clk:2}{imm:4}  // IN[0], 4 bit clock
1:  0{op:1}{clk:2}{imm:4}  // IN[1], 4 bit clock
2:  1{op:1}{clk:2}{imm:4}  // IN[2], 12 bit clock
3:  {imm:8}
4:  1{op:1}{clk:2}{imm:4}  // IN[4], 12 bit clock
5:  {imm:8}
10: {state3:4}{state2:4}   // cfg_trans_offs
11: {state1:4}{state0:4}
6:  {reset0:8}
7:  {reset1:8}
8:  {reset2:8}
9:  {reset3:8}
12: {tra_addr0:8}          // cfg_state_offs
13: {edi_addr0:8}
14: {tra_addr1:8}
15: {edi_addr1:8}
16: {tra_addr2:8}
17: {edi_addr2:8}
...
```

## Control unit
Datapath control signals are determined by three things:
- Information from current instruction
- Execution State (ES)
- Execution Cycle (CYCLE)

Execution State allows us to interpret bytes differently depending on the context, and get considerably more mileage out of the 1-byte format. It can be thought of as an opcode extension that resides in a register.






# Instruction Tables
## KEY
`<=` Assignment on clock edge
`:=` Alias definition
`{a,b,c}` signal concatenation
`PUSH(), POP()` push/pop commands on stack
`$0, $1` First & second elements of stack.
`UPPERCASE` Global identifier
`lowercase` local alias for a signal


## For Edit Machine
Note: In the Code Column, \* indicates that the instruction is shared between the Edit and Transition machines.  

| Assembler Code | ES     | Format                         | Description<br>                                                                                                                                                                                                                                                                                  | Actions<br>++++++++++++++++++++++++++++++                                                                                                                                                                                                    |
| -------------- | ------ | ------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| *EDIT          | INIT   | `{addr:8}`                     | **Start execution.**<br>Goto address `addr`.                                                                                                                                                                                                                                                     | CYCLE 0<br>`addr:=MEM[PC]`<br>`{OP,EX,VAR}<=addr`<br>CYCLE 1<br>`addr:={OP,EX,VAR}`<br>`PC<=addr + TRAN_OFFS`<br>`ES<=STD`                                                                                                                   |
| *CLK0          | CLK    | `0{op:1}{clk:2}{imm:4}`        | **Short clock constraint.**<br>Compares the 4-bit clock `{clk, 0}`  to `imm`. `op` == 1 specifies 'equality', and 'less than' otherwise.                                                                                                                                                         | CYCLE 2<br>`{_,op,clk,imm}:=MEM[VAR]`<br>`val:=CLKS[{clk,0}]`<br>if `op`:<br>-> `IN[VAR]<=(val==imm)`<br>else:<br>-> `IN[VAR]<=(val<imm)`<br>`IN_INVALID[VAR] <= 0`<br>DO CYCLE 1                                                            |
| *CLK1          | CLK    | `1{op:1}{clk:2}{imm:12}`       | **Long clock constraint.**<br>Compares the 4-bit clock `{clk, 1}`  to `imm`. `op` == 1 specifies 'equality', and 'less than' otherwise. This instruction reads two bytes from memory.                                                                                                            | CYCLE 2<br>`{_,op,clk,imm}:=MEM[VAR]`<br>`imm2:=MEM[VAR+1]`<br>`val:=CLKS[{clk,1}]`<br>if `op`:<br>-> `IN[VAR]<=(val=={imm,imm2})`<br>else:<br>-> `IN[VAR]<=(val<{imm,imm2})`<br>`IN_INVALID[VAR] <= 0`<br>DO CYCLE 1                        |
| *PSH           | STD    | `01{ex:1}{var:5}`              | **Push value onto stack.**<br>Chain ACC commands if `ex`. If var refers to a clock, and that clock has not been computed, go do that.                                                                                                                                                            | CYCLE 0<br>`{_,var,ex}:=MEM[PC]`<br>`VAR<=var`<br>`EX<=ex`<br>CYCLE 1<br>If `IN_INVALID[VAR]`:<br>-> `PC_EN <= 0`<br>-> `ES <= CLK`<br>-> `PC <= VAR` <br>else:<br>-> `PUSH()`<br>-> `$0<=IN[VAR]`<br>-> If `EX`:<br>---> `ES<=ACC`          |
| *OP            | STD    | `10{ex:1}{pop:1}{lut:4}`       | **Binary logic operation**.<br>Perform a binary logic operation on first two bits of stack, and push the result. Chain ACC commands if `ex`. If `pop`, consume both elements.                                                                                                                    | CYCLE 0<br>`{_,ex,pop,lut}:=MEM[PC]`<br>`VAR<={pop, lut}`<br>`EX<=ex`<br>CYCLE 1<br>`{pop,lut}:=VAR`<br>If `pop`:<br>-> `POP()`<br>else:<br>-> `PUSH()`<br>`$0<=lut[{$1, $0}]`<br>If `EX`:<br>-> `ES<=ACC`                                   |
| *DO            | STD    | `11{n:2}{addr:4}`              | **Reuse previous code**.<br>This function exists to save precious memory space.<br>Jump backwards by `addr + n + 1`, and run `n+1` instructions before returning to the instruction directly after this one.                                                                                     | CYCLE 0<br>`{_,n,addr}:=MEM[PC]`<br>`JC<=n+2`<br>`VAR<=(~addr)+(~n)`<br>CYCLE 1<br>`RA<=PC+1`<br>`PC<=PC+1+VAR`                                                                                                                              |
| *ACC           | ACC    | `{op:2}{ex:1}{var:5}`          | **Accumulate on $0**.<br>Accumulate on the first stack value using the specified operation. The operation is AND, where the inputs are inverted depending on their bit in `op`. Asserting `ex` will continue to chain ACC comands.                                                               | CYCLE 0<br>`{op,ex,var}:=MEM[PC]`<br>`OP<=op`<br>`VAR<=var`<br>`EX<=ex`<br>CYCLE 1<br>If `IN_INVALID[VAR]`:<br>-> `PC_EN <= 0`<br>-> `ES <= CLK_ACC`<br>else:<br>-> `$0<=(OP[0]^$0)&(OP[1]^IN[VAR])`<br>-> If `!EX`:<br>---> `ES<=STD`       |
| VIO            | STD    | `00{ex:1}{pop:1}{lut:4}`       | ** Declare edit block**.<br>Commit the proceeding edits if the binary operation on the first two bits yields True. Chain ACC commands on the test value if `ex`. If `pop`, consume one element from the stack.                                                                                   | CYCLE 0<br>`{ex,pop,lut}:=MEM[PC]`<br>`EX<=ex`<br>`VAR<={pop,lut}`<br>CYCLE 1<br>`{pop,lut}:=VAR`<br>If `pop`:<br>-> `POP()`<br>`$0<=lut[{$1,$0}]`<br>If `EX`:<br>-> `ES<=EACC`<br>else:<br>-> `ES <= EDIT`                                  |
| *ACC           | ACC    | `{op:2}{ex:1}{var:5}`          | **Accumulate on $0**.<br>Accumulate on the first stack value using the specified operation. The operation is AND, where the inputs are inverted depending on their bit in `op`. Asserting `ex` will continue to chain ACC comands.                                                               | CYCLE 0<br>`{op,ex,var}:=MEM[PC]`<br>`OP<=op`<br>`VAR<=var`<br>`EX<=ex`<br>CYCLE 1<br>If `IN_INVALID[VAR]`:<br>-> `PC_EN <= 0`<br>-> `ES <= CLK_ACC`<br>else:<br>-> `$0<=(OP[0]^$0)&(OP[1]^IN[VAR])`<br>-> If `!EX`:<br>---> `ES<=STD`       |
| ACC            | E_ACC  | `{op:2}{ex:1}{var:5}`          | **Accumulate.**<br>Same as above, except that ending the chain returns to the `EDIT` state. If the accumulated value is 1, the proceeding edits will be executed.                                                                                                                                | CYCLE 0<br>`{op,ex,var}:=MEM[PC]`<br>`OP<=op`<br>`EX<=ex`<br>`VAR<=var`<br>CYCLE 1<br>If `IN_INVALID[VAR]`:<br>-> -> `PC_EN <= 0`<br>-> `ES <= E_CLK_ACC`<br>else:<br>-> `$0<=(OP[0]^$0)&(OP[1]^IN[VAR])`<br>-> If `!EX`:<br>---> `ES<=EDIT` |
| EDI            | EDIT   | `{end:1}{val:1}{nxt:1}{var:5}` | **Specify edit.**<br>If the first element on the stack (written by a proceeding VIO or VIO_ACC instruction) is 1, then override the value output value of `var` to be `val`. Continue chaining these instructions by asserting `nxt`. End the execution of this policy state by asserting `end`. | CYCLE 0<br>`{end,val,nxt,var}:=MEM[PC]`<br>`OP<={end,val}`<br>`EX<=nxt`<br>`VAR<=var`<br>CYCLE 1<br>`{end, val}:=OP`<br>if `$0`:<br>-> `EDIT_D[VAR]<=val`<br>if `end`:<br>-> DO FINISH<br>else if `!EX`:<br>-> `POP()`<br>-> `ES<=STD`       |
|                | FINISH |                                |                                                                                                                                                                                                                                                                                                  | CYCLE 0<br>CYCLE 1<br>if `do_setup`:<br>-> `ES <= SETUP`                                                                                                                                                                                     |
|                | SETUP  |                                |                                                                                                                                                                                                                                                                                                  | CYCLE 0<br>`VAR <= {NEXT_STATE, 1}`<br>CYCLE 1<br>`PC<=VAR + cfg_state_offs`<br>`ES<=INIT`                                                                                                                                                       |

## For Transition Machine


| Assembler<br>Code | ES     | Format                   | Description<br>                                                                                                                                                                                                                                                           | Actions<br>++++++++++++++++++++++++++++++                                                                                                                                                                                              |
| ----------------- | ------ | ------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| *TRAN             | INIT   | `{addr:8}`               | **Start execution.**<br>Goto address `addr`.                                                                                                                                                                                                                              | CYCLE 0<br>`addr:=MEM[PC]`<br>`{OP,EX,VAR}<=addr`<br>CYCLE 1<br>`addr:={OP,EX,VAR}`<br>`PC<=addr`<br>`ES<=STD`                                                                                                                         |
| *CLK0             | CLK    | `0{op:1}{clk:2}{imm:4}`  | **Short clock constraint.**<br>Compares the 4-bit clock `{clk, 0}`  to `imm`. `op` == 1 specifies 'equality', and 'less than' otherwise.                                                                                                                                  | CYCLE 2<br>`{_,op,clk,imm}:=MEM[VAR]`<br>`val:=CLKS[{clk,1}]`<br>if `op`:<br>-> `IN[VAR]<=(val==imm)`<br>else:<br>-> `IN[VAR]<=(val<imm)`<br> `IN_INVALID[VAR] <= 0`<br>DO CYCLE 1                                                     |
| *CLK1             | CLK    | `1{op:1}{clk:2}{imm:12}` | **Long clock constraint.**<br>Compares the 4-bit clock `{clk, 1}`  to `imm`. `op` == 1 specifies 'equality', and 'less than' otherwise. This instruction reads two bytes from memory.                                                                                     | CYCLE 2<br>`{_,op,clk,imm}:=MEM[VAR]`<br>`imm2:=MEM[VAR+1]`<br>`val:=CLKS[{clk,1}]`<br>if `op`:<br>-> `IN[VAR]<=(val=={imm,imm2})`<br>else:<br>-> `IN[VAR]<=(val<{imm,imm2})`<br>`IN_INVALID[VAR] <= 0`<br>DO CYCLE 1                  |
| *PSH              | STD    | `01{ex:1}{var:5}`        | **Push value onto stack.**<br>Chain ACC commands if `ex`. If var refers to a clock, and that clock has not been computed, go do that.                                                                                                                                     | CYCLE 0<br>`{_,var,ex}:=MEM[PC]`<br>`VAR<=var`<br>`EX<=ex`<br>CYCLE 1<br>If `IN_INVALID[VAR]`:<br>-> `PC_EN <= 0`<br>-> `ES <= CLK`<br>else:<br>-> `PUSH()`<br>-> `$0<=IN[VAR]`<br>-> If `EX`:<br>---> `ES<=ACC`                       |
| *OP               | STD    | `10{ex:1}{pop:1}{lut:4}` | **Binary logic operation**.<br>Perform a binary logic operation on first two bits of stack, and push the result. Chain ACC commands if `ex`. If `pop`, consume both elements.                                                                                             | CYCLE 0<br>`{_,ex,pop,lut}:=MEM[PC]`<br>`VAR<={pop, lut}`<br>`EX<=ex`<br>CYCLE 1<br>`{pop,lut}:=VAR`<br>If `pop`:<br>-> `PUSH()`<br>else:<br>-> `POP()`<br>`$0<=lut[{$1, $0}]`<br>If `EX`:<br>-> `ES<=ACC`                             |
| *DO               | STD    | `11{n:2}{addr:4}`        | **Reuse previous code**.<br>This function exists to save precious memory space.<br>Jump backwards by `addr + n + 1`, and run `n+1` instructions before returning to the instruction directly after this one.                                                              | CYCLE 0<br>`{_,n,addr}:=MEM[PC]`<br>`JC<=n+2`<br>`VAR<=(~addr)+(~n)`<br>CYCLE 1<br>`RA<=PC+1`<br>`PC<=PC+1+VAR`                                                                                                                        |
| *ACC              | ACC    | `{op:2}{ex:1}{var:5}`    | **Accumulate on $0**.<br>Accumulate on the first stack value using the specified operation. The operation is AND, where the inputs are inverted depending on their bit in `op`. Asserting `ex` will continue to chain ACC comands.                                        | CYCLE 0<br>`{op,ex,var}:=MEM[PC]`<br>`OP<=op`<br>`VAR<=var`<br>`EX<=ex`<br>CYCLE 1<br>If `IN_INVALID[VAR]`:<br>-> `PC_EN <= 0`<br>-> `ES <= CLK_ACC`<br>else:<br>-> `$0<=(OP[0]^$0)&(OP[1]^IN[VAR])`<br>-> If `!EX`:<br>---> `ES<=STD` |
| NXT1              | STD    | `000{addr:5}`            | **Unconditional transition.**<br>Perform transition specfied by `addr`. Transitions are specified in instruction memory around `traOffset`. states are 4 bit and stored in front of `traOffset`, two per byte. Clock resets are 1 byte and are stored behind `traOffset`. | CYCLE 0<br>`{_, addr}:=MEM[PC]`<br>`VAR<=addr`<br>`JC<=2`<br>CYCLE 1<br>`HI<=VAR[0]`<br>`RA<=cfg_trans_offs + ~(VAR[4:0]>>1)`<br>`PC<=cfg_trans_offs + VAR[4:0]`<br>`ES<=TRA`                                                                  |
| NXT2              | STD    | `001{up:1}{len:4}`       | **Declare transition jump table.**<br>Construct a jump table using the first `len` bits of the stack as the index. We pack two stack id's per byte, so we specify the 5th bit using `up`.                                                                                 | CYCLE 0<br>`{_,up,len}:=MEM[PC]`<br>`VAR<={up,len}`<br>CYCLE 1<br>`{_,len}:=VAR`<br>`val:=stack[4:1]`<br>`PC<=PC + 1 + val`<br>`ES<=NXT`<br>`HI<=$0`<br>                                                                               |
| TAB               | NXT    | `{hi:4}{lo:4}`           | **Transition jump table row**<br>Rows of the NXT jump table.<br>Set up state to perform the transition with the id specified by either `hi` or `lo`, selecting based on the `HI` register. Following this, execute TRA and RST.                                           | CYCLE 0<br>`{hi,lo}:=MEM[PC]`<br>if `HI`:<br>-> `VAR[3:0]<=hi`<br>else:<br>-> `VAR[3:0]<=lo`<br>`JC<=2`<br>CYCLE 1<br>`HI<=VAR[0]`<br>`RA<=cfg_trans_offs + ~(VAR[4:0]>>1)`<br>`PC<=cfg_trans_offs + VAR[4:0]`<br>`ES<=RST`                    |
| TRA               | TRA    | `{hi:4}{lo:4}`           | **Transition state data declaration.**<br>Set the next state to the nibble specified by the `HI` register.                                                                                                                                                                | CYCLE 0<br>`{hi,lo}:=MEM[PC]`<br>if `HI`:<br>-> `VAR[3:0]<=hi`<br>else:<br>-> `VAR[3:0]<=lo`<br>CYCLE 1<br>`NEXT_STATE<=VAR[3:0]`<br>`ES<=FINISH`                                                                                      |
| RST               | RST    | `{rst:8}`                | **Transition reset data declaration.**<br>Reset the clocks according to the asserted bits in `rst`.                                                                                                                                                                       | CYCLE 0<br>`rst:=MEM[PC]`<br>`VAR<=rst`<br>CYCLE 1<br>`rst:=VAR`<br>apply `rst`<br>`ES<=TRA`                                                                                                                                           |
|                   | FINISH |                          |                                                                                                                                                                                                                                                                           | CYCLE 0<br>CYCLE 1<br>if `do_setup`:<br>-> `ES <= SETUP`                                                                                                                                                                               |
|                   | SETUP  |                          |                                                                                                                                                                                                                                                                           | CYCLE 0<br>`VAR <= {NEXT_STATE, 0}`<br>CYCLE 1<br>`PC<=VAR + cfg_state_offs`<br>`ES<=INIT`                                                                                                                                                 |



## Assumed state behaviour



| State       | Description                                                                                    | Actions<br>++++++++++++++++++++++++++++++++++++++++                                                            |     |
| ----------- | ---------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------- | --- |
| SETUP0      |                                                                                                | `VAR[E]<={NEXT_STATE,0}`<br><br>                                                                               |     |
| SETUP1(1)   | Load inputs. Setup initial states for both machines. Load Initial ES, kicking off the machine. | `PC[E]<=VAR[E] + cfg_state_offs`<br>`ES[E]<=INIT`<br><br>`VAR[T]<={NEXT_STATE,1}`                              |     |
| SETUP2(0)   |                                                                                                | `PC[T]<=VAR[T] + cfg_state_offs`<br>`ES[T]<=INIT`<br>                                                          |     |
| CYCLE 0(1)  |                                                                                                | if `JC != 0`:<br>-> `JC<=JC-1`                                                                                 |     |
| CYCLE 1 (1) |                                                                                                | if `!extraCycle`:<br>-> `PC<=PC+1`<br>-> <br>-> if `JC==1`:<br>---> `PC <= RA`<br>else:<br>-> `CYCLE<=CYCLE 2` |     |
| CYCLE 2     |                                                                                                | `CYCLE <= CYCLE 1`<br>                                                                                         |     |
| FINSH       | Wait until trigger condition                                                                   | if `t>1`                                                                                                       |     |
|             |                                                                                                |                                                                                                                |     |


`PC`
`PC<=cfg_trans_offs + ~addr`
`PC<=cfg_trans_offs + ~VAR`
