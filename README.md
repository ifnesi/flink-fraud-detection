![image](docs/confluent-logo.png)

# flink-fraud-detection
Real-Time Fraud Detection using Confluent Cloud for Flink

THIS IS A WORK IN PROGRESS!!!

```sh
python3 -m venv .venv
source .venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
```

```sh
cat > ./.env <<EOF
#!/bin/bash
export CONFLUENT_CLOUD_API_KEY="<CONFLUENT_CLOUD_API_KEY>"
export CONFLUENT_CLOUD_API_SECRET="<CONFLUENT_CLOUD_API_SECRET>"
EOF
```

```sh
terraform init
source .env
terraform plan
terraform apply --auto-approve
terraform output -json > tf_aws_data.json
```

![image](docs/london-paris.png)

## External References
Check out [Confluent's Developer portal](https://developer.confluent.io), it has free courses, documents, articles, blogs, podcasts and so many more content to get you up and running with a fully managed Apache Kafka service.

Disclaimer: I work for Confluent :wink:
