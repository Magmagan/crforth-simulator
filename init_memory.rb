module InitMemory
    
    require '.\crsymbols.rb'
    
    def create_memory_array
        puts "END to end."
        
        # Get instructions from user input
        input_string = ""
        while !input_string.include?('END')
            input_string += ' ' + $stdin.gets.chomp
        end
        
        # Before tokenizing, convert all numbers of form -n to
        # NEGATE PUSH n
        input_string = input_string.gsub(/\-([0-9]+) /, '\1 NEGATE ')
        
        puts input_string
        
        # Tokenize and remove END
        tokens = input_string.split()
        tokens.pop()
        
        # Convert tokens into instructions
        instructions = convert(tokens)
        
        # Convert instructions to integers and resize array to 256.
        instructions.map! {|i| CrSymbols.to_ins(i)}
        instructions.fill(0, instructions.length...256)
        
        return instructions
    end
    
    def convert (tokens)
        
        instructions = []
        last_stack = CrSymbols::REGISTERS['PSP']
        
        tokens.each do |token|
            
            # Check if token fits ALU hash
            begin
                if CrSymbols::ALU_OPERATIONS.key?(token)
                    instruction = CrSymbols::INSTRUCTIONS['ALU'] + ""
                    instruction = format(instruction, last_stack, token)
                    instructions.push(instruction)
                    next
                end
            end
            
            # Check if token is a register operation R>
            begin
                if token.include?('>') && CrSymbols::REGISTERS.key?(token.sub!(/>/, ''))
                    instruction = CrSymbols::INSTRUCTIONS['R>'] + ""
                    instruction = format(instruction, last_stack, token)
                    instructions.push(instruction)
                    next
                end
            end
            
            # Check if token is a register operation R<
            begin
                if token.include?('<') && CrSymbols::REGISTERS.key?(token.sub!(/</, ''))
                    instruction = CrSymbols::INSTRUCTIONS['R>'] + ""
                    instruction = format(instruction, last_stack, token)
                    instructions.push(instruction)
                    next
                end
            end
            
            # Check if token defines SSR register
            begin
                if token == 'PSP' || token == 'RSP'
                    last_stack = CrSymbols::REGISTERS[token]
                    next
                end
            end
            
            # Check if token fits instructions hash
            begin
                if CrSymbols::INSTRUCTIONS.key?(token)
                    instruction = CrSymbols::INSTRUCTIONS[token] + ""
                    instruction = format(instruction, last_stack)
                    instructions.push(instruction)
                    next
                end
            end
            
            # Try converting an immediate value (push operation)
            begin
                number = Integer(token)
                instruction = number_to_instruction(number) 
                instructions.push(instruction)
                next # Processing done, go to next token
            rescue ArgumentError
            end
            
            # None of the cases: fail
            puts 'Error:' + token
        end
        
        return instructions
    end
    
    def number_to_instruction (int)
        int = "%016b" % int
        int.insert(12, '_')
        int.insert(8, '_')
        int.insert(4, '_')
        return int
    end
    
    def format (instruction, sp, argument = '')
        stack_pointer = sp == CrSymbols::REGISTERS['PSP'] ? 0 :
                        sp == CrSymbols::REGISTERS['RSP'] ? 1 : 0;
        
        unless argument == ''
            if CrSymbols::ALU_OPERATIONS.key?(argument)
                instruction['AAAA'] = CrSymbols::ALU_OPERATIONS[argument]
            end
            if CrSymbols::REGISTERS.key?(argument)
                instruction['RRRR'] = CrSymbols::REGISTERS[argument]
            end
            
        end
        
        instruction['S'] = stack_pointer.to_s
        return instruction
    end
    
end

include InitMemory

InitMemory::create_memory_array