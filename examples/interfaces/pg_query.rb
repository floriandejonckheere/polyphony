# frozen_string_literal: true

require 'modulation'

Rubato = import('../../lib/rubato')
Postgres =  import('../../lib/rubato/extensions/postgres')

DB = PG.connect(
  host:     '/tmp',
  user:     'reality',
  password: nil,
  dbname:   'reality',
  sslmode:  'require'
)

def perform(error)
  puts "*" * 40
  DB.transaction do
    res = DB.query("select 1 as test")
    puts "result: #{res.to_a}"
    raise 'hello' if error
    DB.transaction do
      res = DB.query("select 2 as test")
      puts "result: #{res.to_a}"
    end
  end
rescue => e
  puts "error: #{e.inspect}"
end

spawn do
  perform(true)
  perform(false)
end
