# ------------------------------------------------------------------------------
# DEMO 1: Production Infrastructure Change Set (PR #2)
# Triggering Terraform SRE Safety Gate
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

# 2. 🔴 HIGH RISK: Security Group wide open to the public internet
# SRE Note: Both a standard IaC linter AND the AI agent should be unhappy about this one -
# an open CIDR is exactly the well-known misconfiguration static tooling is good at.
resource "aws_security_group" "app_ingress" {
  name        = "app-production-ingress"
  description = "Application tier security group"

  ingress {
    description = "HTTPS from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Open to the entire internet
  }

  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Administrative access exposed to the entire internet
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
  aliases             = ["api.company.com", "api-v2.company.com"] # Attached one more custom domain alias
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

# 4b. 🟢 LOW RISK (as the developer sees it): One more additive DNS alias for the CDN
# Dev Note: Purely additive, no existing DNS records are touched. Same shape as api_dns above.
# (This is the change the static analyzer approves and the AI agent overrules.)
resource "aws_route53_record" "api_v2_dns" {
  zone_id = "Z123456789ABC"
  name    = "api-v2.company.com"
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

# 6. 🟢 GENUINELY FINE: Ephemeral CI scratch bucket, no compliance claim
# SRE Note: A linter will still emit its standard S3 hardening findings here.
# The agent is expected to weigh them against context - non-production, no
# classification tags, no customer data - and NOT block the pipeline for it.
# This is the control case: proof the gate can say "this one is fine."
resource "aws_s3_bucket" "ci_scratch" {
  bucket = "company-ci-scratch-artifacts"

  tags = {
    Environment        = "test"
    DataClassification = "Public"
    Purpose            = "Ephemeral CI build artifacts, deleted after 7 days"
    Owner              = "Platform-CI"
  }
}

# 7. 🟡 WASTE: Elastic IP allocated but never associated with anything
# SRE Note: Not a security hole - nothing is exposed, nothing is at risk.
# It is simply billed hourly, forever, for doing nothing. Exactly the class of
# finding a security scanner has no opinion about and a finance team does.
resource "aws_eip" "orphaned_nat" {
  domain = "vpc"

  tags = {
    Environment = var.environment
    Owner       = "Network-Team"
    Purpose     = "Reserved for NAT gateway migration (never completed)"
  }
}
