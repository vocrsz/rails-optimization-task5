require 'openssl'
require 'faraday'
require 'async'

OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE

ARGV[1].to_i.times.map do
  Thread.new do
    puts "https://localhost:9292/#{ARGV[0]}?value=ping"
    Faraday.get("https://localhost:9292/#{ARGV[0]}?value=ping") do |req|
      req.options.open_timeout = 3
      req.options.timeout = 3
    end
  end
end.each(&:join)
