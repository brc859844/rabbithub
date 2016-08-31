# PubSub-over-Webhooks with RabbitHub

[RabbitHub][gitrepo] is an implementation of
[PubSubHubBub][pshb_project], a straightforward pubsub layer on top of
plain old HTTP POST - pubsub over Webhooks. RabbitHub provides an
HTTP-based interface to [RabbitMQ][].

It gives every AMQP exchange and queue hosted by a RabbitMQ broker a
couple of URLs: one to use for delivering messages to the exchange or
queue, and one to use to subscribe to messages forwarded on by the
exchange or queue. You subscribe with a callback URL, so when messages
arrive, RabbitHub POSTs them on to your callback. For example,

 - <http://dev.rabbitmq.com/rabbithub/endpoint/x/amq.direct> is the
   URL for delivering messages to the "amq.direct" exchange on the
   public test instance of RabbitMQ, and

 - <http://dev.rabbitmq.com/rabbithub/subscribe/q/some_queue_name> is
   the URL for subscribing to messages from the (hypothetical) queue
   "some_queue_name" on the broker.

The symmetrical .../subscribe/x/... and .../endpoint/q/... also exist.

The [PubSubHubBub protocol][spec] specifies some RESTful(ish)
operations for establishing subscriptions between message sources
(a.k.a "topics") and message sinks. RabbitHub implements these
operations as well as a few more for RESTfully creating and deleting
exchanges and queues.

While PubSubHubBub is written assuming Atom content, RabbitHub is
content-agnostic (just like RabbitMQ): any content at all can be sent
using RabbitHub's implementation of the PubSubHubBub protocol. Because
RabbitHub is content-agnostic, it doesn't implement any of the
Atom-specific parts of the PubSubHubBub protocol, including the "ping"
operation that tells a PSHB hub to re-fetch content feeds.

## <a name="example"></a>Example: combining HTTP messaging with AMQP and XMPP

Combining RabbitHub with the AMQP protocol implemented by RabbitMQ
itself and with the other adapters and gateways that form part of the
RabbitMQ universe lets you send messages across different kinds of
message networks - for example, our public RabbitMQ instance,
`dev.rabbitmq.com`, has RabbitHub running as well as the standard AMQP
adapter, the [rabbitmq-xmpp][] plugin, and a bunch of our other
experimental stuff, so you can do things like this:

<img src="https://raw.githubusercontent.com/tonyg/rabbithub/master/doc/rabbithub-example.png" alt="RabbitHub example configuration"/>

 - become XMPP friends with `pshb@dev.rabbitmq.com` (the XMPP adapter
   gives each exchange a JID of its own)

 - use PubSubHubBub to subscribe the sink
   <http://dev.rabbitmq.com/rabbithub/endpoint/x/pshb> to some
   PubSubHubBub source - perhaps one on the public Google PSHB
   instance. (Note how the given URL ends in "x/pshb", meaning the
   "pshb" exchange - which lines up with the JID we just became XMPP
   friends with.)

 - wait for changes to be signalled by Google's PSHB hub to RabbitHub

 - when they are, you get an XMPP IM from `pshb@dev.rabbitmq.com` with
   the Atom XML that the hub sent out as the body

Again, RabbitHub is content-agnostic, so the fact that Atom appears is
an artifact of what Google's public PSHB instance is mailing out,
rather than anything intrinsic in pubsub-over-webhooks.

## Installation

