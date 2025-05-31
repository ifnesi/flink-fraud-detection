import eventlet

eventlet.monkey_patch()

import io
import os
import sys
import json
import time
import signal
import socket
import logging
import argparse

from flask import Flask, render_template, request, jsonify
from flask_socketio import SocketIO

from datetime import datetime, timezone
from configparser import ConfigParser

from confluent_kafka import Producer, Consumer, KafkaException
from confluent_kafka.schema_registry import SchemaRegistryClient
from confluent_kafka.schema_registry.avro import AvroSerializer, AvroDeserializer
from confluent_kafka.serialization import (
    SerializationContext,
    StringSerializer,
    StringDeserializer,
    MessageField,
)


####################
# Global variables #
####################
# Set console logs
logging.basicConfig(
    level=logging.INFO,
    format="[%(levelname)s] %(asctime)s: %(message)s",
    handlers=[logging.StreamHandler()],
)

# Flask App / WebSocket (to broadcast the Kafka data consumed back to the front-end)
app = Flask(
    __name__,
    static_folder="static",
    template_folder="templates",
)
socketio = SocketIO(
    app,
    cors_allowed_origins="*",
    async_mode="eventlet",
)


#####################
# Generic class #
#####################
class KafkaApp:
    """Main Kafka class for Producer and Consumer (consumer as a separate thread)"""
    def __init__(self, config):
        self.shutdown_event = False

        # Kafka topics
        self.producer_topic = config["others"]["producer.topic"]
        self.consumer_topic = [config["others"]["consumer.topic"]]

        # Configure Kafka producer
        self.conf_producer = dict(config["kafka"])
        self.conf_producer.update(config["kafka-producer"])
        self.producer = Producer(self.conf_producer)
        logging.info(
            f"Producer `{self.conf_producer['client.id']}` bootstrapped to: {self.conf_producer['bootstrap.servers']}"
        )

        # Configure Kafka consumer
        self.conf_consumer = {
            "client.id": socket.gethostname(),
        }
        self.conf_consumer.update(config["kafka"])
        self.conf_consumer.update(config["kafka-consumer"])
        self.consumer = Consumer(self.conf_consumer)
        logging.info(
            f"Consumer `{self.conf_consumer['group.id']} `bootstrapped to: {self.conf_consumer['bootstrap.servers']}"
        )

        # Get AVRO schema
        with open(os.path.join("schemas", "transactions.avro"), "r") as f:
            value_schema = json.loads(f.read())

        # Schema Registry
        conf_schema_registry = dict(config["schema-registry"])
        self.schema_registry = SchemaRegistryClient(conf_schema_registry)

        # Avro SerDes
        self.avro_serializer = AvroSerializer(
            self.schema_registry,
            json.dumps(value_schema),
        )
        self.avro_deserializer = AvroDeserializer(
            self.schema_registry,
        )

        # String SerDes
        self.string_serializer = StringSerializer("utf_8")
        self.string_deserializer = StringDeserializer("utf_8")

    def delivery_report(self, err, msg):
        if err is not None:
            logging.error(f"Message delivery failed -> {err}")
        elif msg is not None:
            logging.info(
                f"Message delivered to topic `{msg.topic()}`, partition #{msg.partition()} at offset #{msg.offset()}"
            )
        else:
            logging.error(f"Message delivery failed -> $err and $msg are null")

    def submit_event(self, key, value):
        """Publish message to Kafka"""
        self.producer.produce(
            self.producer_topic,
            key=self.string_serializer(key),
            value=self.avro_serializer(
                value,
                SerializationContext(
                    self.producer_topic,
                    MessageField.VALUE,
                ),
            ),
            on_delivery=self.delivery_report,
        )

    def kafka_consumer_thread(self):
        """Consume Kafka messages and push/websock it to the front-end"""
        self.consumer.subscribe(self.consumer_topic)
        logging.info(
            f"Consumer `{self.conf_consumer['group.id']}` subscribed to topic(s): {', '.join(self.consumer_topic)}"
        )

        try:
            while not self.shutdown_event:
                self.producer.poll(1.0)
                msg = self.consumer.poll(1.0)
                if msg is not None:
                    if msg.error():
                        logging.error(f"Consumer error: {msg.error()}")
                    else:
                        value = self.avro_deserializer(
                            msg.value(),
                            SerializationContext(
                                msg.topic(),
                                MessageField.VALUE,
                            ),
                        )
                        value.update({"user_id": self.string_deserializer(msg.key())})
                        logging.info(f"Message from topic `{msg.topic()}`: {value}")
                        socketio.emit(
                            "kafka_message",
                            self.format_dict(value),
                        )
                else:
                    eventlet.sleep(0.1)

        except KafkaException as err:
            logging.error(f"Kafka exception: {err}")
        finally:
            logging.info("Closing Kafka consumer...")
            self.consumer.close()
            logging.info("Flushing Kafka producer...")
            self.producer.flush()

    def start_consumer_thread(self):
        """Using Eventlet’s GreenThread Instead of Threading - Let eventlet manage the thread"""
        self.thread = eventlet.spawn(self.kafka_consumer_thread)

    def stop_consumer(self):
        self.shutdown_event = True

    def signal_handler(self, sig, frame):
        logging.info(f"Received signal {sig}, shutting down...")
        self.stop_consumer()
        sys.exit(0)

    def format_dict(self, data):
        result = dict()
        for key, value in data.items():
            if isinstance(value, datetime):
                v = value.strftime("%Y-%m-%d %H:%M:%S.%f")[:-3]
            else:
                v = value
            result[key] = v
        return result


