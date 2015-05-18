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

  # Set max retry for each batch
  config :max_retries, :validate => :number, :default => 3
  
  # Ignore bad message
  config :ignore_bad_messages, :validate => :boolean, :default => false
  
  # Ignore bad values
  config :ignore_bad_values, :validate => :boolean, :default => false
  
  # Batch size
  config :batch_size, :validate => :number, :default => 1

  # Batch batch processor tic (sec)
  config :batch_processor_thread_period, :validate => :number, :default => 1

  public
  def register
    require "thread"
    require "cassandra"
    @@r = 0

    # Messages collector. When @batch_msg_queue.length > batch_size
    # batch_size of messages are sent to Cassandra
    @batch_msg_queue = Queue.new

    # Failed batches collector. Every retry_delay secs batches from the queue
    # are pushed to Cassandra. If a try is failed a batch.try_count is incremented.
    # If batch.try_count > max_retries, the batch is rejected
    # with error message in error log
    @failed_batch_queue = Queue.new

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

    @batch_processor_thread = Thread.new do
      loop do
        stop_it = Thread.current["stop_it"]
        sleep(@batch_processor_thread_period)
        send_batch2cassandra stop_it
        return if stop_it
      end
    end

    @failed_batch_processor_thread = Thread.new do
      loop do
        stop_it = Thread.current["stop_it"]
        sleep(@retry_delay)
        resend_batch2cassandra
        return if stop_it
      end
    end
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
      msg.reject!{|key| %r{^@} =~ key}
    end

    if msg.nil? and @ignore_bad_messages
      @logger.warn("Failed to get message from source. Skip it.",
                    :event => event)
      return
    end
    
    convert2cassandra_format! msg

    @batch_msg_queue.push(msg)
    @logger.info("Queue message to be sent")
  end # def receive

  private
  def send_batch2cassandra stop_it = false
    loop do
      return if @batch_msg_queue.length < @batch_size and !stop_it
      begin
        batch = prepare_batch
        return if batch.nil?
        @session.execute(batch,  consistency: :all)
        batch.clear
        @logger.info "Batch sent successfully"
      rescue => e
        @logger.warn "Fail to send batch. Schedule it to send later."
        @failed_batch_queue.push({:batch => batch, :try_count => 0})
      end
    end
  end

  private
  def prepare_batch()
    statement_and_values = []
    while statement_and_values.length < @batch_size and !@batch_msg_queue.empty?
      msg = @batch_msg_queue.pop
      query = "INSERT INTO #{@keyspace}.#{@table} (#{msg.keys.join(', ')})
        VALUES (#{("?"*msg.keys.count).split(//)*", "})"

      @statement_cache[query] = @session.prepare(query) unless @statement_cache.key?(query)
      statement_and_values << [@statement_cache[query], msg.values]
    end
    return nil if statement_and_values.empty?

    batch = @session.batch do |b|
      statement_and_values.each do |v|
        b.add(v[0], [1])
      end
    end
    return batch
  end

  private
  def resend_batch2cassandra
    while !@failed_batch_queue.empty?
      batch_container = @failed_batch_queue.pop
      batch = batch_container[:batch]
      count = batch_container[:try_count]
      begin
        @session.execute(batch,  consistency: :all)
        batch.clear
        @logger.info "Batch sent"
      rescue => e
        if count > @max_retries
          @logger.fatal("Failed to send batch to Cassandra in #{@max_retries} tries",
            :batch => batch)
        else
          @failed_batch_queue.push({:batch => batch, :try_count => count + 1})
          @logger.warn("Failed to send batch again. Reschedule it.")
        end
      end
      sleep(@retry_delay)
    end
  end

  public
  def teardown
    @batch_processor_thread["stop_it"] = true
    @batch_processor_thread.join

    @failed_batch_processor_thread["stop_it"] = true
    @failed_batch_processor_thread.join
  end

  private
  def convert2cassandra_format! msg
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
