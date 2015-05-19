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

## Installation instructions
For CentOS 6.6, logstash-1.4.2-1_2c0f5a1.noarch
<pre><code>
git clone https://github.com/otokarev/logstash-output-cassandra.git \
&& cd logstash-output-cassandra.git \
&& gem build logstash-output-cassandra.gemspec \
&& env GEM_HOME=/opt/logstash/vendor/bundle/jruby/1.9/ GEM_PATH="" \
&& java -jar /opt/logstash/vendor/jar/jru^C-complete-1.7.11.jar -S \
&& gem install logstash-output-cassandra-0.1.0.gem
</code></pre>

## TODO
1. Testing Testing Testing


## Contributing

All contributions are welcome: ideas, patches, documentation, bug reports, complaints, and even something you drew up on a napkin.

Programming is not a required skill. Whatever you've seen about open source and maintainers or community members  saying "send patches or die" - you will not see that here.

It is more important to the community that you are able to contribute.

For more information about contributing, see the [CONTRIBUTING](https://github.com/elasticsearch/logstash/blob/master/CONTRIBUTING.md) file.