terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.35.0"
    }
  }
}


provider "aws" {
  region = "us-east-1"
}

# S3 Bucket
resource "aws_s3_bucket" "app_bucket" {
  bucket = "ayeon78676kkyry9"
  

  
}

resource "aws_s3_bucket_versioning" "versioning_example" {
  bucket = aws_s3_bucket.app_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

# resource "aws_key_pair" "my_key_pair" {
#   key_name   = "project"  # Change to your desired key name
#   public_key = file("project.pub")  # Path to your public key file
# }

# resource "aws_s3_object" "app_zip" {
#   bucket = aws_s3_bucket.app_bucket.id
#   key    = "javaapp.zip"
#   source = "/home/ayeon/aws-devops/code-pipeline1" # Specify the local path to your zip file
# }
resource "aws_iam_instance_profile" "instance_profile" {
  name = "example-profile"
  role = aws_iam_role.instance_role.name
}
# IAM Role for EC2 Instance
resource "aws_iam_role" "instance_role" {
  name = "example-instance-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_policy" "deploy" {
  name        = "codedeploy-policy"
  description = "IAM policy for CodeDeploy EC2 instance"
  policy      = jsonencode({
    Version   = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Action    = [
          "s3:Get*",
          "s3:List*",
        ],
        Resource  = "*",
      },
      {
        Effect    = "Allow",
        Action    = [
          "codedeploy:*"
          
        ],
        Resource  = "*",
      },
    ],
  })
}


# Attach an inline policy to the EC2 instance role
resource "aws_iam_role_policy_attachment" "instance_policy_attachment" {
  role       = aws_iam_role.instance_role.name
  policy_arn = aws_iam_policy.deploy.arn
}

resource "null_resource" "create_host" {
  # ...

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    working_dir = "${path.module}"
    command = <<-EOT
      echo "" > hosts
      echo "[server]" >> hosts
    EOT
  }

  
}

resource "aws_security_group" "example" {
  name        = "example-security-group"
  description = "Allow inbound traffic on port 8080"
  
  // You can specify VPC settings here, such as vpc_id if needed
}

resource "aws_security_group_rule" "ingress_8080" {
  type              = "ingress"
  from_port         = 8080
  to_port           = 8080
  protocol          = "tcp"
  security_group_id = aws_security_group.example.id
  cidr_blocks       = ["0.0.0.0/0"]  # Allowing traffic from any IPv4 address. Adjust as needed.
}

resource "aws_security_group_rule" "ingress_22" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  security_group_id = aws_security_group.example.id
  cidr_blocks       = ["0.0.0.0/0"]  # Allowing traffic from any IPv4 address. Adjust as needed.
}

resource "aws_instance" "deploy" {
  # count         = 3
  iam_instance_profile = aws_iam_instance_profile.instance_profile.name
  ami                  = "ami-0c7217cdde317cfec" # Change this to your desired AMI
  instance_type        = "t2.micro"              # Change this to your desired instance type
  key_name             = "project"               # Change this to your key pair name
  tags = {
    name = "deploy"
  }

  security_groups = [aws_security_group.example.name]

  provisioner "local-exec" {
    # command = "echo ${self.p_ip} >> hosts"
    command = <<-EOT
      echo "" > hosts
      echo "[server]" >> hosts
      echo ${self.public_ip} >> hosts
      ansible-playbook -i hosts playbook.yml
    EOT
  }
}

# resource "null_resource" "ansible_provisioner" {
#   provisioner "local-exec" {
#     command = "ansible-playbook -i hosts playbook.yml"
    
# # Assuming your Ansible playbook is in a folder called 'ansible' 
# # within your Terraform module.
#   }
# }




resource "aws_s3_bucket" "codebuild" {
  bucket = "builder9kiu00999"
}

# resource "aws_s3_bucket_acl" "example" {
#   bucket = aws_s3_bucket.example.id
#   # acl    = "private"
# }



data "aws_iam_policy_document" "assume_role_codebuild" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "codebuild" {
  name               = "example"
  assume_role_policy = data.aws_iam_policy_document.assume_role_codebuild.json
}

data "aws_iam_policy_document" "example" {
  statement {
    effect = "Allow"

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]

    resources = ["*"]
  }

  statement {
    effect = "Allow"

    actions = [
      "ec2:CreateNetworkInterface",
      "ec2:DescribeDhcpOptions",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DeleteNetworkInterface",
      "ec2:DescribeSubnets",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeVpcs",
    ]

    resources = ["*"]
  }

  statement {
    effect    = "Allow"
    actions   = ["ec2:CreateNetworkInterfacePermission"]
    resources = ["arn:aws:ec2:us-east-1:123456789012:network-interface/*"]


  }

  statement {
    effect  = "Allow"
    actions = ["s3:*"]
    resources = [
      "*"
    ]
  }
}

resource "aws_iam_role_policy" "example" {
  role   = aws_iam_role.codebuild.name
  policy = data.aws_iam_policy_document.example.json
}

