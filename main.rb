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
    
    def read_memory (address)
        [@memory[address], @memory[address - 1]]
    end
    
    def write_memory (address, value, write_enabled)
        puts "Write_memory, address: #{address}"
        if write_enabled
            @memory[address] = value
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
    
    def read_register (address)
        @registers[address]
    end
    
    def write_register (address, value, write_enabled, pc_value, pc_write_enabled)
        if write_enabled
            @registers[address] = value            
        end
        # Only on clock F
        if pc_write_enabled && (address != 0 || !write_enabled)
            @registers[PC] = pc_value
        end
    end
    
    def update_sp (Δ, sp)
        @registers[sp] += Δ
    end
    
    def ssr= (value)
        @ssr = value == 0 || value == 1 ? value : @ssr
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
        puts "Computing #{op2} #{control} #{op1}"
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
        puts @result
    end
    
    def initialize
        @result = 0
    end
    
end

class ControlUnit
    
    # Define instruction name constants
    I_NOP  = 0  #0000 Not working/not implemented
    I_ALU  = 1  #0001 Working!
    I_JUMP = 3  #0011 Working!
    I_IF   = 2  #0010 Working!
    I_DUP  = 7  #0111 Working!
    I_OVER = 5  #0101 Working!
    I_DROP = 6  #0110 Working!
    I_AT   = 9  #1001 @ Working!
    I_WRT  = 12 #1100 ! Working!
    I_RW   = 14 #1110 R< Not working/not implemented
    I_RR   = 11 #1011 R> Not working/not implemented
    I_HALT = 15 #1111 Not working/not implemented
    
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
    
    attr_reader :set_ssr
    attr_reader :alu_control
    attr_reader :sp_change
    attr_reader :write_enabled
    attr_reader :register_address_read
    attr_reader :mux_memory_data
    attr_reader :mux_memory_address
    attr_reader :register_address_write
    attr_reader :register_write_enabled
    attr_reader :mux_jump_address
    
    def calculate_ssr
        @set_ssr = @instruction[15] == 1 ? @instruction[0] : $registers.ssr
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
            when I_ALU, I_OVER, I_DUP, I_AT, I_WRT
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
        
        puts "MMD: %b" % control
        
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
            @register_address_write = false
            return
        end
        
        unless control == I_RW
            @register_address_write = false
        else
            @register_address_write = true
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
        calculate_register_address_write
        calculate_register_write_enabled
        calculate_mux_jump_address
    end
    
end

module VirtualMethods
    
    def Instruction_Fetch
        return $memory.read_memory($registers.pc).first
    end
    
    def Update_SSR (value)
        $registers.ssr = value
    end
    
    def Read_Operands (address)
        return $memory.read_memory(address)
    end
    
    def Compute_ALU (op1, op2, alu_control)
        $alu.compute(op1, op2, alu_control)
        return $alu.result
    end
    
    def Update_SP (sp_change, sp)
        $registers.update_sp(sp_change, sp)
    end
    
    def Read_At (address)
        return $memory.read_memory(address).first
    end
    
    def Read_Registers (address)
        return $registers.read_register(address)
    end
    
    def Write_Memory (address, value, write_enabled)
        puts "Virtual address: #{address}"
        $memory.write_memory(address, value, write_enabled)
    end
    
    def Write_Registers (address, value, write_enabled,
                         pc_value = 0, pc_write_enabled = false)
        puts "WR: #{pc_value}, #{pc_write_enabled}"
        $registers.write_register(address, value, write_enabled, pc_value, pc_write_enabled)
    end
    
end

include VirtualMethods

def to_ins (value)
    value.gsub("_", "").to_i(2)
end

require '.\init_memory.rb'
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

