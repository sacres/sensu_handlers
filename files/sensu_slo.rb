#!/usr/bin/env ruby
#
# Sensu Handler: sensu_slo
#
# This handler calculate the age of a check by subtracting the execution
# time of the check with the current time on the Sensu server. This can
# be used to monitor check latency and also, by evaluating the interval
# time, used to give and idea of the number of succesfull checks
# navigating Sensu's message bus.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-handler'

$env_dir = "/nail/etc/"
$default_dims_files = [
  "runtimeenv",
  "ecosystem",
  "region",
  "habitat"
]

class SensuSLOHandler < Sensu::Handler

  def handle

    metric_name = settings['sensu_slo']['metric_name'] || 'sensu.check_age"'

    statsite_host = settings['sensu_slo']['statsite_host'] || '127.0.0.1'
    statsite_port = settings['sensu_slo']['statsite_port'] || 8125

    # Extract the name of the check and the client which ran it
    if @event["check"] != nil
      check_name = @event["check"]["name"]
      if check_name == nil
        STDERR.puts "Check result did not have a 'name'\n"
        return
      end
      
      client_name = @event["client"]["name"]
      if client_name == nil
        STDERR.puts "Check result did not have a 'client name'\n"
        return
      end
    else
      STDERR.puts "Check result does not appear to contain check data\n"
      return
    end

    # Calculate how long ago the check was executed
    now = Time.now.to_i
    executed = @event["check"]["executed"].to_i
    if executed == nil
      STDERR.puts "Check result does not have an 'executed' field\n"
      return
    end
    age = now - executed

    # Create an array to hold the metric Dimensions
    dims = Array.new
    dims << ["metric_name", metric_name]

    # Add default environment Dimensions
    $default_dims_files.each do |f|
      begin
        dims << [f, File.read($env_dir + "/" + f)]
      rescue Errno::ENOENT
        STDERR.puts "Could not read #{f}\n"
      rescue => e
        STDERR.puts "An unknown error occured: #{e}\n"
      end
    end

    # Add the check specific dimensions
    dims << ["check_name", check_name]
    dims << ["client_name", client_name]

    # Format the output string and send to statsite
    statsite_msg = "#{dims.to_json}:#{age}|g"

    statsite = UDPSocket.new
    n = statsite.send statsite_msg, 0, $statsite_host, $statsite_port

    STDERR.puts "Zero bytes sent to #{statsite_host}:#{statsite_port}. Msg: #{statsite_msg}\n" if n < 1
    STDOUT.puts "#{n} bytes sent to statsite\n"

  end

end
