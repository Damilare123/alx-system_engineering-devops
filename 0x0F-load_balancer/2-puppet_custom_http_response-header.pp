#!/usr/bin/env bash
# Installs, configures, and starts the load balancer
sudo apt-get update
sudo apt-get -y install --no-install-recommends software-properties-common
sudo add-apt-repository -y ppa:vbernat/haproxy-2.4
sudo apt-get -y install haproxy

# the load balancer's configuration
DOMAIN_NAME='beta-scribbles.tech'
INIT_FILE='/etc/default/haproxy'
CONFIG_FILE='/etc/haproxy/haproxy.cfg'
HAPROXY_LB_CONFIG=\
"
#--$DOMAIN_NAME-params-begin--
backend $DOMAIN_NAME-backend
	balance roundrobin
	server 9386-web-01 3.238.174.143:80 check
	server 9386-web-02 44.201.94.124:80 check
frontend $DOMAIN_NAME-frontend
	bind *:80
	mode http
	default_backend $DOMAIN_NAME-backend
#--$DOMAIN_NAME-params-end--
"

[ -f "$INIT_FILE" ] || touch "$INIT_FILE"
[ -f "$CONFIG_FILE" ] || touch "$CONFIG_FILE"

CONFIG_WORDS=$(grep -Eco "$DOMAIN_NAME-backend" < $CONFIG_FILE)

if [ "$(grep -Eco '^ENABLED=[01]$' < $INIT_FILE)" -gt 0 ]; then
	sed -i 's/^ENABLED=0$/ENABLED=1/' "$INIT_FILE"
else
	echo 'ENABLED=1' >> $INIT_FILE
fi

if [ "$CONFIG_WORDS" -eq 0 ]; then
	echo -e "$HAPROXY_LB_CONFIG" >> $CONFIG_FILE
else
	start_tkn="#--$DOMAIN_NAME-params-begin--"
	end_tkn="#--$DOMAIN_NAME-params-end--"
	a=$(grep -onE "$start_tkn" < "$CONFIG_FILE" | cut -d : -f1)
	b=$(grep -onE "$end_tkn" < "$CONFIG_FILE" | cut -d : -f1)
	a=$((a - 1))
	b=$((b + 1))
	sed -i "$a,$b"d "$CONFIG_FILE"
	echo -en "$HAPROXY_LB_CONFIG" >> $CONFIG_FILE
fi

if [ "$(pgrep -c haproxy)" -le 0 ]; then
	service haproxy start
else
	service haproxy restart
fi
