# ------------------------------------------------------------------------------
# DEMO 1: Production Infrastructure Change Set (PR #1)
# Demonstrates rich change diversity: Critical Destruction, Security Tightening,
# CloudFront Distribution Updates, DNS Records, and Safe Metadata Tagging.
# ------------------------------------------------------------------------------

# 1. 🔴 CRITICAL RISK: Changing 'identifier' forces full database drop & recreation!
resource "aws_db_instance" "production_db" {
  identifier          = "production-customer-db-v2" # Renamed from v1 -> FORCES DESTRUCTION
  allocated_storage   = var.db_allocated_storage
  engine              = "postgres"
  engine_version      = "15.4"
  instance_class      = "db.t3.medium"
  username            = "dbadmin"
  password            = "SuperSecurePassword123!" # Hardcoded demo credential
  skip_final_snapshot = true                      # Dangerous: no backup on destruction

  tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = "Customer360"
  }
}

# 2. 🟡 WARN / CAUTION: Security Group Tightening (Restricting from 0.0.0.0/0 to internal VPC)
# SRE Note: Good security practice, but verify no legitimate external clients get blocked!
resource "aws_security_group" "app_ingress" {
  name        = "app-production-ingress"
  description = "Application tier security group - restricted to corporate VPC"

  ingress {
    description = "HTTPS from internal corporate VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"] # Tightened from 0.0.0.0/0
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Environment = var.environment
    SecurityTier = "Restricted"
  }
}

# 3. 🟡 MEDIUM RISK: CloudFront Distribution Domain & Alias Update
# SRE Note: Global edge propagation takes ~5-15 minutes; verify ACM SSL cert binding.
resource "aws_cloudfront_distribution" "cdn" {
  enabled             = true
  aliases             = ["api.company.com"] # Added custom domain alias
  price_class         = "PriceClass_100"
  default_root_object = "index.html"

  origin {
    domain_name = "company-production-data-lake-raw.s3.amazonaws.com"
    origin_id   = "S3-DataLakeOrigin"
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "S3-DataLakeOrigin"
    viewer_protocol_policy = "redirect-to-https"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = false
    acm_certificate_arn            = "arn:aws:acm:us-east-1:123456789012:certificate/abc-123"
    ssl_support_method             = "sni-only"
  }

  tags = {
    Environment = var.environment
    Service     = "EdgeGateway"
  }
}

# 4. 🟢 LOW RISK: New Route53 DNS Alias Record for CloudFront
# SRE Note: Safe additive resource, zero impact on existing DNS entries.
resource "aws_route53_record" "api_dns" {
  zone_id = "Z123456789ABC"
  name    = "api.company.com"
  type    = "A"

  alias {
    name                   = "d111111abcdef8.cloudfront.net"
    zone_id                = "Z2FDTNDATAQYW2" # Standard CloudFront hosted zone
    evaluate_target_health = false
  }
}

# 5. 🟢 SAFE / METADATA ONLY: Adding Cost & Governance Tags to existing S3 Bucket
# SRE Note: In-place metadata change, 100% zero downtime, zero blast radius.
resource "aws_s3_bucket" "data_lake" {
  bucket = "company-production-data-lake-raw"

  tags = {
    Environment        = var.environment
    DataClassification = "Confidential"
    CostCenter         = "Data-Analytics-402"
    Owner              = "DataOps-Team"
    ComplianceScope    = "SOC2-Type2"
  }
}
