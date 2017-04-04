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

<img src="doc/rabbithub-example.png" alt="RabbitHub example configuration"/>

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

### See Wiki for more detailed information
Wiki Home:  https://github.com/gfiehler/rabbithub/wiki

Wiki Administrators Guide:  https://github.com/gfiehler/rabbithub/wiki/RabbitHub-Administrators-Guide

Wiki Users Guide:  https://github.com/gfiehler/rabbithub/wiki/RabbitHub-Users-Guide

## Installation
This release is for rabbitmq 3.6.6.  For prior versions of Rabbitmq please use the latest 3.6.3 branch.
To install from source (requires Erlang R18.3 or higher due to SSL bugs in 17.x.):

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

## Upgrade from Previous Versions of RabbitHub
Unfortunately due to changes in mnesia tables, at this time, an upgrade from a previous version of RabbitHub requires that the mnesia directory (/var/lib/rabbitmq/mnesia) directory is deleted before the upgrade.  This will mean a loss of all Rabbitmq messages and configuration.  Configuration can be saved via the rabbitmq-management ui/api by downloading the Rabbitmq defintions and then uploading them after the update.  However, this does not save in flight messages.  It is highly suggested that all publishers are turned off temporarily, wait until all in flight messages are consumed, export Rabbitmq definitions, then perform the upgrade.

Technical Note:  I have been unable to get the transform_table funtion to work when the table has more than 1 disc node.  If anyone has the answer on how to accomplish this, I would happy to make this upgrade function without loss of data.

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

## RabbitHub Management UI
A Rabbitmq Management Plugin for RabbitHub can be found here 
<https://github.com/gfiehler/rabbithub_management>

## RabbitHub API
### API  
| GET  | PUT  | DELETE  | POST | Path | Description |
| :---: |:---:| :---:| :---:| :------| :------|
|  | X  | X  | X | /endpoint/q/*queue_name* <br> /*vhost*/endpoint/q/*queue_name* | Create/Delete a Rabbitmq Queue|
|  | X  | X  | X | /endpoint/x/*exchange_name* <br> /*vhost*/endpoint/x/*exchange_name* | Create/Delete a Rabbitmq Exchange.<br> Publish Message to Exchange (Query Parameter:  hub.topic=topic_name,<br> Payload:  Message Body.  <br> See Table Below for all publishing options|
|  |   | X | X  | /subscribe/q/*queue_name* <br> /*vhost*/subscribe/q/*queue_name* | Subscribe to a Queue. <br> See below for payload options.<br>See Table below for Options.   |
|  |   | X | X  | /subscribe/x/*exchange_name* <br> /*vhost*/subscribe/x/*exchange_name* | Subscribe to an Exchange.  <br>See below for payload options..<br>See Table below for Options.  |
|  |   | X | X  | /subscribe/q/*queue_name* <br> /*vhost*/subscribe/q/*queue_name* | Unsubscribe to a Queue. <br>See below for payload options..<br>See Table below for Options.   |
|  |   | X | X  | /subscribe/x/*exchange_name* <br> /*vhost*/subscribe/x/*exchange_name* | Unsubscribe to an Exchange.  <br>See below for payload options..<br>See Table below for Options.  |
| X |   |  | X  | /subscriptions <br> /subscriptions/q/*queue_name* <br> /subscriptions/x/*exchange_name*  | 1. Batch Import/Export of all subscribers from/to a Json File.  See format below <br> 2. To retrieve a single subscription /subscriptions/*q or x*/*queue or exchange name*?hub.callback=*callbackurl*&hub.topic=*topic*<br> 3. To retrieve only subscriptions that will expire within *n* days add query parameter hub.expires=n where n is number of days|
| X |   |  |   | /subscriptions/errors  | Batch Export of all subscriber HTTP POST errors to a Json File.  See format below  |

#### Uniqueness of Subscriber
A Unique Subscriber is defined by 
 * vhost
 * resource type (queue/exchange)
 * resource name
 * callback url
 * topic
 
 NOTE:  *It is possible to create multiple subscribers to the same queue, depending on the exchange type.  If this occurs, the subscribers share the queue and each message will only go to one subscriber. Since the hub.topic parameter does not affect the subscription to an existing queue (primarily utilized when subscribing to an exchange in binding the generated pseudo queue to the exchange) but is still considered part of the uniqueness of the subscriber, you can create 2 subscribers to the same queue with different topics.  In this case only one subscriber to this queue will get each message.*

