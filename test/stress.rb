# frozen_string_literal: true

count = ARGV[0] ? ARGV[0].to_i : 100
test_name = ARGV[1]

$test_cmd = +'ruby test/run.rb --verbose'
if test_name
  $test_cmd << " --name #{test_name}"
end

puts '*' * 40
puts
puts $test_cmd
puts

def run_test(count)
  puts "#{count}: running tests..."
  # sleep 1
  system($test_cmd)
  puts

  return if $?.exitstatus == 0

  puts "Failure after #{count} tests"
  exit!
end

trap('INT') { exit! }
t0 = Time.now
count.times do |i|
  run_test(i + 1)
end
elapsed = Time.now - t0
puts format(
  "Successfully ran %d tests in %f seconds (%f per test)",
  count,
  elapsed,
  elapsed / count
)