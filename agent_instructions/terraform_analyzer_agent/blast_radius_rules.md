# Terraform Blast Radius & Risk Rules

This document outlines the heuristic scoring model used by the Terraform Analyzer Agent to evaluate change impact.

## Risk Classification Matrix

| Action Pattern | Target Resource Type | Risk Rating | Blast Radius | Pipeline Gate |
| :--- | :--- | :--- | :--- | :--- |
| `replace` (destroy then create) | Databases (`aws_db_instance`, `google_sql_*`), Storage (`aws_s3_bucket`, `aws_ebs_volume`) | 🔴 Critical | 9.0 - 10.0 | **BLOCK** |
| `delete` | Networking (VPC, Subnet, Route Table, NAT Gateway, Transit Gateway) | 🔴 Critical | 8.5 - 9.5 | **BLOCK** |
| `create` / `update` | Security Group with `0.0.0.0/0` on management ports (`22`, `3389`, `8080`, `2375`) | 🟠 High | 7.0 - 8.0 | **BLOCK / WARN** |
| `create` / `update` | IAM Policy granting `AdministratorAccess` or wildcard `*` actions | 🟠 High | 7.0 - 8.0 | **WARN** |
| `update` (in-place) | Compute instance type, container CPU/RAM allocations | 🟡 Medium | 4.0 - 6.0 | **APPROVE / WARN** |
| `create` | New isolated resources (e.g. new S3 bucket with encryption enabled) | 🟢 Low | 2.0 - 3.5 | **APPROVE** |
| `update` (in-place) | Tags, descriptions, metadata | 🟢 Minimal | 1.0 - 2.0 | **APPROVE** |

---

## Destructive Triggers in Terraform HCL

The agent specifically watches for changes to immutable attributes that force resource replacement:
1. `name` or `identifier` changes on stateful resources without `lifecycle.create_before_destroy`.
2. `engine` or `storage_type` migrations on RDS.
3. `allocated_storage` downgrades (shrink is unsupported by cloud providers, forcing recreation).
4. `availability_zone` changes without multi-AZ replication.