########
# Main #
########
if __name__ == "__main__":
    # Read Config File
    try:
        parser = argparse.ArgumentParser(
            description=f"Confluent Cloud - Fraud Prevention Demo"
        )
        parser.add_argument(
            "--config",
            help="Path to the config file",
            dest="config",
            type=str,
        )
        parser.add_argument(
            "--dummy",
            help="Generate dummy records",
            dest="dummy_records",
            type=int,
            default=0,
        )
        args = parser.parse_args()
        config = ConfigParser()
        config.read(args.config)
    except Exception as err:
        logging.error(err)
        help_output = io.StringIO()
        parser.print_help(file=help_output)
        logging.error(help_output.getvalue())
        sys.exit(-1)

    # Instance of the Kafka App class
    kafka_app = KafkaApp(dict(config))
    signal.signal(signal.SIGINT, kafka_app.signal_handler)
    signal.signal(signal.SIGTERM, kafka_app.signal_handler)

    # Submit dummy records (if any)
    # In Flink the first watermark is not emitted until the 250th record
    user_id_dummy = "----"
    message_dummy = {
        "transaction_id": None,
        "amount": None,
        "lat": 0,
        "lng": 0,
        "timestamp": 0,
    }
    for i in range(args.dummy_records):
        kafka_app.submit_event(
            user_id_dummy,
            message_dummy,
        )

    # Flask Routing
    @app.route("/")
    def index():
        return render_template("index.html")

    @app.route("/submit-event", methods=["POST"])
    def submit_coordinates():
        data = request.get_json()
        user_id = data.get("user_id")
        iso_timestamp = data.get("timestamp")
        dt = datetime.strptime(iso_timestamp, "%Y-%m-%dT%H:%M:%S.%fZ")
        dt = dt.replace(tzinfo=timezone.utc)
        message = {
            "transaction_id": data.get("transaction_id"),
            "amount": data.get("amount"),
            "lat": data.get("latitude"),
            "lng": data.get("longitude"),
            "timestamp": int(dt.timestamp() * 1000),
        }
        kafka_app.submit_event(
            user_id,
            message,
        )
        return jsonify({"success": True})

    # Start consumer thread
    kafka_app.start_consumer_thread()

    # Run Flask App
    try:
        logging.info("Starting Flask App...")
        socketio.run(
            app,
            host="localhost",
            port=8888,
            debug=False,
            use_reloader=False,
        )
    finally:
        logging.info("Bye bye!")
        kafka_app.thread.wait()
