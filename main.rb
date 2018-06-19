class Clock
    
    # Define constants for clock cycles
    A = 1
    B = 2
    C = 3
    D = 4
    E = 5
    F = 6
    
    attr_reader :cycle
    
    def initialize
        @cycle = A
    end
    
    def next_cycle
        @cycle =
            case @cycle
            when A then B
            when B then C
            when C then D
            when D then E
            when E then F
            when F then A
            end
            
    end
    
    def to_s
        case @cycle
        when A then "A"
        when B then "B"
        when C then "C"
        when D then "D"
        when E then "E"
        when F then "F"
        end
    end
    
end

class Memory
    
    def initialize (instructions)
        @memory = instructions
    end
    
    def posedge_ace (address)
        [@memory[address], @memory[address - 1]]
    end
    
    def posedge_f (address, value, write_enabled)
        if write_enabled
            @memory[address] = value
        end
    end
    
    def memory (clock_cycle, address, value, write_enabled)
        case clock_cycle
        when Clock::A, Clock::C, Clock::E
            return posedge_ace(address)
        when Clock::F
            posedge_f(address, value, write_enabled)
        end
    end
    
    def to_s
        s = ""
        (0...8).each do |i|
            (0...8).each do |j|
                s += "#{@memory[i*8 + j]}, "
            end
            s += "\n"
        end
        return s
    end
    
end

class Registers
    
    # Define constants for common register addresses
    PC  = 0
    PSP = 1
    RSP = 2
    OFR = 3
    
    def initialize
        @registers = [
            0x00,                   # PC  register
            0x30,                   # PSP register
            0x38,                   # RSP register
            0x00,                   # OfR register
            0x00, 0x00, 0x00, 0x00, # Registers Gr0 - Gr3
            0x00, 0x00, 0x00, 0x00, # Registers Gr4 - Gr7
            0x00, 0x00, 0x00, 0x00, # Registers Gr8 - GrB
        ]
        @ssr = 0
    end
    
    def pc
        @registers[PC]
    end
    
    def psp
       @registers[PSP] 
    end
    
    def rsp
        @registers[RSP]
    end
    
    def ofr
        @registers[OFR]
    end
    
    def ssr
        @ssr
    end
    
    def posedge_ace (address)
        @registers[address]
    end
    
    def posedge_b (value)
        @ssr = value == 0 || value == 1 ? value : @ssr
    end
    
    def posedge_df (clock_cycle, address, value, write_enabled, pc_value, pc_write_enabled)
        case clock_cycle
        when Clock::D
            @registers[address] = value
        when Clock::F
            if write_enabled
                @registers[address] = value
            end
            # If we're not already writing to PC with R<, update PC.
            if clock_cycle == 6 && pc_write_enabled && (address != 0 || !write_enabled)
                @registers[PC] = pc_value
            end
        end
    end
    
    def registers (clock_cycle, address, value, ssr_value, write_enabled, pc_value, pc_write_enabled)
        puts "Value: #{ssr_value}, C: #{clock_cycle}"
        case clock_cycle
        when Clock::A, Clock::C, Clock::E
            return posedge_ace(address)
        when Clock::B
            posedge_b(ssr_value)
        when Clock::D, Clock::F
            posedge_df(clock_cycle, address, value, write_enabled, pc_value, pc_write_enabled)
        end
    end
    
    def to_s
        "SSR:       #{@ssr}\n" + 
        "PC:        #{@registers[PC]}\n" +
        "PSP:       #{@registers[PSP]}\n" +
        "RSP:       #{@registers[RSP]}\n" +
        "OfR:       #{@registers[OFR]}\n" +
        "Gr1 - Gr4: #{@registers[(4...8)]}\n" +
        "Gr5 - Gr8: #{@registers[(8...12)]}\n" +
        "Gr9 - GrC: #{@registers[(12...16)]}\n"
    end
    
end