while true

    ###############################
    ###### Clock A - Read  1 ######
    ###############################
    
    # Sequential stuff
    
    threads = [
        Thread.new{Instruction_Fetch()}
    ]
    
    w_instruction = threads[0].value
    puts "PC: #{$registers.pc}"
    puts "w_instruction: #{w_instruction}"
    
    # Combinational

    $control_unit.update(w_instruction)
    w_SSR = $control_unit.set_ssr
    w_alu_control = $control_unit.alu_control
    w_sp_change = $control_unit.sp_change
    w_write_enabled = $control_unit.write_enabled
    w_mux_memory_data = $control_unit.mux_memory_data
    w_mux_memory_address = $control_unit.mux_memory_address
    w_register_address_write = $control_unit.register_address_write
    w_register_write_enabled = $control_unit.register_write_enabled
    w_mux_jump_address = $control_unit.mux_jump_address
    
    puts "v Look v", w_sp_change
    
    $clock.next_cycle
    
    ###############################
    ###### Clock B - Write 1 ######
    ###############################
    
    # Sequential stuff
    
    threads = [
        Thread.new{Update_SSR(w_SSR)}
    ]
    
    # Combinational
    
    w_address = if $registers.ssr == 0 then $registers.psp else $registers.rsp end
    
    $clock.next_cycle
    
    ###############################
    ###### Clock C - Read  2 ######
    ###############################
    
    # Sequential stuff
    
    threads = [
        Thread.new{Read_Operands(w_address)}
    ]
    
    w_op1, w_op2 = threads[0].value
    puts "OP1: #{w_op1}, OP2: #{w_op2}"
    
    # Combinational
    
    w_sp = $registers.ssr == 0 ? Registers::PSP : Registers::RSP
    
    $clock.next_cycle
    
    ###############################
    ###### Clock D - Write 2 ######
    ###############################
    
    # Sequential stuff
    
    threads = [
        Thread.new{Compute_ALU(w_op1, w_op2, w_alu_control)},
        Thread.new{Update_SP(w_sp_change, w_sp)}
    ]
    
    w_alu_result = threads[0].value
    threads[1].join
    
    # Combinational stuff
    
    w_sp_address = $registers.ssr == 0 ? $registers.psp : $registers.rsp
    
    $clock.next_cycle
    
    ###############################
    ###### Clock E - Read  3 ######
    ###############################
    
    # Sequential stuff
    
    threads = [
        Thread.new{Read_At(w_op1)},
        Thread.new{Read_Registers(0)}
    ]
    
    w_at_data = threads[0].value
    w_register_read = threads[1].value
    
    # Combinational stuff
    
    w_memory_write_value = case w_mux_memory_data
                           when ControlUnit::MMW_INSTRUCTION then w_instruction
                           when ControlUnit::MMW_OP1         then w_op1
                           when ControlUnit::MMW_OP2         then w_op2
                           when ControlUnit::MMW_ALURES      then w_alu_result
                           when ControlUnit::MMW_ATREAD      then w_at_data
                           when ControlUnit::MMW_REGREAD     then w_register_read
                           end
    
    w_memory_address_value = case w_mux_memory_address
                             when ControlUnit::MMA_SP  then w_sp_address
                             when ControlUnit::MMA_OP1 then w_op1
                             end
    
    w_jump_address = case w_mux_jump_address
                     when ControlUnit::MJA_PC then $registers.pc + 1
                     when ControlUnit::MJA_OP1 then w_op1
                     when ControlUnit::MJA_OP2 then w_op1 == 0 ? w_op2 : $registers.pc + 1
                     end
    
    w_jump_enable = $clock.cycle == 5 || $clock.cycle == 6
    
    $clock.next_cycle
    
    puts "WRITEME: #{w_mux_memory_data}"
    
    ###############################
    ###### Clock F - Write 3 ######
    ###############################
    
    # Sequential stuff
    
    puts $memory
    
    threads = [
        Thread.new{Write_Memory(w_memory_address_value, w_memory_write_value, w_write_enabled)},
        Thread.new{Write_Registers(w_register_address_write, w_op1, w_register_write_enabled,
                                   w_jump_address, w_jump_enable)}
    ]
    
    threads.each {|thread| thread.join }
    
    puts $memory
    puts $registers
    
    # Combinational stuff
    
    $clock.next_cycle
    
    gets
end

# puts $a