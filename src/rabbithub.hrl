-record(rabbithub_subscription, {resource, topic, callback}).

-record(rabbithub_lease, {subscription, lease_expiry_time_microsec}).
-record(rabbithub_subscription_pid, {subscription, pid, expiry_timer}).
-record(rabbithub_subscription_err, {subscription, error_count, first_error_time_microsec, last_error_time_microsec}).
