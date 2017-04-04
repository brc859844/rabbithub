-record(rabbithub_subscription, {resource, topic, callback}).
-record(rabbithub_consumer, {subscription, node}).
-record(rabbithub_lease, {subscription, lease_expiry_time_microsec, lease_seconds, ha_mode, max_tps, status, pseudo_queue}).
-record(rabbithub_subscription_pid, {consumer, pid, expiry_timer}).
-record(rabbithub_subscription_err, {subscription, error_count, first_error_time_microsec, last_error_time_microsec, last_error_msg}).
-record(rabbithub_batch, {subscription, lease_expiry_time_microsec, status}).
%% create a new record type for each security_type to use in parsing the security_config
-record(rabbithub_outbound_auth, {subscription, auth_type, auth_config}).
%% store the base64 econded basic auth string, not its components
-record(rabbithub_outbound_auth_basicauth_config, {authorization}).
-record(rabbithub_contact, {app_name, contact_name, phone, email, description}).
-record(rabbithub_subscriber_contact_info, {subscription, contact_info}).
