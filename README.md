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
            
        # Sometimes it's usefull to ignore failed messages, 
        # in the case set ignore_bad_message to True.
        # By default it is False
        ignore_bad_message => true
        
        # Datastax cassandra driver supports batch insert.
        # You can define the batch size explicitely.
        # By default it is 1.
        batch_size => 100
    }
}
</code></pre>

## TODO
1. Testing Testing Testing
1. Implement a mechanism to flush a batch to cassandra even in the case when an amount of collected messages is lesser than <code>batch_size</code>

## Contributing

All contributions are welcome: ideas, patches, documentation, bug reports, complaints, and even something you drew up on a napkin.

Programming is not a required skill. Whatever you've seen about open source and maintainers or community members  saying "send patches or die" - you will not see that here.

It is more important to the community that you are able to contribute.

For more information about contributing, see the [CONTRIBUTING](https://github.com/elasticsearch/logstash/blob/master/CONTRIBUTING.md) file.