resource "aws_codebuild_project" "build" {
  name          = "testProject"
  description   = "test_codebuild_project"
  build_timeout = 5
  service_role  = aws_iam_role.codebuild.arn

    artifacts {
      type = "CODEPIPELINE"
    }

  cache {
    type     = "S3"
    location = aws_s3_bucket.codebuild.bucket
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux2-x86_64-standard:4.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"

    # environment_variable {
    #   name  = "SOME_KEY1"
    #   value = "SOME_VALUE1"
    # }

    # environment_variable {
    #   name  = "SOME_KEY2"
    #   value = "SOME_VALUE2"
    #   type  = "PARAMETER_STORE"
    # }
  }

  logs_config {
    cloudwatch_logs {
      group_name  = "log-group"
      stream_name = "log-stream"
    }

    s3_logs {
      status   = "ENABLED"
      location = "${aws_s3_bucket.codebuild.id}/build-log"
    }
  }

    source {
      type            = "CODEPIPELINE"
      # location        = "https://github.com/mitchellh/packer.git"
      # git_clone_depth = 1

      # git_submodules_config {
      #   fetch_submodules = true
      # }
    }

  #   source_version = "master"

  #   vpc_config {
  #     vpc_id = aws_vpc.example.id

  #     subnets = [
  #       aws_subnet.example1.id,
  #       aws_subnet.example2.id,
  #     ]

  #     security_group_ids = [
  #       aws_security_group.example1.id,
  #       aws_security_group.example2.id,
  #     ]
  #   }

  tags = {
    Environment = "Test"
  }
}

resource "aws_codedeploy_app" "deploy_app" {
  compute_platform = "Server"
  name             = "deploy_app"
}

data "aws_iam_policy_document" "assume_role_codedeploy" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["codedeploy.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "codedeploy" {
  name               = "example-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role_codedeploy.json
}

resource "aws_iam_role_policy_attachment" "AWSCodeDeployRole" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSCodeDeployRole"
  role       = aws_iam_role.codedeploy.name
}

# resource "aws_codedeploy_app" "deploy_app" {
#   name = "example-app"
# }

resource "aws_sns_topic" "example" {
  name = "example-topic"
}

resource "aws_codedeploy_deployment_group" "deploy_group" {
  app_name              = aws_codedeploy_app.deploy_app.name
  deployment_group_name = "example-group"
  service_role_arn      = aws_iam_role.codedeploy.arn

  ec2_tag_set {
    ec2_tag_filter {
      key   = "name"
      type  = "KEY_AND_VALUE"
      value = "deploy"
    }

    ec2_tag_filter {
      key   = "filterkey2"
      type  = "KEY_AND_VALUE"
      value = "filtervalue"
    }
  }

  trigger_configuration {
    trigger_events     = ["DeploymentFailure"]
    trigger_name       = "example-trigger"
    trigger_target_arn = aws_sns_topic.example.arn
  }

  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }

  alarm_configuration {
    alarms  = ["my-alarm-name"]
    enabled = true
  }

  outdated_instances_strategy = "UPDATE"

}

resource "aws_codepipeline" "codepipeline" {
  name     = "tf-test-pipeline"
  role_arn = aws_iam_role.codepipeline_role.arn

  artifact_store {
    location = aws_s3_bucket.codepipeline_bucket.bucket
    type     = "S3"

    # encryption_key {
    #   id   = data.aws_kms_alias.s3kmskey.arn
    #   type = "KMS"
    # }
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "S3"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        S3Bucket    = aws_s3_bucket.app_bucket.id
        S3ObjectKey = "javaapp.zip"

      }
    }
  }

  stage {
    name = "Build"

    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]
      version          = "1"

      configuration = {
        ProjectName = "testProject" 
      }
    }
  }

  stage {
    name = "Deploy"

    action {
      name            = "Deploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "CodeDeploy"
      input_artifacts = ["build_output"]
      version         = "1"

      configuration = {
        ApplicationName     = "deploy_app"
        DeploymentGroupName = "example-group"

      }
    }
  }
}



resource "aws_s3_bucket" "codepipeline_bucket" {
  bucket = "pipeline-bucketllo888"
}

# resource "aws_s3_bucket_public_access_block" "codepipeline_bucket_pab" {
#   bucket = aws_s3_bucket.codepipeline_bucket.id

#   # block_public_acls       = true
#   # block_public_policy     = true
#   # ignore_public_acls      = true
#   # restrict_public_buckets = true
# }

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["codepipeline.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "codepipeline_role" {
  name               = "test-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

data "aws_iam_policy_document" "codepipeline_policy" {
  statement {
    effect = "Allow"

    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:GetBucketVersioning",
      "s3:PutObjectAcl",
      "s3:PutObject",
    ]

    resources = [
      "*"
    ]
  }

  # statement {
  #   effect    = "Allow"
  #   actions   = ["codestar-connections:UseConnection"]
  #   resources = [aws_codestarconnections_connection.example.arn]
  # }

  statement {
    effect = "Allow"

    actions = [
      "codebuild:BatchGetBuilds",
      "codebuild:StartBuild",
      "codedeploy:*"
    ]

    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "codepipeline_policy" {
  name   = "codepipeline_policy"
  role   = aws_iam_role.codepipeline_role.id
  policy = data.aws_iam_policy_document.codepipeline_policy.json
}

# data "aws_kms_alias" "s3kmskey" {
#   name = "alias/myKmsKey"
# }