### Subscription Options
| Parameter  | Description  |
| :--- |:---| 
| hub.mode | 'subscribe' to create a new subscription, 'unsubscribe' to deactivate an existing subscription |
| hub.topic | A filter for selecting a subset of messages |
| hub.verify  | The subscription verification mode for this request (the value may be either “sync” or “async”). Refer to the PubSubHubBub specification for additional details. |
| hub.callback | Callback url for the subscribers rest api. |
| hub.lease_seconds | Subscriber-provided lease duration in seconds. After this time, the subscription will be terminated. The default lease is approximately 30 days, and the maximum lease is approximately 1000 years. Refer to the PubSubHubBub specification for additional information.  |
| hub.max_tps | Simple throttling mechanism to limit the Maximum Transactions Per Second that can be sent to a subscriber.  See Max TPS section for details |
| hub.ha_mode | Ability to set HA Mode for a consumer for an individual subscription overriding the enviornment variable settings.  See High Availability Consumers section for details |
| hub.basic_auth | allows the setting of basic auth credentials for calling the subscriber.  The value must be the base64 of user:pass. |
| hub.app_name | allows the setting of an application name for the subscriber. |
| hub.contact_name | allows the setting of contact name for the subscriber. |
| hub.phone | allows the setting of a phone number for the subscriber. |
| hub.email | allows the setting of an email address for the subscriber. |
| hub.description | allows the setting of a description for the subscriber. |

### Other Options
| Parameter  | Description  |
| :--- |:---| 
| hub.persistmsg | Used when Publishing a message.  true:  set Rabbitmq to persist this message, should be in conjunction with durable queues. |
| hub.expires | Used when performing a GET subscriptions.  This filters get all subscriptions to only suscriptions that will expire within *n* days |

### Subscription Payloads
Content-Type:  application/x-www-form-urlencoded<br>
`
"hub.mode=subscribe&hub.callback=http://10.1.1.8:4567/sub1&<br>hub.topic=foo&hub.verify=sync&hub.lease_seconds=86400"
`
<br>
Content-Type: application/json<br>
Required Fields<br>
```javascript
{
	"hub": {
		"callback": "http://10.1.1.8:4567/sub1",
		"topic": "foo",
		"mode": "subscribe",
		"verify": "sync",
	}
}
```
<br>
All Options<br>
```javascript
{
	"hub": {
		"callback": "http://10.1.1.8:4567/sub1",
		"topic": "foo",
		"lease_seconds": 1234,
		"mode": "subscribe",
		"verify": "sync",
		"max_tps": 3,
		"ha_mode": "all",
		"basic_auth": "base64ofuser:pass",
		"contact": {
			"app_name": "My App Name",
			"contact_name": "My Name",
			"phone": "111-111-1111",
			"email": "me@email.com",
			"description": "this is my subscriber app"
		}
	}
}
```

### Other Publishing Options
#### Headers Exchange Support
It is now possible to publish message headers for use with Headers exchanges. 
This is done with a custom HTTP header 'x-rabbithub-msg_header' sent with the publishing of a message to RabbitHub.
The format of the values is a comma delimited list of key=value pairs.  Each key/value pair will be converted to
a rabbitmq message properties used by headers exchanges for routing messages to queues.

'''
  x-rabbithub-msg_header:keya = valueA,keyb = valueB
'''

#### Correlation ID
If the following environment variable is set, and the configured http header is set when publishing a message, the correlation id will be logged in the Rabbitmq log and sent to the subscriber with the same http header.

Environment Variable:  `set_correlation_id = 'http header'` 
   ..* HTTP Header:  the name of an http header that will have a value of a correlation id.  E.g. 'x-correlation-id'
   If this header exists when a message is published to RabbitHub, the value will be passed on to all subscribers using the same http header on the Post to the subscriber.

#### Message ID
If the following enviroment variable is set, RabbitHub will generate a message id, log it in the Rabbitmq log and pass it to the subscriber in the configured http header.

Environment Variable:  `set_message_id = 'http header'` 
   ..* HTTP Header:  the name of an http header to send a message id to the subscriber.  E.g. 'x-message-id'
   If this variable is set, when a message is published to RabbitHub, a message id will be generated and logged with the publication and then the message id will be sent to all subscribers as the value to this http header.
 
