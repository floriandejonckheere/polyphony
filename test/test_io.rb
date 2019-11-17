# frozen_string_literal: true

require_relative 'helper'

class GyroIOTest < MiniTest::Test
  def test_that_reading_works
    i, o = IO.pipe
    data = +''
    w = Gyro::IO.new(i, :r)
    w.start do
      i.read_nonblock(8192, data)
      w.stop unless data.empty?
    end
    defer { o << 'hello' }
    suspend
    assert_equal('hello', data)
  end
end

class IOTest < MiniTest::Test
  def setup
    @i, @o = IO.pipe
  end

  def test_that_io_op_yields_to_other_fibers
    count = 0
    msg = nil
    [
      spin {
        @o.write("hello")
        @o.close
      },

      spin {
        while count < 5
          sleep 0.01
          count += 1
        end
      }, 

      spin {
        msg = @i.read
      }
    ].each(&:await)
    assert_equal(5, count)
    assert_equal("hello", msg)
  end

  def test_that_double_chevron_method_returns_io
    assert_equal(@o, @o << 'foo')

    @o << 'bar' << 'baz'
    @o.close
    assert_equal('foobarbaz', @i.read)
  end
end

class IOClassMethodsTest < MiniTest::Test
  def test_binread
    s = IO.binread(__FILE__)
    assert_kind_of(String, s)
    assert(!s.empty?)
    assert_equal(IO.orig_binread(__FILE__), s)

    s = IO.binread(__FILE__, 100)
    assert_equal(100, s.bytesize)
    assert_equal(IO.orig_binread(__FILE__, 100), s)

    s = IO.binread(__FILE__, 100, 2)
    assert_equal(100, s.bytesize)
    assert_equal('frozen', s[0..5])
  end

  BIN_DATA = "\x00\x01\x02\x03"

  def test_binwrite
    fn = '/tmp/test_binwrite'
    FileUtils.rm(fn) rescue nil

    len = IO.binwrite(fn, BIN_DATA)
    assert_equal(4, len)
    s = IO.binread(fn)
    assert_equal(BIN_DATA, s)
  end

  def test_foreach
    lines = []
    IO.foreach(__FILE__) { |l| lines << l }
    assert_equal("# frozen_string_literal: true\n", lines[0])
    assert_equal("end", lines[-1])
  end

  def test_read
    s = IO.read(__FILE__)
    assert_kind_of(String, s)
    assert(!s.empty?)
    assert_equal(IO.orig_read(__FILE__), s)

    s = IO.read(__FILE__, 100)
    assert_equal(100, s.bytesize)
    assert_equal(IO.orig_read(__FILE__, 100), s)

    s = IO.read(__FILE__, 100, 2)
    assert_equal(100, s.bytesize)
    assert_equal('frozen', s[0..5])
  end

  def test_readlines
    lines = IO.readlines(__FILE__)
    assert_equal("# frozen_string_literal: true\n", lines[0])
    assert_equal("end", lines[-1])
  end

  WRITE_DATA = "foo\nbar קוקו"

  def test_write
    fn = '/tmp/test_write'
    FileUtils.rm(fn) rescue nil

    len = IO.write(fn, WRITE_DATA)
    assert_equal(WRITE_DATA.bytesize, len)
    s = IO.read(fn)
    assert_equal(WRITE_DATA, s)
  end

  def test_popen
    counter = 0
    timer = spin {
      throttled_loop(200) { counter += 1 }
    }

    IO.popen('sleep 0.01') { |io| io.read }
    assert(counter >= 2)

    result = nil
    IO.popen('echo "foo"') { |io| result = io.read }
    assert_equal("foo\n", result)
  ensure
    timer&.stop
  end

  def test_kernel_gets
    counter = 0
    timer = spin {
      throttled_loop(200) { counter += 1}
    }

    i, o = IO.pipe
    orig_stdin = $stdin
    $stdin = i
    spin {
      sleep 0.01
      o.puts "foo"
      o.close
    }

    assert(counter >= 0)
    assert_equal("foo\n", gets)
  ensure
    $stdin = orig_stdin
    timer&.stop
  end

  def test_kernel_gets_with_argv
    ARGV << __FILE__

    s = StringIO.new(IO.orig_read(__FILE__))

    while (l = s.gets)
      assert_equal(l, gets)
    end
  ensure
    ARGV.delete __FILE__
  end

  def test_kernel_puts
    orig_stdout = $stdout
    o = eg(
      '@buf': +'',
      write: ->(*args) { args.each { |a| @buf << a } },
      flush: -> { },
      buf: -> { @buf }
    )

    $stdout = o

    puts("foobar")
    assert_equal("foobar\n", o.buf)
  ensure
    $stdout = orig_stdout
  end
end