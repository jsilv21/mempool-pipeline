resource "aws_instance" "mempool_ec2" {
  ami           = data.aws_ami.amazon_linux_2023.id
  instance_type = var.ec2_instance_type
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name

  tags = {
    Name        = "${var.project_name}-ec2"
    Environment = var.environment
  }
}
