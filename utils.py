import eventlet

eventlet.monkey_patch()

import sys
import json
import yaml
import socket
import logging

from flask import Flask
from datetime import datetime
from flask_socketio import SocketIO
from confluent_kafka import Producer, Consumer, KafkaException
from confluent_kafka.schema_registry import SchemaRegistryClient
from confluent_kafka.schema_registry.avro import AvroSerializer, AvroDeserializer
from confluent_kafka.serialization import (
    SerializationContext,
    StringSerializer,
    StringDeserializer,
    MessageField,
)


#####################
# Generic class #
#####################
class FlaskApp:
    def __init__(self):
        # Flask App / WebSocket (to broadcast the Kafka data consumed back to the front-end)
        self.app = Flask(
            __name__,
            static_folder="static",
            template_folder="templates",
        )
        self.socketio = SocketIO(
            self.app,
            cors_allowed_origins="*",
            async_mode="eventlet",
        )


class KafkaApp:
    """Main Kafka class for Producer and Consumer (consumer as a separate thread)"""

    def __init__(self, args, socketio):
        self.socketio = socketio
        self.shutdown_event = False

        # Get config from YAML file
        with open(args.config, "r") as f:
            config = yaml.safe_load(f.read())

        # Kafka topics
        self.card_transactions_topic = config["kafka-others"]["card_transactions.topic"][
            "name"
        ]
        self.users_config_topic = config["kafka-others"][
            "users_config.topic"
        ]["name"]
        self.card_transactions_enriched_topic = config["kafka-others"][
            "card_transactions_enriched.topic"
        ]["name"]

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

        # Schema Registry
        conf_schema_registry = dict(config["schema-registry"])
        self.schema_registry = SchemaRegistryClient(conf_schema_registry)

        # card_transactions
        ## Avro SerDes
        with open(config["kafka-others"]["card_transactions.topic"]["schema"], "r") as f:
            value_schema = json.loads(f.read())
        self.avro_serializer_fd = AvroSerializer(
            self.schema_registry,
            json.dumps(value_schema),
        )
        self.avro_deserializer_fd = AvroDeserializer(
            self.schema_registry,
        )

        # users_config
        ## Avro Ser
        with open(
            config["kafka-others"]["users_config.topic"]["schema"], "r"
        ) as f:
            value_schema = json.loads(f.read())
        self.avro_serializer_fdc = AvroSerializer(
            self.schema_registry,
            json.dumps(value_schema),
        )

        ## String SerDes
        self.string_serializer = StringSerializer("utf_8")
        self.string_deserializer = StringDeserializer("utf_8")

        # Submit dummy records (if any)
        # In Flink the first watermark is not emitted until the 250th record
        if args.dummy_records > 0:
            user_id_dummy = "----"
            message_dummy = {
                "transaction_id": None,
                "amount": None,
                "lat": 0,
                "lng": 0,
                "timestamp": 0,
            }
            for i in range(args.dummy_records):
                self.submit_event(
                    self.card_transactions_topic,
                    user_id_dummy,
                    message_dummy,
                    self.avro_serializer_fd,
                )

        # Upsert users
        self.users = dict()
        for key, value in config["users"].items():
            self.users[key] = value["first_name"] + " " + value["last_name"]
        if args.users:
            for key, value in config["users"].items():
                message = {
                    "first_name": value["first_name"],
                    "last_name": value["last_name"],
                    "max_speed": value["max_speed"],
                }
                self.submit_event(
                    self.users_config_topic,
                    key,
                    message,
                    self.avro_serializer_fdc,
                )

    def delivery_report(self, err, msg):
        if err is not None:
            logging.error(f"Message delivery failed -> {err}")
        elif msg is not None:
            logging.info(
                f"Message delivered to topic `{msg.topic()}`, partition #{msg.partition()} at offset #{msg.offset()}"
            )
        else:
            logging.error(f"Message delivery failed -> $err and $msg are null")

    def submit_event(self, topic, key, value, serialiser):
        """Publish message to Kafka"""
        self.producer.produce(
            topic=topic,
            key=self.string_serializer(key),
            value=serialiser(
                value,
                SerializationContext(
                    topic,
                    MessageField.VALUE,
                ),
            ),
            on_delivery=self.delivery_report,
        )

    def kafka_consumer_thread(self):
        """Consume Kafka messages and push/websock it to the front-end"""
        self.consumer.subscribe([self.card_transactions_enriched_topic])
        logging.info(
            f"Consumer `{self.conf_consumer['group.id']}` subscribed to topic: {self.card_transactions_enriched_topic}"
        )

        try:
            while not self.shutdown_event:
                self.producer.poll(1.0)
                msg = self.consumer.poll(1.0)
                if msg is not None:
                    if msg.error():
                        logging.error(f"Consumer error: {msg.error()}")
                    else:
                        value = self.avro_deserializer_fd(
                            msg.value(),
                            SerializationContext(
                                msg.topic(),
                                MessageField.VALUE,
                            ),
                        )
                        value.update({"user_id": self.string_deserializer(msg.key())})
                        logging.info(f"Message from topic `{msg.topic()}`: {value}")
                        self.socketio.emit(
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
