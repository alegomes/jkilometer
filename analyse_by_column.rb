input=ARGV[0]
field=ARGV[1].to_i

if ARGV.length == 1
  puts 
  puts "Usage: analyse_by_column <summary_results.csv> <column_number>"
  puts
  exit
end

last_line_was_comment=false
last_line_was_data=false

input_file = File.open(input, "r")

description=""
timestamp=""
data=""

puts "Timestamp;Description;Column #{field} data serie"
input_file.each do |line| 

  line.chomp!

  # Comment
  if /#.*$/ =~ line
    if last_line_was_data
      puts "#{timestamp};\"#{description}\";#{data}" 
      description=""
      timestamp=""
      data=""
    end

    if /#[\s]+(.+)$/ =~ line
      description=$1
    end

    last_line_was_comment=true
    last_line_was_data=false
  end

  # Data
  if /[\d]{2}\/[\d]{2}\/[\d]{4}.*$/ =~ line

    line = line.split(";")

    if last_line_was_comment
      timestamp=line[0]
      data=line[field]
    else
#      puts "line=#{line} line.size=#{line.size} data=#{data} line[#{field}]=#{line[field]}"
      data=data+";"+line[field]
    end

    last_line_was_comment=false
    last_line_was_data=true

  end

end

# ultima linha
puts "#{timestamp};\"#{description}\";#{data}"
