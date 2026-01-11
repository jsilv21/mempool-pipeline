resource "aws_instance" "mempool_ec2" {
  ami           = var.ec2_ami
  instance_type = var.ec2_instance_type

  tags = {
    Name        = "${var.project_name}-ec2"
    Environment = var.environment
  }
}
