resource "aws_s3_bucket" "cicd" {
  bucket        = "${var.project}-${var.aws_account_id}-${var.region}-${local.environment}-${var.component}-cicd-artifacts"
  force_destroy = "false"

  tags = {
    Name = "Terraform State File Bucket for account ${var.aws_account_id} in region ${var.region}"
  }
}

resource "aws_s3_bucket_public_access_block" "cicd" {
  bucket                  = aws_s3_bucket.cicd.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cicd" {
  bucket = aws_s3_bucket.cicd.bucket

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.cicd.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_versioning" "cicd" {
  bucket = aws_s3_bucket.cicd.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "cicd" {
  bucket                = aws_s3_bucket.cicd.id
  expected_bucket_owner = var.aws_account_id

  rule {
    id     = "default"
    status = "Enabled"

    filter {
      prefix = ""
    }

    noncurrent_version_transition {
      noncurrent_days = "30"
      storage_class   = "STANDARD_IA"
    }

    noncurrent_version_transition {
      noncurrent_days = "60"
      storage_class   = "GLACIER"
    }

    noncurrent_version_expiration {
      noncurrent_days = "90"
    }
  }
}

resource "aws_s3_bucket_policy" "cicd" {
  bucket = aws_s3_bucket.cicd.id
  policy = data.aws_iam_policy_document.cicd_bucket_policy.json

  depends_on = [
    aws_s3_bucket_public_access_block.cicd,
  ]
}

data "aws_iam_policy_document" "cicd_bucket_policy" {
  statement {
    sid    = "DontAllowNonSecureConnection"
    effect = "Deny"
    actions = [
      "s3:*",
    ]
    resources = [
      aws_s3_bucket.cicd.arn,
      "${aws_s3_bucket.cicd.arn}/*",
    ]
    principals {
      type = "AWS"
      identifiers = [
        "*",
      ]
    }
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values = [
        "false",
      ]
    }
  }

  statement {
    sid    = "AllowLocalPrincipalsToList"
    effect = "Allow"
    actions = [
      "s3:ListBucket",
    ]
    resources = [
      aws_s3_bucket.cicd.arn,
    ]
    principals {
      type = "AWS"
      identifiers = [
        "arn:aws:iam::${var.aws_account_id}:root"
      ]
    }
  }

  statement {
    sid    = "AllowLocalPrincipalsToGet"
    effect = "Allow"
    actions = [
      "s3:GetObject",
    ]
    resources = [
      "${aws_s3_bucket.cicd.arn}/*",
    ]
    principals {
      type = "AWS"
      identifiers = [
        "arn:aws:iam::${var.aws_account_id}:root"
      ]
    }
  }
}
