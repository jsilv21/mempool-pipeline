variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "mempool-pipeline"
}

variable "ec2_instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
}

variable "ec2_ami" {
  description = "EC2 AMI ID"
  type        = string
  default     = "ami-0c55b159cbfafe1f0" # need to update with proper AMI - TBD
}

variable "lambda_runtime" {
  description = "Lambda runtime"
  type        = string
  default     = "nodejs14.x"
}
