require './init_memory.rb'
include InitMemory

array = InitMemory::create_memory_array

list_file = open('./mem.list', 'w')

array.each do |instruction|
    list_file.write("%016b\n" % instruction)
end

list_file.close
