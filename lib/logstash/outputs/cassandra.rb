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
  
  # Ignore bad message
  config :ignore_bad_messages, :validate => :boolean, :default => false
  
  # Ignore bad values
  config :ignore_bad_values, :validate => :boolean, :default => false
  
  # Batch size
  config :batch_size, :validate => :number, :default => 1

  public
  def register
    require "cassandra"
    @@r = 0

    @statement_cache = {}
    @batch = []
    
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

    if msg.nil? and @ignore_bad_messages
      @logger.warn("Failed to get message from source. Skip it.",
                    :event => event)
      return
    end
    
    convertToCassandraFormat! msg

    @batch.push(msg)

    return if @batch.length < @batch_size
    
    @logger.info("Data to be stored", :msg => msg)
    
    begin
      batch = @session.batch do |b|
        @batch.each do |msg|
          query = "INSERT INTO #{@keyspace}.#{@table} (#{msg.keys.join(', ')})
            VALUES (#{("?"*msg.keys.count).split(//)*", "})"

          @statement_cache[query] = @session.prepare(query) unless @statement_cache.key?(query)
          b.add(@statement_cache[query], msg.values)
        end
      end
      @session.execute(batch,  consistency: :all)
      @batch.clear
      @logger.info "Batch sent"
    rescue => e
      @logger.warn("Failed to send event to Cassandra",
                    :event => event, :exception => e, :backtrace => e.backtrace)
      sleep @retry_delay
      retry
    end
  end # def receive

  private
  def convertToCassandraFormat! msg
    @hints.each do |key, value|
      if msg.key?(key)
        begin
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
        rescue Exception => e
          # Ok, cannot convert the value, let's assign it in default one
          if @ignore_bad_values
            bad_value = msg[key]
            msg[key] = case value
            when 'int'
              0
            when 'uuid'
              Cassandra::Uuid.new("00000000-0000-0000-0000-000000000000")
            when 'timestamp'
              Cassandra::Types::Timestamp.new(Time::parse("1970-01-01 00:00:00"))
            when 'inet'
              Cassandra::Types::Inet.new("0.0.0.0")
            when 'float'
              Cassandra::Types::Float.new(0)
            end
            @logger.warn("Cannot convert `#{key}` value (`#{bad_value}`) to `#{value}` type, set to `#{msg[key]}`",
                         :exception => e, :backtrace => e.backtrace)
          else 
            @logger.fatal("Cannot convert `#{key}` value (`#{msg[key]}`) to `#{value}` type",
                          :exception => e, :backtrace => e.backtrace)
            raise
          end
        end
      end
    end
  end
end # class LogStash::Outputs::Cassandra
