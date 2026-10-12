terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# ---------------------------------------------------------------------------
# Security groups: only app-sg may reach the database
# ---------------------------------------------------------------------------
resource "aws_security_group" "app" {
  name        = "${var.project_name}-app-sg"
  description = "Placeholder app-tier security group — attach this to any instance that needs DB access."
  vpc_id      = data.aws_vpc.default.id

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-app-sg"
  }
}

resource "aws_security_group" "rds" {
  name        = "${var.project_name}-rds-sg"
  description = "Allows MySQL (3306) only from the app tier security group — never 0.0.0.0/0."
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description     = "MySQL from app tier only"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-rds-sg"
  }
}

# ---------------------------------------------------------------------------
# DB subnet group — spans 2 AZs, required even for single-AZ RDS
# ---------------------------------------------------------------------------
resource "aws_db_subnet_group" "this" {
  name       = "${var.project_name}-subnet-group"
  subnet_ids = slice(data.aws_subnets.default.ids, 0, 2)

  tags = {
    Name = "${var.project_name}-subnet-group"
  }
}

# ---------------------------------------------------------------------------
# RDS instance — credentials managed entirely by AWS Secrets Manager
# ---------------------------------------------------------------------------
resource "aws_db_instance" "this" {
  identifier     = "${var.project_name}-mysql"
  engine         = "mysql"
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage = var.allocated_storage_gb
  storage_type       = "gp3"
  storage_encrypted  = true

  db_name  = "labdb"
  username = var.master_username
  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false

  multi_az                = var.multi_az
  backup_retention_period = var.backup_retention_days
  backup_window            = "03:00-04:00"
  maintenance_window       = "sun:04:30-sun:05:30"

  deletion_protection = false
  skip_final_snapshot  = true

  tags = {
    Name = "${var.project_name}-mysql"
  }
}
