# encoding: utf-8
require "logstash/outputs/base"
require "logstash/namespace"
require "time"


class LogStash::Outputs::Cassandra < LogStash::Outputs::Base
  
  milestone 1

  config_name "cassandra"

  # Cassandra server hostname or IP-address
  config :hosts, :validate => :string, :required => true
  
  # The keyspace to use
  config :keyspace, :validate => :string, :required => true

  # The table to use
  config :table, :validate => :string, :required => true
   
  # Username
  config :username, :validate => :string, :required => true

  # Password
  config :password, :validate => :string, :required => true

  # Source
  config :source, :validate => :string, :default => nil
  
  # Hints
  config :hints, :validate => :hash, :default => {}

  # Number of seconds to wait after failure before retrying
  config :retry_delay, :validate => :number, :default => 3, :required => false
  
  public
  def register
    require "cassandra"
    
    cluster = Cassandra.cluster(
      username: @username,
      password: @password,
      hosts: @hosts
    )
    
    @session  = cluster.connect(@keyspace)
    
    @logger.info("New Cassandra output", :username => @username,
                :hosts => @hosts, :keyspace => @keyspace, :table => @table)
  end # def register

  public
  def receive(event)
    return unless output?(event)

    if @source
      msg = event[@source]
    else
      msg = event.to_hash
      # Filter out @timestamp, @version, etc
      # to be able to use elasticsearch input plugin directly
      msg.reject!{|key, value| %r{^@} =~ key}
    end
    
    # convert values to Cassandra format
    @hints.each do |key, value|
      if msg.key?(key)
        msg[key] = case value
        when 'int'
          msg[key].to_i
        when 'uuid'
          Cassandra::Types::Uuid.new(msg[key])
        when 'timestamp'
          Cassandra::Types::Timestamp.new(Time::parse(msg[key]))
        when 'inet'
          Cassandra::Types::Inet.new(msg[key])
        when 'float'
          Cassandra::Types::Float.new(msg[key])
        end
      end
    end
    
    @logger.info("Data to be stored", :msg => msg)
    
    begin
      statement = @session.prepare(
        "INSERT INTO #{@keyspace}.#{@table} (#{msg.keys.join(', ')})
        VALUES (#{("?"*msg.keys.count).split(//)*", "})")
      @session.execute(
        statement, :arguments => msg.values
      )
    rescue => e
      @logger.warn("Failed to send event to Cassandra",
                    :event => event, :exception => e, :backtrace => e.backtrace)
      sleep @retry_delay
      retry
    end
  end # def receive
end # class LogStash::Outputs::Cassandra
