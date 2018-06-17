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
        input_string = input_string.gsub(/\-([0-9]+) /, 
                                        '\1 NEGATE ')
        
        puts input_string
        
        # Tokenize and remove END
        tokens = input_string.split()
        tokens.pop()
        
        # Convert tokens into instructions
        instructions = convert(tokens)
        
    end
    
    def convert (tokens)
        
        instructions = []
        last_stack = CrSymbols::REGISTERS['PSP']
        
        tokens.each do |token|
            
            # Check if token defines SSR register
            begin
                if token == 'PSP' || token == 'RSP'
                    last_stack = CrSymbols::REGISTERS[token]
                    next
                end
            end
            
            # Check if token fits instructions hash
            begin
                if CrSymbols::REGISTERS.key?()
            end
            
            # Try converting an immediate value (push operation)
            begin
                number = Integer(token)
                instruction = number_to_instruction(number) 
                instructions.push(instruction)
                next # Processing done, go to next token
            rescue ArgumentError
            end
            
            
            
            instructions.push(token)
        end
        
        puts "", instructions
        
    end
    
    def number_to_instruction (int)
        int = "%016b" % int
        int.insert(12, '_')
        int.insert(8, '_')
        int.insert(4, '_')
        return int
    end
    
end

include InitMemory

InitMemory::create_memory_array