#### Max TPS
A simple method to throttle messages being sent to subscribers.  Rabbithub follows the following simple algorithm to determine how long to wait before processing the next message for a particular subscriber.

   `Max Delay(milliseconds) = (1/(Max TPS/Number of Consumers))*1000
   
    Delay (milliseconds) = Max Delay - HTTP Post Transaction Time (milliseconds)`
	
	For example if you have environment variable ha_consumers=all and subscriber with max_tps=5 on a 3 node cluster 
	and the HTTP POST takes 20 milliseconds :
	
	Delay = (1/(5/3))*1000 - 200
	Delay = 400 milliseconds
	
	Note:  setting environment variable log_maxtps_delay = true will log this value on each POST.

#### Subscriber Basic Auth
Ability to configure basic authentication credentials for RabbitHub to use when it calls the subscriber.  The value of the parameter is the base64 of user:pass.  Example:
	~$ echo -n user:pass | base64
	~$ dXNlcjpwYXNz
	POST ../subscribe/q/*queue_name* Payload: "hub.mode=subscribe&hub.callback=http://10.1.1.8:4567/sub1&hub.topic=foo&hub.verify=sync&hub.lease_seconds=86400&hub.basic_auth=dXNlcjpwYXNz"

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

  Environment Variable:  `log_published_messages = true/false` 
   ..* true:  will log all messages published to RabbitHUb with Message ID (if configured), Correlation ID (if present) and Configured Message Headers.  
   ..* false: (default) will not log messages published to RabbitHub

  Environment Variable:  `log_message_body = true/false` 
   ..* true:  if `log_published_messages` is set to true, also log the message body with published messages
   ..* false: (default) will not log message body for published messages

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
### Subscriber Verification on Unsubscribe  
  By default the subscriber callback URL must be active and available to validate subscribe and unsubscribe requests.  The following environment variable allows for unsubscribing (deactivating) a subscriber without the validation to the callback URL.  This can be useful if a subscriber is down and it is desired to keep the subscription record in an inactive state until it is back up and available.
  
  Environment Variable:  `validate_callback_on_unsubscribe = true/false` 
   ..* true (default):  default behavior requires the callback URL to validate all unsubscribe/deactivate requests
   ..* false:  when a unsubscribe request is made, do not validate with the callback URL, shutdown any active consumers and change status to inactive.

### HTTP Request Options
  Options that are used when sending a HTTP POST request to the subscriber. E.g. timeout and connect_timeout.  Please see the HTTP Option section of <http://erlang.org/doc/man/httpc.html#request-5>.
  
  `[
        {rabbithub, [            
			{http_request_options, [
				{timeout, 2000}
			]}
	   ]}
    ].`
	
### RabbitHub Subscriber Validation
By default, any action to the subscriber must be validated.  This is done by making a GET request to the subscriber with a token value and the subscriber must respond with the token. Validation is done on `subscribe` and `unsubscribe` commands.   Subscribe is always required, however, unsubscribe validation can be turned off with the following environment variable.  This can be useful if a subscriber has stopped without unsubscribing and large numbers of messages are being backed up.

* `validate_callback_on_unsubscribe` = (true, false)
 ..* true:  default value.  Requires validation by calling subscriber to unsubscribe.
 ..* false: does not require validation to unsubscribe.  
   

### VHOST Support

RabbitHub supports publishing and subscribing to vhosts by adding the vhost name to the url prior to the resource.  Not adding the vhost to the path defaults to the default vhost '/'.
For exmaple:

- http://localhost:15670/testvhost/endpoint/x/xFoo

### Subscribing to an Exchange
Technically it is not possbile to subscribe to an exchange.  To allow this, RabbitHub generates a queue with a name of 
     `amq.http.pseudoqueue-<guid>`
RabbitHub then binds that queue to the exchange with the hub.topic parameter as the routing key and creates a Rabbitmq 
consumer for that queue.  

However, this was done with an internal queue which means the consumer tag is not associated with the queue and it is harder to trace which queue is connected to which subscriber.  Also, some of the newer error management features are also not available e.g. 	unsubscribe_on_http_post_error.

If the following environment variable is set, RabbitHub will still generate the queue, however, after binding it to the exchange, it will create a standard consumer that allows all features to work.  It will also show the consumer tag on the queue details page and show the pseudo_queue name on the subscriber details page of the RabbitHub Manangement Plugin.

* `use_internal_queue_for_pseudo_queue` = (true, false)
 ..* true:  default.  Backwards compatible by using internal queues.
 ..* false: will create a standard consumer and link the queue to the consumer and subscriber. 

**NOTE:**  *If you create subscribers to an exchange and then change `use_internal_queue_for_pseudo_queue` value, it will most likely fail.  If you need to change which pseduo queue method is used, you must delete all current exchange subscribers and re-create them after the change.*

### Export List of Subscribers
The following api will return a json formatted list of the current subscribers for RabbitHub.

<em>Note:  both import and export of subscribers requires a user with rabbitmq tags (roles)  `administrator,rabbithub_admin`</em>

`curl --request GET http://guest:guest@localhost:15670/subscriptions`
  
 - vhost:  vhost
 - resource_type:  queue or exchange
 - resource_name:  name of resource
 - topic:          routing key from hub.topic parameter
 - callback:       url of callback subscriber
 - lease_expiry_time_microsec: date time of subscription expiration in microseconds- http://localhost:15670/subscriptions.  This field is ignored on a POST.  
 - lease_seconds:  the lease time in seconds as given at time of subscription
 - ha_mode:        HA Mode (all, n, none)
 - status:         active/inactive (equivalent to hub.mode subscribe/unsubscribe
 - max_tps:        number of transactions per second allowed to this subscriber
 - pseudo_queue:   when subscribing to an exchange, a queue is created for the subscription by RabbitHub, this is the definition of this queue.  This field is ignored on a POST.
 - outbound_auth:  section to hold authentication values for calling a subscribers callback url.  This has 2 data fields, auth_type and auth_config.  Currently only basic_auth is supported.
 - auth_type:      basic_auth is the only currently supported auth_type.
 - auth_config:    the base64 encoded string for the user:pass for basic authentication when calling the subscriber callback url
 - contact:        this section hold contact information about the subscriber
 - app_name:       the name of the subscribing application
 - contact_name:   the contact person for the subscription
 - phone:          the contact phone number for the subscription
 - email:          the contact email address for the subscription
 - description:    a description of the subscription
 
```javascript
{
	"subscriptions": [{
		"vhost": "rhtest2",
		"resource_type": "exchange",
		"resource_name": "xfanout1",
		"topic": "testx1",
		"callback": "http://localhost:8999/rabbithub/s1",
		"lease_expiry_time_microsec": 4638804849466651,
		"lease_seconds": 3153600000,
		"ha_mode": 1,
		"status": "active",
		"max_tps": 0,
		"pseudo_queue": "[{amqqueue,{resource,<<\"rhtest2\">>,queue, <<\"amq.http.pseudoqueue-BeIw7rnvjx9i2p_6CS5-0Q\">>}, true,false,none,[],<0.6145.2>,[],[],[],undefined,[],[],live,0}]",
		"outbound_auth": "undefined",
		"contact": "undefined"
	}, {
		"vhost": "rhtest2",
		"resource_type": "queue",
		"resource_name": "q1",
		"topic": "testq1allparams",
		"callback": "http://localhost:8999/rabbithub/s1",
		"lease_expiry_time_microsec": 1485291249262811,
		"lease_seconds": 86400,
		"ha_mode": "all",
		"status": "active",
		"max_tps": 2,
		"pseudo_queue": "[undefined]",
		"outbound_auth": {
			"auth_type": "basic_auth",
			"auth_config": "base64encodedstring"
		},
		"contact": {
			"app_name": "my est app 2",
			"contact_name": "my name",
			"phone": "111-111-1111",
			"email": "me@mail.com",
			"description": "my test app description"
		}
	}]
}
```
### Import Subscribers in Batch
The file that was exported in the previous section can then be imported with the following API

<em>Note:  both import and export of subscribers requires a user with rabbitmq tags (roles)  `administrator,rabbithub_admin`</em>

```
  curl -d '{
	"subscriptions": [{
		"vhost": "rhtest2",
		"resource_type": "exchange",
		"resource_name": "xfanout1",
		"topic": "testx1",
		"callback": "http://localhost:8999/rabbithub/s1",
		"lease_expiry_time_microsec": 4638804849466651,
		"lease_seconds": 3153600000,
		"ha_mode": 1,
		"status": "active",
		"max_tps": 0,
		"pseudo_queue": "[{amqqueue,{resource,<<\"rhtest2\">>,queue, <<\"amq.http.pseudoqueue-BeIw7rnvjx9i2p_6CS5-0Q\">>}, true,false,none,[],<0.6145.2>,[],[],[],undefined,[],[],live,0}]",
		"outbound_auth": "undefined",
		"contact": "undefined"
	}, {
		"vhost": "rhtest2",
		"resource_type": "queue",
		"resource_name": "q1",
		"topic": "testq1allparams",
		"callback": "http://localhost:8999/rabbithub/s1",
		"lease_expiry_time_microsec": 1485291249262811,
		"lease_seconds": 86400,
		"ha_mode": "all",
		"status": "active",
		"max_tps": 2,
		"pseudo_queue": "[undefined]",
		"outbound_auth": {
			"auth_type": "basic_auth",
			"auth_config": "base64encodedstring"
		},
		"contact": {
			"app_name": "my est app 2",
			"contact_name": "my name",
			"phone": "111-111-1111",
			"email": "me@mail.com",
			"description": "my test app description"
		}
	}]
      }' --header "content-type:application/json" http://guest:guest@localhost:15670/subscriptions
```
Both export and import are also available via the RabbitHub Management UI.

### Modifying an Existing Subscribers Configuration
If you need to update the configuration, such as expiration or ha mode, and the subscriber is already running and active, you must first deactivate the subscriber, then activate it with the new configuration.  If you update the subscriber configuration while it is active, it will not affect the current running subscriber, but will take affect on the next consumer restart.  This can be done via the API, UI or via batch updates.

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
 `unsubscribe_on_http_post_error_limit` may occur within `unsubscribe_on_http_post_error_timeout_microseconds` time interval before the consumer is unsubscribed.  Also if these are set unsubscribe_on_http_post_error will not be used as the above overrides it.


The following table helps explain how the above options work together.

| requeue_on_ http_post_ error | unsubscribe_on_ http_post _error | unsubscribe_on_ http_post_ error_limit | unsubscribe_on_ http_post_ error_timeout_ microseconds | requires DLQ | Behavior | 
|-------------|-----|----------|--------|--------|---------| 
| TRUE  | TRUE | Unset| Unset | NO | HTTP Response Error:  Consumer: unsubscribed <br><br>Message in Queue: Ready|
|       |      |      | | |Other Error:  Consumer:  Unsubscribed<br><br> Message in Queue:  Ready |
| TRUE  | FALSE | Unset | Unset | NO | "HTTP Response Error:  Consumer: Subscribed<br><br> Message in Queue:  Unacked |
| | | | | | Other Error:  Consumer:  Subscribed <br><br> Message in Queue:  Unacked |
| TRUE | TRUE | Set | Set | YES  | HTTP Response Error:  Consumer:  Unsubscribed <br>(only 1 message is published,<br> they retry 5 more times and unsub)<br><br><br>Message in Queue: Ready |
| | | | | | Other Error:  Consumer:  Unsubscribed <br><br><br>Message in Queue:  Ready |
| TRUE  | FALSE | Set | Set | YES | NOT ALLOWED <br><br><br> NOT ALLOWED |                                                                                                     | 
| FALSE | TRUE | Unset | Unset | YES | HTTP Response Error:  Consumer: Unsubscribed<br><br><br>Message in Queue:  DLQ or Lost|
| | | | | | Other Error:  Consumer:  Unsubscribed<br><br><br>Message in Queue:  Ready |
| FALSE | FALSE | Unset | Unset | YES | HTTP Response Error:  Consumer:  Subscribed<br><br><br>Message in Queue:  DLQ or Lost |
| | | | | | Other Error:  Consumer:  Subscribed<br><br>Message in Queue:  Unacked |
| FALSE | TRUE | Set | Set | YES | HTTP Response Error:  Consumer:  Unsubscribed<br> (6 msgs published before Unsub)<br><br><br>Message in Queue:  6 msgs in DLQ or Lost | 
| | | | | | Other Error: Consumer: Unsubscribed <br>(6 msgs publsihed before unusb)<br><br><br>Message in Queue:<br>  6 msgs DLQ or Lost  |
| FALSE | False<br> NOT ALLOWED |  Set | Set | YES | NOT ALLOWED<br><br><br>NOT ALLOWED | 


| Terms | Explanations |
|-------|--------------|
| HTTP Resonse Error | HTTP response codes in 400 or 500 series |
| Other Errors | Connection error or timeout error |
| Message in Queue: ready | Msg can be processed by another consumer |
| Message in Queue: Unacked | msg cannot be processed by another consumer,<br> consumer is hung and no other messages can be processed.  Have to manually unsubscribe or deactivate user to process msg |
| Message in Queue:  DLQ or Lost | msg is either lost or sent to Dead Letter Queue<br> if a Dead Letter Exchange is configured |
| Consumer:  Unsubscribed | Consumer was deactivated, can be Activated via UI or API |

### Sample Configuration
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
	[RabbitHub Management UI](https://github.com/gfiehler/rabbithub_management)
 
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
