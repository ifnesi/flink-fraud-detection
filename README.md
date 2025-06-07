![image](docs/confluent-logo.png)

# Real-Time Fraud Detection using Confluent Cloud for Flink



## Overview

![image](docs/diagram.png)

## Pre-requisites
- User account on [Confluent Cloud](https://www.confluent.io/confluent-cloud/tryfree)
- Local install of [Terraform](https://www.terraform.io)
- Local install of [jq](https://jqlang.github.io/jq/download)

## Installation (only need to do that once)

### Install Terraform
```shell
brew tap hashicorp/tap
brew install hashicorp/tap/terraform
brew update
brew upgrade hashicorp/tap/terraform
```

### Install jq
```shell
brew install jq
```

### Python setup
```sh
python3 -m venv .venv
source .venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
deactivate
```

### Set environment variables
```sh
cat > ./.env <<EOF
#!/bin/bash
export CONFLUENT_CLOUD_API_KEY="<CONFLUENT_CLOUD_API_KEY>"
export CONFLUENT_CLOUD_API_SECRET="<CONFLUENT_CLOUD_API_SECRET>"
EOF
```

### Provision Confluent Cloud resources (Terraform)
```sh
terraform init
source .env
terraform plan
terraform apply --auto-approve
terraform output -json > tf_aws_data.json
./set_config.sh
```

### Start Web application
```sh
source .venv/bin/activate
python3 app.py --config ./config/tf_config.yml --users --dummy 250
```

![image](docs/app-main.png)

### Delete Confluent Cloud resources (Terraform)
```sh
deactivate
terraform destroy --auto-approve
```

## External References
Check out [Confluent's Developer portal](https://developer.confluent.io), it has free courses, documents, articles, blogs, podcasts and so many more content to get you up and running with a fully managed Apache Kafka service.

Disclaimer: I work for Confluent :wink:
