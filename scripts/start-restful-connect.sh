#!/usr/bin/env bash

NAME="restful-connector"
CHECK_STATUS_HOST="kafka-subscription"
CHECK_STATUS_PORT="2000"
CHECK_STATUS_PATH="up"
tag="[start-restful-connect.sh]"

function info {
  echo "$tag (INFO) : $1"
}
function warn {
  echo "$tag (WARN) : $1"
}
function error {
  echo "$tag (ERROR): $1"
}

set -e

# Verify envs
if [[ -z "$CONNECT_BOOTSTRAP_SERVERS" ]]; then
  error "EMPTY ENV 'CONNECT_BOOTSTRAP_SERVERS'"; exit 1
fi

if [[ -z "$CONNECT_REST_ADVERTISED_HOST_NAME" ]]; then
  warn "EMPTY ENV 'CONNECT_REST_ADVERTISED_HOST_NAME'"; unset $CONNECT_REST_ADVERTISED_HOST_NAME
fi

if [[ -z "$CONNECT_REST_ADVERTISED_PORT" ]]; then
  warn "EMPTY ENV 'CONNECT_REST_ADVERTISED_PORT'"; unset $CONNECT_REST_ADVERTISED_PORT
fi

if [[ -z "$CONNECT_JMX_PORT" ]]; then
  warn "EMPTY ENV 'CONNECT_JMX_PORT'"; unset $CONNECT_JMX_PORT
fi

if [[ -z "$CONNECT_GROUP_ID" ]]; then
  warn "EMPTY ENV 'CONNECT_GROUP_ID'. USE DEFAULT VALUE"; unset $CONNECT_GROUP_ID
fi

CONNECT_PID=0

handleSignal() {
  info 'Stopping... '
  if [ $CONNECT_PID -ne 0 ]; then
    kill -s TERM "$CONNECT_PID"
    wait "$CONNECT_PID"
  fi
  info 'Stopped'
  exit
}

function create_connector() {
    connector_data=`curl -v -H "Content-Type: application/json" -X POST --max-time 5 -d "{\"name\":\"$NAME\",\"config\":{\"connector.class\":\"io.github.makiskaradimas.connect.restful.RestfulSinkConnector\",\"message.class\":\"io.github.makiskaradimas.dataenrichment.post.EnrichedPost\",\"entity.class\":\"io.github.makiskaradimas.dataenrichment.gson.PostDto\",\"entity.serializer.class\":\"io.github.makiskaradimas.dataenrichment.gson.PostDtoSerializer\",\"tasks.max\":\"2\",\"bulk.size\":\"1\",\"topics\":\"streams-joined-output\"}}" http://$CONNECT_REST_ADVERTISED_HOST_NAME:$CONNECT_REST_ADVERTISED_PORT/connectors 2>/dev/null`
    if [ $(echo $connector_data | grep "$NAME" | wc -l) -gt 0 ]
    then
        info "Starting connector $NAME"
    elif [ $(echo $connector_data | grep "409" | wc -l) -gt 0 ]
    then
       warn "Connector $NAME already exists. Resuming..."
    else
       error "Failed to create connector $NAME. Response data: $connector_data"
    fi
}

info "Starting..."
trap "handleSignal" SIGHUP SIGINT SIGTERM
until [ $(curl -H "Content-Type: application/json" -I http://$CHECK_STATUS_HOST:$CHECK_STATUS_PORT/$CHECK_STATUS_PATH 2>/dev/null | grep "200 OK" | wc -l) -gt 0 ]; do
   sleep 1
done
$KAFKA_HOME/bin/kafka-topics.sh --create --zookeeper zookeeper:2181 --replication-factor 1 --partitions 1 --topic connect-offsets-restful &>/dev/null || $KAFKA_HOME/bin/kafka-topics.sh --alter --zookeeper zookeeper:2181 --topic connect-offsets-restful &>/dev/null
$KAFKA_HOME/bin/kafka-topics.sh --create --zookeeper zookeeper:2181 --replication-factor 1 --partitions 1 --topic connect-configs-restful &>/dev/null || $KAFKA_HOME/bin/kafka-topics.sh --alter --zookeeper zookeeper:2181 --topic connect-configs-restful &>/dev/null
$KAFKA_HOME/bin/kafka-topics.sh --create --zookeeper zookeeper:2181 --replication-factor 1 --partitions 1 --topic connect-status-restful &>/dev/null || $KAFKA_HOME/bin/kafka-topics.sh --alter --zookeeper zookeeper:2181 --topic connect-status-restful &>/dev/null
$KAFKA_HOME/bin/connect-distributed.sh $KAFKA_HOME/config/connect-distributed-restful.properties &
CONNECT_PID=$!
# Wait for worker to get ready
until [ $(curl -H "Content-Type: application/json" -I --max-time 5 http://$CONNECT_REST_ADVERTISED_HOST_NAME:$CONNECT_REST_ADVERTISED_PORT/connectors 2>/dev/null | grep "200 OK" | wc -l) -gt 0 ]; do
   sleep 1
done
create_connector

wait