Currently this repository is abandoned, better maintenance you can get [here](https://github.com/eladamitpxi/logstash-output-cassandra/).

# Logstash Cassandra Output Plugin

This is a plugin for [Logstash](https://github.com/elasticsearch/logstash).

It is fully free and fully open source. The license is Apache 2.0, meaning you are pretty much free to use it however you want in whatever way.

## Usage

<pre><code>
output {
    cassandra {
        # Credentials of a target Cassandra, keyspace and table
        # where you want to stream data to.
        username => "cassandra"
        password => "cassandra"
        hosts => ["127.0.0.1"]
        keyspace => "logs"
        table => "query_log"
        # Cassandra consistency level.
        # Options: "any", "one", "two", "three", "quorum", "all",
        #    "local_quorum", "each_quorum", "serial", "local_serial",
        #    "local_one"
        # Default: "one"
        consistency => "all"
        
        # Where from the event hash to take a message
        source => "payload"
        
        # if cassandra does not understand formats of data
        # you feeds it with, just provide some hints here
        hints => {
            id => "int"
            at => "timestamp"
            resellerId => "int"
            errno => "int"
            duration => "float"
            ip => "inet"}
            
        # Sometimes it's usefull to ignore malformed messages
        # (e.x. source contains nothing),
        # in the case set ignore_bad_messages to True.
        # By default it is False
        ignore_bad_messages => true
        
        # Sometimes it's usefull to ignore problems with a convertation
        # of a received value to Cassandra format and set some default
        # value (inet: 0.0.0.0, float: 0.0, int: 0,
        # uuid: 00000000-0000-0000-0000-000000000000,
        # timestamp: 1970-01-01 00:00:00) in the case set
        # ignore_bad_messages to True.
        # By default it is False
        ignore_bad_values => true
        
        # Datastax cassandra driver supports batch insert.
        # You can define the batch size explicitely.
        # By default it is 1.
        batch_size => 100
        
        # Every batch_processor_thread_period sec. a special thread
        # pushes all collected messages to Cassandra. By default it is 1 (sec.)
        batch_processor_thread_period => 1
        
        # max max_retries times the plugin will push failed batches
        # to Cassandra before give up. By defult it is 3.
        max_retries => 3
        
        # retry_delay secs. between two sequential tries to push a failed batch
        # to Cassandra. By default it is 3 (secs.)
        retry_delay => 3
    }
}
</code></pre>

## Running Plugin in Logstash
### Run in a local Logstash clone

Edit Logstash Gemfile and add the local plugin path, for example:
```
gem "logstash-output-cassandra", :path => "/your/local/logstash-output-cassandra"
```

Install plugin
```
bin/plugin install --no-verify
```
Run Logstash with the plugin
```
bin/logstash -e 'output {cassandra {}}'
```

### Run in an installed Logstash

You can use the same method to run your plugin in an installed Logstash by editing its Gemfile and pointing the :path to your local plugin development directory or you can build the gem and install it using:

Build your plugin gem
```
gem build logstash-output-cassandra.gemspec
```
Install the plugin from the Logstash home
```
bin/plugin install /your/local/plugin/logstash-output-cassandra.gem
```
Run Logstash with the plugin
```
bin/logstash -e 'output {cassandra {}}'
```

## TODO