To install from source (requires Erlang R15B01 or higher):

    git clone https://github.com/brc859844/rabbithub
    cd rabbithub
    make deps
    make
    make package
    cp dist/*.ez $RABBITMQ_HOME/plugins

Note that Windows users can build the plugin using the commands under Cygwin. When working with Cygwin ensure that the Erlang bin directory is in your PATH (so that rebar can find erl and erlc) and that the zip utility is installed with your Cygwin installation (required to create the plugin ez file).

Enable the plugin:

    rabbitmq-plugins enable rabbithub

By default the plugin will listen for HTTP requests on port 15670.

Note that if no username is specified for HTTP requests submitted to RabbitHub then RabbitHub checks to see whether a default username has been specified for the rabbithub application, and if so uses it. By default RabbitHub is configured to use a default username of `guest` (see the definition of `default_username` in `rabbithub.app`). This configuration might be reasonable for development and testing (aside from security testing); however for production environments this will most likely not be ideal, and the default username should therefore be deleted or changed to a RabbitMQ username that has only the required permissions. It is generally also a good idea to disable the RabbitMQ `guest` user, or to at least reduce the permissions of `guest` (when RabbitMQ is initially installed, the username `guest` has full permissions and a rather well-known password).   

## HTTP messaging in the Browser

In order to push AMQP messages out to a webpage running in a browser,
try using <http://www.reversehttp.net/> to run a PubSubHubBub endpoint
in a webpage - see for instance
<http://www.reversehttp.net/demos/endpoint.html> and its [associated
Javascript](http://www.reversehttp.net/demos/endpoint.js) for a simple
prototype of the idea. It's also possible to build simple PSHB hubs in
Javascript using the same tools.

  [gitrepo]: http://github.com/tonyg/rabbithub
  [pshb_project]: http://code.google.com/p/pubsubhubbub/
  [spec]: http://pubsubhubbub.googlecode.com/svn/trunk/pubsubhubbub-core-0.1.html
  [RabbitMQ]: http://www.rabbitmq.com/
  [rabbitmq-xmpp]: http://hg.rabbitmq.com/rabbitmq-xmpp/raw-file/default/doc/overview-summary.html

## Proxy server support

If RabbitHub is being used behind a firewall, it may be necessary to route HTTP(s) requests to callback URLs via a proxy server. A proxy server can be specified for RabbitHub by defining `http_client_options` in `rabbitmq.config` as illustrated below, where the same proxy server has been specified for both HTTP and HTTPS, and the proxy server will not be used for requests to `localhost`.

    [
        {rabbithub, [
            {http_client_options, [
                {proxy,{{"10.1.1.1",8080}, ["localhost"]}},
                {https_proxy,{{"10.1.1.1",8080},["localhost"]}}
            ]}
        ]}
    ].

Note that proxy server support is only available in RabbitHub for RabbitMQ 3.2.1 or higher.

## Cluster Support

### Mnesia Table Cluster Support
RabbitHub now creates copies of its 3 mnesia tables across all nodes of a cluster for enhanced cluster failover ability.

 - rabbithub_lease (disc_copy)
 - rabbithub_subscription_pid (ram_copy)
 - rabbithub_subscription_err (ram_copy)

### RabbitHub Consumer Cluster Support
#### Consumer Tags
RabbitHub consumers can now be created with Consumer Tag format.  Consumer Tags show up in the Rabbitmq Management UI on the detail screen for a queue.  This helps identify where the Consumer is located in a cluster.

	 amq.http.consumer.*localservername*-AhKV3L3eH2gZbrF79v2kig
	 
   where the localservername is the server name of the rabbitmq cluster node on which the consumer was created by setting RabbitHub environment variable `include_servername_in_consumer_tag` to true.     
   
   By not setting this variable the backwards compatible consumer tag of
   
     amq.http.consumer-AhKV3L3eH2gZbrF79v2kig
	 
  will be used.  An example can of setting this variable can be found in the test folder in the file:  rabbitmq.config.consumertag.
  
#### High Availability Consumers
RabbitHub now supports several modes in which you can create more than 1 consumer for a subscription across the cluster for high availability.

By setting the `ha_consumers` environment variable to one of the following modes

  - `all`:  when a subscription is created a copy of the consumer is created on all nodes of the cluster
  - `n`:  where `n` is an integer, in this mode a copy of the consumer will be started on `n` number of nodes plus the original node to which the subscription was made.  Therefore if `ha_consumers=1` and there are more than 1 node in the cluster,  2 consumers will be created.  The `n` consumers will be created on randomly selected cluster nodes other than the original node.
  
  Note:  In these modes Rabbithub will first create the consumer on the local node to which the subscription was made, if that consumer starts, it will always return a positive return code to the subscriber, even if some or all of the remote consumers do not start.  The body of the response will include status of all attemped consumer starts.  The following is an example response
  
  `{
	"consumers": [{
		"node": "rabbit@rabbit1",
		"status": "ok"
	}, {
		"node": "rabbit@rabbit2",
		"status": "ok"
	}]
   }`
  
#### RabbitHub Failover Support
  If HA Queues are being used in the Rabbitmq cluster and a node goes down, those queues will failover to another node according to the policies set for HA Queues.  When this happens The consumers that are connected to that queue will also go down.  However, Rabbithub will attempt to restart all consumers that fail.  However, the restart attempts generally happen too quickly for the master queues to failover and be ready to accept new connection.  To solve this issue a new environment varaible can be set to set a wait interval between a consumer going down and the restart attempt which will, in most cases, allow the master queue to failover and be ready to accept new connections.
  
  Environment Variable:  `wait_for_consumer_restart_milliseconds = N` 
	where `N` is an integer in milliseconds.  
	
## RabbitHub Troubleshooting

  To help troubleshoot or just log activity an option is available to log the payload of all http posts to subscribers.		
  
  Environment Variable:  `log_http_post_request = true/false` 
   ..* true:  will log all posts to subscribers
   ..* false: (default) will not log posts to subscribers
	 
  To log other values that may be useful for troubleshooting or for archive records the following Environment Variables are available:

  Environment Variable:  `log_http_headers = [header1, header2]` 
   ..* List of HTTP Headers:  a comma separated list of http headers in single quotes. E.g. ['content-type', 'authorization']
   Each http header, if it exists, when a message is published to RabbitHub will be logged.
   
  Environment Variable:  `set_correlation_id = 'http header'` 
   ..* HTTP Header:  the name of an http header that will have a value of a correlation id.  E.g. 'x-correlation-id'
   If this header exists when a message is published to RabbitHub, the value will be passed on to all subscribers using the same http header on the Post to the subscriber.
   
  Environment Variable:  `set_message_id = 'http header'` 
   ..* HTTP Header:  the name of an http header to send a message id to the subscriber.  E.g. 'x-message-id'
   If this variable is set, when a message is published to RabbitHub, a message id will be generated and logged with the publication and then the message id will be sent to all subscribers as the value to this http header.
   
## RabbitHub Subscriber Management
  By default the subscriber callback URL must be active and available to validate subscribe and unsubscribe requests.  The following environment variable allows for unsubscribing (deactivating) a subscriber without the validation to the callback URL.  This can be useful if a subscriber is down and it is desired to keep the subscription record in an inactive state until it is back up and available.
  
  Environment Variable:  `validate_callback_on_unsubscribe = true/false` 
   ..* true (default):  default behavior requires the callback URL to validate all unsubscribe/deactivate requests
   ..* false:  when a unsubscribe request is made, do not validate with the callback URL, shutdown any active consumers and change status to inactive.

  
## RabbitHub APIs

### VHOST Support

RabbitHub supports publishing and subscribing to vhosts by adding the vhost name to the url prior to the resource.  Not adding the vhost to the path defaults to the default vhost '/'.
For exmaple:

- http://localhost:15670/testvhost/endpoint/x/xFoo

### Headers Exchange Support
It is now possible to publish message headers for use with Headers exchanges. 
This is done with a custom HTTP header 'x-rabbithub-msg_header' sent with the publishing of a message to RabbitHub.
The format of the values is a comma delimited list of key=value pairs.  Each key/value pair will be converted to
a rabbitmq message properties used by headers exchanges for routing messages to queues.

'''
  x-rabbithub-msg_header:keya = valueA,keyb = valueB
'''

### Export List of Subscribers
The following api will return a json formatted list of the current subscribers for RabbitHub.

`curl --request GET http://guest:guest@localhost:15670/subscriptions`
  
 - vhost:  vhost
 - resource_type:  queue or exchange
 - resource_name:  name of resource
 - topic:          routing key from hub.topic parameter
 - callback:       url of callback subscriber
 - lease_expiry_time_microsec: date time of subscription expiration in microseconds- http://localhost:15670/subscriptions   
 - lease_seconds:  the lease time in seconds as given at time of subscription
 - ha_mode:        HA Mode (all, n, none)
 - status:         active/inactive
 
```javascript
{
	"subscriptions": [{
		"vhost": "/",
		"resource_type": "queue",
		"resource_name": "ha.q2",
		"topic": "inactivetest",
		"callback": "http://callbackdomain/subscriber/s2",
		"lease_expiry_time_microsec": 1472911582355564,
		"lease_seconds": 1000000,
		"ha_mode": "all",
		"status": "inactive"
	}, {
		"vhost": "/",
		"resource_type": "queue",
		"resource_name": "ha.1",
		"topic": "activetest",
		"callback": "http://callbackdomain/subscriber/s1",
		"lease_expiry_time_microsec": 1472911582355564,
		"lease_seconds": 1000000,
		"ha_mode": "all",
		"status": "active"
	}]
```
### Import Subscribers in Batch
The file that was exported in the previous section can then be imported with the following API

```javascript
  curl -d '{"subscriptions":[{"vhost":"/","resource_type":"queue","resource_name":"ha.q2","topic":"ha.q2","callback":"http://RabbitErl19:8999/rabbithub/s2","lease_expiry_time_microsec":1472716785983474, "lease_seconds":1000000,"ha_mode":"none","status":"active"}, {"vhost":"/","resource_type":"queue","resource_name":"ha.q1","topic":"ha.q1","callback":"http://callbackdomain/subscriber/s2", "lease_expiry_time_microsec":1472733774026491, "lease_seconds":1000000,"ha_mode":"none","status":"active"}, {"vhost":"/","resource_type":"queue","resource_name":"ha.q1","topic":"test","callback":"http://callbackdomain/subscriber/s2", "lease_expiry_time_microsec":1472733774026491,"lease_seconds":1000000,"ha_mode":"none","status":"inactive"}]}' --header "content-type:application/json" http://guest:guest@localhost:15670/subscriptions
```
Both export and import are also available via the RabbitHub Management UI.

## RabbitHub hub.topic in posts to subscribers
  RabbitHub environment variable- append_hub_topic_to_callback: (true, false)
  ..* true: (default) Append hub.topic parameter when Posting a message to a subscriber
  ..* false: Do not append hub.topic parameter when Posting a message to a subscriber 
  
## RabbitHub HTTP Post to Subscriber Error Management
Two new rabbithub environment parameters are now available to control what happens when a HTTP POST to a consumer fails.
The following parameters can be defined in the `rabbitmq.config` file
These are set in the rabbitmq.config file as illustrated below

 * `requeue_on_http_post_error` = (true, false)
 ..* true:  will not requeue, message may be lost
 ..* false: will requeue, best utilized when queue has a dead-letter-exchange configured
 * `unsubscribe_on_http_post_error` = (true, falise)
 ..* true: (default) on HTTP Post error to subscriber, the consumer will be unsubscribed
 ..* false: on HTTP Post error to subscriber the consumer will not be unsubscribed
 ..* Note:  If this variable is set to false, it will override unsubscribe_on_http_post_error_limit and unsubscribe_on_http_post_error_timeout_microseconds and not unsubscribe even when reaching the configured limits.
 * `unsubscribe_on_http_post_error_limit` = integer
 ..* Integer value is how many errors are allowed prior to the consumer being unsubscribed
 * `unsubscribe_on_http_post_error_timeout_microseconds` = microseconds
 ..* Time interval where unsubscribe_on_http_post_error_limit errors are allowed to happen prior to unsubscribing the consumer
 
NOTE: 'unsubscribe_on_http_post_error_limit' and `unsubscribe_on_http_post_error_timeout_microseconds` must be set as a pair as it designates that
 `unsubscribe_on_http_post_error_limit` may occur within `unsubscribe_on_http_post_error_timeout_microseconds` time interval before the consumer is unsubscribed.
 
```
[

 {rabbithub, [        
	{requeue_on_http_post_error, false},
	{unsubscribe_on_http_post_error_limit, 5},
	{unsubscribe_on_http_post_error_timeout_microseconds, 60000000}	
    ]}
].
```
Note:  an example of this configuration can be found in the test folder in file:  rabbitmq.config.errormanagement.
 
These errors are tracked per subscriber and re-subscribing will reset the error tracking for that subscriber.

To help understand how many errors have occured the following rest endpoint returns a list of all error counts currently being tracked.

- http://localhost:15670/subscriptions/errors   

 - resource:  vhost
 - queue:  queue name
 - topic:  routing key from hub.topic parameter
 - callback:  url of callback subscriber
 - error_count: number of HTTP POST errors for this subscriber since the first_error_time_microsec
 - first_error_time_microsec:  time in microseconds for the first error in this interval
 - last_error_time_microsec:  time in microseconds of the last error that occurred 

```javascript
[{
	"resource": "/",
	"queue": "foo2",
	"topic": "foo2",
	"callback": "http://localhost:8999/rest/testsubscriber2",
	"error_count": 1,
	"first_error_time_microsec": 1467326540248893,
	"last_error_time_microsec": 1467326540248893
}, {
	"resource": "/",
	"queue": "foo1",
	"topic": "foo1",
	"callback": "http://localhost:8999/rest/testsubscriber1",
	"error_count": 2,
	"first_error_time_microsec": 1467326520609017,
	"last_error_time_microsec": 1467326522694452
}]
```

## RabbitHub Subscriber Creation
  
  To create a RabbitHub subscriber a restful api must be created that implements the following methods
  
  POST:  this will receive a message that the callback URL has been subscribed to as the body of the POST
	The following HTTP Headers may be set when the the message is POSTed to this URL
	
	
  GET:  this will receive validation requests for creating a subscription that will forward messages to this URL.  
    The method will receive a GET request with the following query parameter
		hub.challenge=`token`
	The api must return the token as the body of the response to validate that it is ok to create a subscription to this URL.
	
## RabbitHub Management UI
A Rabbitmq_management plugin has been created for RabbitHub.  Please refer to 

		https://github.com/gfiehler/rabbithub_management
 
## Software License

RabbitHub is [open-source](http://www.opensource.org/) code, licensed
under the very liberal [MIT
license](http://www.opensource.org/licenses/mit-license.php):

    Copyright (c) 2009 Tony Garnock-Jones <tonyg@lshift.net>
    Copyright (c) 2009 LShift Ltd. <query@lshift.net>

    Permission is hereby granted, free of charge, to any person
    obtaining a copy of this software and associated documentation
    files (the "Software"), to deal in the Software without
    restriction, including without limitation the rights to use, copy,
    modify, merge, publish, distribute, sublicense, and/or sell copies
    of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be
    included in all copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
    EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
    MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
    NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
    HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
    WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
    DEALINGS IN THE SOFTWARE.
