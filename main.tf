provider "aws" {
  region = "us-east-1"
}

# -----------------------------
# KMS Key for EBS Encryption
# -----------------------------
resource "aws_kms_key" "ebs_key" {
  description             = "KMS key for EBS encryption"
  deletion_window_in_days = 10
  enable_key_rotation     = true
}

# -----------------------------
# Security Group
# -----------------------------
resource "aws_security_group" "secure_sg" {
  name        = "secure-ec2-sg"
  description = "Allow SSH from my IP and HTTPS outbound only"

  ingress {
    description = "Allow SSH from my public IP only"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["154.209.252.179/32"]  # Replace with your IP
  }

  egress {
    description = "Allow HTTPS outbound to internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "secure-ec2-sg"
  }
}

# -----------------------------
# Encrypted EBS Volume
# -----------------------------
resource "aws_ebs_volume" "encrypted_volume" {
  availability_zone = "us-east-1a"
  size              = 10
  type              = "gp3"
  encrypted         = true
  kms_key_id        = aws_kms_key.ebs_key.arn

  tags = {
    Name = "encrypted-ebs-volume"
  }
}

# -----------------------------
# EC2 Instance
# -----------------------------
resource "aws_instance" "secure_ec2" {
  ami                    = "ami-0c02fb55956c7d316" # Amazon Linux 2
  instance_type          = "t2.micro"
  key_name               = "week-3"
  vpc_security_group_ids = [aws_security_group.secure_sg.id]
  monitoring             = true
  availability_zone      = "us-east-1a"

  # 🔐 Enforce IMDSv2
  metadata_options {
    http_tokens = "required"
  }

  # 🔐 Encrypted Root Volume with Customer KMS
  root_block_device {
    encrypted   = true
    volume_size = 8
    volume_type = "gp3"
    kms_key_id  = aws_kms_key.ebs_key.arn
  }

  tags = {
    Name = "secure-ec2-instance"
  }
}

# -----------------------------
# Attach EBS Volume to EC2
# -----------------------------
resource "aws_volume_attachment" "attach_ebs" {
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.encrypted_volume.id
  instance_id = aws_instance.secure_ec2.id
}