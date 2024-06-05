require 'openssl'
require 'faraday'

require 'async'
require 'async/semaphore'
require 'async/barrier'
require 'async/waiter'

require 'benchmark'
require 'pry'

OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE

# Есть три типа эндпоинтов API
# Тип A:
#   - работает 1 секунду
#   - одновременно можно запускать не более трёх
# Тип B:
#   - работает 2 секунды
#   - одновременно можно запускать не более двух
# Тип C:
#   - работает 1 секунду
#   - одновременно можно запускать не более одного
#
def a(value)
  puts "https://localhost:9292/a?value=#{value}"
  Async { Faraday.get("https://localhost:9292/a?value=#{value}").body }
end

def b(value)
  puts "https://localhost:9292/b?value=#{value}"
  Async { Faraday.get("https://localhost:9292/b?value=#{value}").body }
end

def c(value)
  puts "https://localhost:9292/c?value=#{value}"
  Async { Faraday.get("https://localhost:9292/c?value=#{value}").body }
end

# Референсное решение, приведённое ниже работает правильно, занимает ~19.5 секунд
# Надо сделать в пределах 7 секунд

def collect_sorted(arr)
  arr.sort.join('-')
end

start = Time.now

a11, a12, a13,
a21, a22, a23,
a31, a32, a33,
b1, b2, b3,
ab1, ab2, ab3,
c1, c2, c3,
result = nil

a_barrier = Async::Barrier.new
b_barrier = Async::Barrier.new
c_barrier = Async::Barrier.new

Async do
  Async do
    a11, a12, a13 = [a(11), a(12), a(13)].map do |task|
      a_barrier.async do
        task.wait
      end
    end

    b1, b2 = [b(1), b(2)].map do |task|
      b_barrier.async do
        task.wait
      end
    end

    a_barrier.wait
    a21, a22, a23 = [a(21), a(22), a(23)].map do |task|
      a_barrier.async do
        task.wait
      end
    end

    b_barrier.wait
    b_barrier.async do
      b3 = b(3).wait
    end
    ab1 = "#{collect_sorted([a11.wait, a12.wait, a13.wait])}-#{b1.wait}"

    c_barrier.async do
      c1 = c(ab1).wait
    end

    a_barrier.wait
    a31, a32, a33 = [a(31), a(32), a(33)].map do |task|
      a_barrier.async do
        task.wait
      end
    end
    ab2 = "#{collect_sorted([a21.wait, a22.wait, a23.wait])}-#{b2.wait}"

    c_barrier.wait
    c_barrier.async do
      c2 = c(ab2).wait
    end

    a_barrier.wait
    b_barrier.wait
    ab3 = "#{collect_sorted([a31.wait, a32.wait, a33.wait])}-#{b3}"

    c_barrier.wait
    c_barrier.async do
      c3 = c(ab3).wait
    end

    c_barrier.wait
    c123 = collect_sorted([c1, c2, c3])
    result = a(c123).wait
  end
end

puts "FINISHED in #{Time.now - start}s."
puts "RESULT = #{result}" # 0bbe9ecf251ef4131dd43e1600742cfb
