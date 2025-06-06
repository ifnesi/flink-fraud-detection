from utils import KafkaApp, FlaskApp

import io
import sys
import signal
import logging
import argparse

from flask import render_template, request, jsonify
from datetime import datetime, timezone


####################
# Global variables #
####################
# Set console logs
logging.basicConfig(
    level=logging.INFO,
    format="[%(levelname)s] %(asctime)s: %(message)s",
    handlers=[logging.StreamHandler()],
)

########
# Main #
########
if __name__ == "__main__":
    # This is the main Flask app that will be used to serve the front-end and handle WebSocket connections
    flask = FlaskApp()

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
        parser.add_argument(
            "--users",
            help="Upsert users as per configuration",
            dest="users",
            action="store_true",
        )
        args = parser.parse_args()
    except Exception as err:
        logging.error(err)
        help_output = io.StringIO()
        parser.print_help(file=help_output)
        logging.error(help_output.getvalue())
        sys.exit(-1)

    # Instance of the Kafka App class
    kafka_app = KafkaApp(args, flask.socketio)
    signal.signal(signal.SIGINT, kafka_app.signal_handler)
    signal.signal(signal.SIGTERM, kafka_app.signal_handler)

    # Flask Routing
    @flask.app.route("/")
    def index():
        return render_template("index.html")

    @flask.app.route("/submit-event", methods=["POST"])
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
            kafka_app.fraud_detection_topic,
            user_id,
            message,
            kafka_app.avro_serializer_fd,
        )
        return jsonify({"success": True})

    # Start consumer thread
    kafka_app.start_consumer_thread()

    # Run Flask App
    try:
        logging.info("Starting Flask App...")
        flask.socketio.run(
            flask.app,
            host="localhost",
            port=8888,
            debug=False,
            use_reloader=False,
        )
    finally:
        logging.info("Bye bye!")
        kafka_app.thread.wait()
