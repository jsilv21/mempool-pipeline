data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

resource "aws_security_group" "mempool_ec2" {
  name        = "${var.project_name}-ec2-sg"
  description = "Allow outbound HTTPS and DNS for mempool websocket + AWS APIs"
  vpc_id      = data.aws_vpc.default.id

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 53
    to_port     = 53
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-ec2-sg"
    Environment = var.environment
  }
}

resource "aws_cloudwatch_log_group" "mempool_ec2" {
  name              = "/${var.project_name}/${var.environment}/ec2"
  retention_in_days = 14
}

locals {
  mempool_ws_client = file("${path.module}/../src/ec2/mempool_ws_client.py")
  mempool_requirements = file("${path.module}/../src/ec2/requirements.txt")
}

resource "aws_instance" "mempool_ec2" {
  ami                         = data.aws_ami.amazon_linux_2023.id
  instance_type               = var.ec2_instance_type
  iam_instance_profile        = aws_iam_instance_profile.ec2_profile.name
  subnet_id                   = data.aws_subnets.default.ids[0]
  vpc_security_group_ids      = [aws_security_group.mempool_ec2.id]
  user_data_replace_on_change = true

  user_data = <<-EOF
              #!/bin/bash
              set -euo pipefail

              dnf install -y python3-pip amazon-cloudwatch-agent

              mkdir -p /opt/mempool
              cat > /opt/mempool/requirements.txt <<'REQ'
              ${local.mempool_requirements}
              REQ

              python3 -m venv /opt/mempool/venv
              /opt/mempool/venv/bin/pip install --no-cache-dir -r /opt/mempool/requirements.txt

              cat > /opt/mempool/mempool_ws_client.py <<'PY'
              ${local.mempool_ws_client}
              PY

              mkdir -p /etc/mempool
              cat > /etc/mempool/mempool.env <<'ENV'
              FIREHOSE_STREAM_NAME=${aws_kinesis_firehose_delivery_stream.mempool_firehose.name}
              LOG_LEVEL=INFO
              AWS_REGION=${var.aws_region}
              AWS_DEFAULT_REGION=${var.aws_region}
              MEMPOOL_TRACK_BLOCK=0
              ENV

              cat > /etc/systemd/system/mempool-ws.service <<'SERVICE'
              [Unit]
              Description=Mempool websocket client
              After=network-online.target
              Wants=network-online.target

              [Service]
              Type=simple
              User=ec2-user
              WorkingDirectory=/opt/mempool
              EnvironmentFile=/etc/mempool/mempool.env
              ExecStart=/opt/mempool/venv/bin/python /opt/mempool/mempool_ws_client.py
              Restart=always
              RestartSec=5
              StandardOutput=append:/var/log/mempool-ws.log
              StandardError=append:/var/log/mempool-ws.err.log

              [Install]
              WantedBy=multi-user.target
              SERVICE

              chown -R ec2-user:ec2-user /opt/mempool
              systemctl daemon-reload
              systemctl enable --now mempool-ws.service

              cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json <<'JSON'
              {
                "logs": {
                  "logs_collected": {
                    "files": {
                      "collect_list": [
                        {
                          "file_path": "/var/log/mempool-ws.log",
                          "log_group_name": "${aws_cloudwatch_log_group.mempool_ec2.name}",
                          "log_stream_name": "{instance_id}-stdout",
                          "timestamp_format": "%Y-%m-%d %H:%M:%S"
                        },
                        {
                          "file_path": "/var/log/mempool-ws.err.log",
                          "log_group_name": "${aws_cloudwatch_log_group.mempool_ec2.name}",
                          "log_stream_name": "{instance_id}-stderr",
                          "timestamp_format": "%Y-%m-%d %H:%M:%S"
                        }
                      ]
                    }
                  }
                }
              }
              JSON

              /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json -s
              EOF

  tags = {
    Name        = "${var.project_name}-ec2"
    Environment = var.environment
  }
}