class ALU
    
    attr_reader :result
    
    def compute (op1, op2, alu_control)
        control = 0
        (0...4).each do |bit|
            control += alu_control[bit] * 2**bit
        end
        
        case control
            # 0000
            when 0
                @result = op1 == 0 ? -1 : 0
            # 0001
            when 1
                @result = op1
            # 0010
            when 2
                @result = -op1
            # 0011
            when 3
                @result = ~op1
            # 0100
            when 4
                @result = op2 + op1
            # 0101
            when 5
                @result = op2 - op1
            # 0110
            when 6
                @result = op2 * op1
            # 0111
            when 7
                @result = op2 << op1
            # 1000
            when 8
                @result = op2 >> op1
            # 1001
            when 9
                @result = op2 & op1
            # 1010
            when 10
                @result = op2 | op1
            # 1011
            when 11
                @result = op2 ^ op1
            # 1100
            when 12
                @result = op2 < op1
            # 1101
            when 13
                @result = op2 <= op1
            # 1110
            when 14
                @result = op2 == op1
            # 1111
            when 15
                @result = op2 != op1
        end
    end
    
    def initialize
        @result = 0
    end
    
end

class ControlUnit
    
    # Define instruction name constants
    I_NOP  = 0  #0000 Working!
    I_ALU  = 1  #0001 Working!
    I_JUMP = 3  #0011 Working!
    I_IF   = 2  #0010 Working!
    I_DUP  = 7  #0111 Working!
    I_OVER = 5  #0101 Working!
    I_DROP = 6  #0110 Working!
    I_AT   = 9  #1001 @ Working!
    I_WRT  = 12 #1100 ! Working!
    I_RW   = 14 #1110 R< Working!
    I_RR   = 11 #1011 R> Working!
    I_HALT = 15 #1111 Working!
    
    # Define constants for memory write mux
    MMW_INSTRUCTION = 0
    MMW_OP1 = 1
    MMW_OP2 = 2
    MMW_ALURES = 3
    MMW_ATREAD = 4
    MMW_REGREAD = 5
    
    # Define constants for memory address mux
    MMA_SP = 0
    MMA_OP1 = 1
    
    # Define constants for jump address mux
    MJA_PC  = 0
    MJA_OP1 = 1
    MJA_OP2 = 2
    MJA_HALT = 3
    
    attr_reader :set_ssr                        # Defines if SSR value, either from instruction or SSR itself
    attr_reader :alu_control                    # Defines the 4 bits that is used to select the ALU operation
    attr_reader :sp_change                      # Calculates Δsp
    attr_reader :write_enabled                  # Enables/disables memory write
    attr_reader :mux_memory_data                # Decides where the memory write data should come from
    attr_reader :mux_memory_address             # Decides at what address should data be written to memory
    attr_reader :register_address_read          # Calculates what register should be read
    attr_reader :register_address_write         # Calculates what register should be written to
    attr_reader :register_write_enabled         # Enables/disables register write
    attr_reader :mux_jump_address               # JUMP
    
    def calculate_ssr
        @set_ssr = @instruction[15] == 1 ? @instruction[0] : 2
    end
    
    def calculate_alu_control
        control = 0
        (8...12).each do |bit|
            control += @instruction[bit] * 2**(bit - 8)
        end
        
        @alu_control = 0
        
        unless control = I_ALU
            return
        end
        
        (4...8).each do |bit|
            @alu_control += @instruction[bit] * (2**(bit - 4))
        end
    end
    
    def calculate_sp_change
        control = 0
        (8...12).each do |bit|
            control += @instruction[bit] * 2**(bit - 8)
        end
        
        if @instruction[15] == 0 then
            @sp_change = 1
            return     
        end
        
        case control

            when I_ALU
                if @instruction[6] == 0 && @instruction[7] == 0
                    @sp_change = 0
                else
                    @sp_change = -1
                end
                
            when I_IF, I_WRT
                @sp_change = -2
                
            when I_JUMP, I_DROP, I_RW
                @sp_change = -1
            
            when I_DUP, I_OVER, I_RR
                @sp_change = +1
            
            else
                @sp_change = +0 # @, NOP, HALT
        end
    end
    
    def calculate_write_enabled
        control = 0
        (8...12).each do |bit|
            control += @instruction[bit] * 2**(bit - 8)
        end
        
        if @instruction[15] == 0 
            @write_enabled = true
            return
        end
        
        case control
            when I_ALU, I_OVER, I_DUP, I_AT, I_WRT, I_RR
                @write_enabled = true
            else
                @write_enabled = false
        end
    end
    
    def calculate_mux_memory_data
        
        control = 0
        (8...12).each do |bit|
            control += @instruction[bit] * 2**(bit - 8)
        end
        
        if @instruction[15] == 0 
            @mux_memory_data = MMW_INSTRUCTION
            return
        end
        
        case control
            when I_ALU
                @mux_memory_data = MMW_ALURES
            when I_OVER, I_WRT
                @mux_memory_data = MMW_OP2
            when I_DUP
                @mux_memory_data = MMW_OP1
            when I_AT
                @mux_memory_data = MMW_ATREAD
            when I_RR
                @mux_memory_data = MMW_REGREAD
            else
                @mux_memory_data = MMW_OP1
        end
    end
    
    def calculate_mux_memory_address
        control = 0
        (8...12).each do |bit|
            control += @instruction[bit] * 2**(bit - 8)
        end
        
        if @instruction[15] == 0 
            @mux_memory_address = MMA_SP
            return
        end
        
        unless control == I_WRT
            @mux_memory_address = MMA_SP
        else
            @mux_memory_address = MMA_OP1
        end
        
    end
    
    def calculate_register_address_read
        control = 0
        (8...12).each do |bit|
            control += @instruction[bit] * 2**(bit - 8)
        end
        
        if @instruction[15] == 0 
            @register_address_read = 0
            return
        end
        
        address = 0
        (4...8).each do |bit|
            address += @instruction[bit] * 2**(bit - 4)
        end
        
        unless control == I_RR
            @register_address_read = 0
        else
            @register_address_read = address
        end
    end
    
    def calculate_register_address_write
        control = 0
        (8...12).each do |bit|
            control += @instruction[bit] * 2**(bit - 8)
        end
        
        if @instruction[15] == 0 
            @register_address_write = 0
            return
        end
        
        address = 0
        (4...8).each do |bit|
            address += @instruction[bit] * 2**(bit - 4)
        end
        
        unless control == I_RW
            @register_address_write = 0
        else
            @register_address_write = address
        end
    end
    
    def calculate_register_write_enabled
        control = 0
        (8...12).each do |bit|
            control += @instruction[bit] * 2**(bit - 8)
        end
        
        if @instruction[15] == 0 
            @register_write_enabled = false
            return
        end
        
        unless control == I_RW
            @register_write_enabled = false
        else
            @register_write_enabled = true
        end
    end
    
    def calculate_mux_jump_address
        control = 0
        (8...12).each do |bit|
            control += @instruction[bit] * 2**(bit - 8)
        end
        
        if @instruction[15] == 0 
            @mux_jump_address = MJA_PC
            return
        end
        
        case control
            when I_JUMP
                @mux_jump_address = MJA_OP1
            when I_IF
                @mux_jump_address = MJA_OP2
            when I_HALT
                @mux_jump_address = MJA_HALT
            else
                @mux_jump_address = MJA_PC
        end
        
    end
    
    def initialize
        update(0)
    end
    
    def update (instruction)
        @instruction = instruction
        
        calculate_ssr
        calculate_alu_control
        calculate_sp_change
        calculate_write_enabled
        calculate_mux_memory_data
        calculate_mux_memory_address
        calculate_register_address_read
        calculate_register_address_write
        calculate_register_write_enabled
        calculate_mux_jump_address
    end
    
end

module VirtualMethods
    
    def Instruction_Fetch (address)
        return $memory.memory($clock.cycle, address, 0, 0).first
    end
    
    def Update_SSR (address, value, ssr_value, write_enabled,
                    pc_value = 0, pc_write_enabled = false)
        $registers.registers($clock.cycle, address, value, ssr_value, write_enabled, pc_value, pc_write_enabled)
    end
    
    def Read_Operands (address, value = 0, write_enabled = 0)
        return $memory.memory($clock.cycle, address, value, write_enabled)
    end
    
    def Compute_ALU (op1, op2, alu_control)
        $alu.compute(op1, op2, alu_control)
        return $alu.result
    end
    
    def Read_At (address)
        return $memory.memory($clock.cycle, address, 0, 0).first
    end
    
    def Read_Registers (address, value, ssr_value, write_enabled,
                        pc_value, pc_write_enabled)
        return $registers.registers($clock.cycle, address, value, ssr_value, write_enabled, pc_value, pc_write_enabled)
    end
    
    def Write_Memory (address, value, write_enabled)
        $memory.memory($clock.cycle, address, value, write_enabled)
    end
    
    def Write_Registers (address, value, ssr_value, write_enabled,
                         pc_value, pc_write_enabled)
        $registers.registers($clock.cycle, address, value, ssr_value, write_enabled, pc_value, pc_write_enabled)
    end
    
    def Combinational
        $control_unit.update($w_instruction)
        $w_pc = $registers.pc
        $w_pc_offset = $w_pc+$registers.ofr       
        $w_set_ssr = $control_unit.set_ssr
        $w_alu_control = $control_unit.alu_control
        $w_sp_change = $control_unit.sp_change
        $w_write_enabled = $control_unit.write_enabled
        $w_mux_memory_data = $control_unit.mux_memory_data
        $w_mux_memory_address = $control_unit.mux_memory_address
        $w_register_address_read = $control_unit.register_address_read
        $w_register_address_write = $control_unit.register_address_write
        $w_register_write_enabled = $control_unit.register_write_enabled
        $w_mux_jump_address = $control_unit.mux_jump_address
        $w_stack_read_address = if $registers.ssr == 0 then $registers.psp else $registers.rsp end
        $w_stack_read_address_offset = $w_stack_read_address + $registers.ofr
        $w_sp_regaddr = $registers.ssr == 0 ? Registers::PSP : Registers::RSP
        $w_sp_value = $registers.ssr == 0 ? $registers.psp + $w_sp_change : $registers.rsp + $w_sp_change
        $w_sp_address = $registers.ssr == 0 ? $registers.psp : $registers.rsp
        $w_op1_offset = $w_op1 + $registers.ofr
        $w_memory_write_value = case $w_mux_memory_data
                                when ControlUnit::MMW_INSTRUCTION then $w_instruction
                                when ControlUnit::MMW_OP1         then $w_op1
                                when ControlUnit::MMW_OP2         then $w_op2
                                when ControlUnit::MMW_ALURES      then $w_alu_result
                                when ControlUnit::MMW_ATREAD      then $w_at_data
                                when ControlUnit::MMW_REGREAD     then $w_register_read
                                end
        $w_memory_address_value = case $w_mux_memory_address
                                  when ControlUnit::MMA_SP  then $w_sp_address
                                  when ControlUnit::MMA_OP1 then $w_op1
                                  end
        $w_jump_address = case $w_mux_jump_address
                          when ControlUnit::MJA_PC then $registers.pc + 1
                          when ControlUnit::MJA_OP1 then $w_op1
                          when ControlUnit::MJA_OP2 then $w_op1 == 0 ? $w_op2 : $registers.pc + 1
                          when ControlUnit::MJA_HALT then $registers.pc
                          end                            
        $w_jump_enable = $clock.cycle == 5 || $clock.cycle == 6
        $w_memory_address_value_offset = $w_memory_address_value + $registers.ofr
    end
    
end

include VirtualMethods

def to_ins (value)
    value.gsub("_", "").to_i(2)
end

require './init_memory.rb'
include InitMemory

=begin

$clock = Clock.new
$memory = Memory.new(InitMemory::create_memory_array)
$registers = Registers.new
$control_unit = ControlUnit.new
$alu = ALU.new

puts "", "##### Clock Tests ####"

puts $clock
$clock.next_cycle
$clock.next_cycle
puts $clock, $clock.cycle

puts "##### Memory Unit Tests ####"

$memory.write_memory(48, 27, true)
puts $memory

puts "", "##### Control Unit Tests ####"

puts $control_unit.set_ssr
$control_unit.update(to_ins("1000_0011_0000_0001"))
puts $control_unit.set_ssr

puts "", "##### ALU Tests ####"

puts $alu.result
$alu.compute(1, 2, 4)
puts $alu.result

puts "", "##### Register Tests ####"

puts $registers
#$registers.update_sp(-1, 0)
puts $registers

puts "", "#### END INDIVIDUAL TESTS ####", ""

=end

$clock = Clock.new
$memory = Memory.new(InitMemory::create_memory_array)
$registers = Registers.new
$control_unit = ControlUnit.new
$alu = ALU.new

=begin WIRE DESCRIPTIONS

$w_pc                            # Wire from registers[pc]
$w_pc_offset                     # PC + OfR for relative jumping
$w_instruction                   # Contains instruction read from memory, sends to Control Unit
$w_stack_read_address            # Contains PSP or RSP address, depending on SSR
$w_stack_read_address_offset     # SP + OfR for relative stack reading
$w_op1                           # Op1, top of stack
$w_op1_offset                    # Op1 + OfR
$w_op2                           # Op2, second item of the stack
$w_sp                            # Contains name of the stack to be updated with Δsp
$w_alu_result                    # Contains result of ALU operation
$w_sp_address                    # Contains address of the stack for writing to memory
$w_at_data                       # Contains data read from @ read
$w_register_read                 # Contains data read from register bank, R>
$w_memory_write_value            # What will be written to memory
$w_memory_address_value          # What memory address will data be written to memory
$w_memory_address_value_offset   # Memory address adjusted for relative addressing
$w_jump_address                  # What should PC be updated to (no OfR necessary)
$w_jump_enable                   # Only write to PC on Clock E and F

=end

# Set up 'initial' control unit

$w_instruction = 0
$w_op1 = 0
Combinational()

while true    
    
    ###############################
    ###### Clock A - Read  1 ######
    ###############################
    
    # Sequential stuff
    
    threads = [
        Thread.new{Instruction_Fetch($w_pc_offset)}
    ]
    
    $w_instruction = threads[0].value
    
    # Combinational
    
    Combinational()
    
    $clock.next_cycle
    
    ###############################
    ###### Clock B - Write 1 ######
    ###############################
    
    # Sequential stuff
    
    threads = [
        Thread.new{Update_SSR($w_register_address_write, $w_op1, $w_set_ssr, $w_register_write_enabled,
                              $w_jump_address, $w_jump_enable)}
    ]
    
    threads[0].join
    
    # Combinational
    
    Combinational()
    
    $clock.next_cycle
    
    ###############################
    ###### Clock C - Read  2 ######
    ###############################
    
    # Sequential stuff
    
    threads = [
        Thread.new{Read_Operands($w_stack_read_address_offset)}
    ]
    
    $w_op1, $w_op2 = threads[0].value
    
    # Combinational
    
    Combinational()
    
    $clock.next_cycle
    
    ###############################
    ###### Clock D - Write 2 ######
    ###############################
    
    # Sequential stuff
    
    puts "Supposed to update SP"
    puts "%d %d" % [$w_sp_address, $w_sp_value]
    
    threads = [
        Thread.new{Compute_ALU($w_op1, $w_op2, $w_alu_control)},
        Thread.new{Write_Registers($w_sp_regaddr, $w_sp_value, $w_set_ssr, $w_register_write_enabled,
                                   $w_jump_address, $w_jump_enable)},
    ]
    
    $w_alu_result = threads[0].value
    threads[1].join
    
    # Combinational stuff
    
    Combinational()
    
    $clock.next_cycle
    
    ###############################
    ###### Clock E - Read  3 ######
    ###############################
    
    # Sequential stuff
    
    threads = [
        Thread.new{Read_At($w_op1_offset)},
        Thread.new{Read_Registers($w_register_address_write, $w_op1, $w_set_ssr, $w_register_write_enabled,
                                  $w_jump_address, $w_jump_enable)}
    ]
    
    $w_at_data = threads[0].value
    $w_register_read = threads[1].value
    
    # Combinational stuff
    
    Combinational()
    
    $clock.next_cycle
    
    ###############################
    ###### Clock F - Write 3 ######
    ###############################
    
    # Sequential stuff
    
    threads = [
        Thread.new{Write_Memory($w_memory_address_value_offset, $w_memory_write_value, $w_write_enabled)},
        Thread.new{Write_Registers($w_register_address_write, $w_op1, $w_set_ssr, $w_register_write_enabled,
                                   $w_jump_address, $w_jump_enable)}
    ]
    
    threads.each {|thread| thread.join }
    
    puts $memory
    puts $registers
    
    # Combinational stuff
    
    Combinational()
    
    $clock.next_cycle
    
    gets
end

# puts $a