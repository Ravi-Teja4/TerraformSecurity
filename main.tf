provider "aws" {
  region = "us-east-1"
}

# -----------------------------
# Get Current Account ID
# -----------------------------
data "aws_caller_identity" "current" {}

# -----------------------------
# KMS Key with Proper Policy
# -----------------------------
resource "aws_kms_key" "ebs_key" {
  description             = "KMS key for EBS encryption"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowAccountRootFullAccess"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      }
    ]
  })
}

# -----------------------------
# IAM Role for EC2
# -----------------------------
resource "aws_iam_role" "ec2_role" {
  name = "secure-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "secure-ec2-profile"
  role = aws_iam_role.ec2_role.name
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
    cidr_blocks = ["154.209.252.179/32"]
  }

  egress {
    description = "Allow HTTPS outbound only"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# -----------------------------
# EC2 Instance
# -----------------------------
resource "aws_instance" "secure_ec2" {
  ami                    = "ami-0c02fb55956c7d316"
  instance_type          = "t3.micro"
  key_name               = "week-3"
  vpc_security_group_ids = [aws_security_group.secure_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  monitoring             = true
  ebs_optimized          = true
  availability_zone      = "us-east-1a"

  metadata_options {
    http_tokens = "required"
  }

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
