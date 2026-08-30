# ------------------------------------------------------------------------------
# DEMO SCENARIO: A developer submitted a PR modifying the database identifier
# and adding an admin SSH security group rule.
# ------------------------------------------------------------------------------

# Critical Data Store: Changing 'identifier' forces full database replacement!
resource "aws_db_instance" "production_db" {
  identifier          = "production-customer-db-v2" # Renamed from v1 -> FORCES REPLACEMENT
  allocated_storage   = var.db_allocated_storage
  engine              = "postgres"
  engine_version      = "15.4"
  instance_class      = "db.t3.medium"
  username            = "dbadmin"
  password            = "SuperSecurePassword123!" # Hardcoded demo password (triggers security warning)
  skip_final_snapshot = true                      # Dangerous: skips snapshot on destruction!

  tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# High Risk Security Group: Ingress open to entire public internet on port 22
resource "aws_security_group" "allow_ssh" {
  name        = "allow_ssh_from_internet"
  description = "Temporary debug SSH rule added by developer"

  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # HIGH RISK: Open to whole world
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Environment = var.environment
  }
}

# Standard Safe Resource: New S3 bucket
resource "aws_s3_bucket" "data_lake" {
  bucket = "company-production-data-lake-raw"

  tags = {
    Environment = var.environment
    DataClass   = "Confidential"
  }
}
