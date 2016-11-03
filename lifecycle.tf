variable "access_key" {}
variable "secret_key" {}
variable "region" {}
variable "ami" {}
variable "key_name" {}
variable "az" {}
variable "security_groups" {}
variable "subnets" {}
variable "subnet" {}
variable "instance_type" {}

provider "aws" {
  access_key = "${var.access_key}"
  secret_key = "${var.secret_key}"
  region = "${var.region}"
}

resource "aws_sns_topic" "test" {
  name = "test"
}

resource "aws_iam_role" "test_sns" {
  name = "test_sns"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "autoscaling.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role" "test" {
  name = "test"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_policy" "test" {
  name = "test"
  path = "/"
  description = "test"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "ec2:Describe*"
      ],
      "Effect": "Allow",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "sns:*",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "sqs:*",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_policy_attachment" "test" {
  name = "test"
  roles = ["${aws_iam_role.test.name}", "${aws_iam_role.test_sns.name}"]
  policy_arn = "${aws_iam_policy.test.arn}"
}

resource "aws_iam_instance_profile" "test" {
  name = "test"
  roles = [
    "${aws_iam_role.test.name}"
  ]
}

resource "aws_launch_configuration" "test" {
  name = "test"
  image_id = "${var.ami}"
  instance_type = "${var.instance_type}"
  spot_price = "0.5"

  lifecycle {
    create_before_destroy = true
  }

  key_name = "${var.key_name}"
  iam_instance_profile = "test"
  security_groups = ["${var.security_groups}"]
  user_data = "${file("test_userdata.sh")}"

  root_block_device {
    volume_size = "1500"
    volume_type = "gp2"
  }

}

resource "aws_autoscaling_lifecycle_hook" "test_scale_up" {
    name = "test_scale_up"
    autoscaling_group_name = "${aws_autoscaling_group.test.name}"
    default_result = "CONTINUE"
    heartbeat_timeout = 300
    lifecycle_transition = "autoscaling:EC2_INSTANCE_LAUNCHING"
    notification_target_arn = "${aws_sns_topic.test.arn}"
    role_arn = "${aws_iam_role.test_sns.arn}"
}

resource "aws_autoscaling_lifecycle_hook" "test_scale_down" {
    name = "test_scale_down"
    autoscaling_group_name = "${aws_autoscaling_group.test.name}"
    default_result = "CONTINUE"
    heartbeat_timeout = 300
    lifecycle_transition = "autoscaling:EC2_INSTANCE_TERMINATING"
    notification_target_arn = "${aws_sns_topic.test.arn}"
    role_arn = "${aws_iam_role.test_sns.arn}"
}

resource "aws_autoscaling_group" "test" {
  name = "test"
  availability_zones = ["${var.az}"]
  vpc_zone_identifier = ["${var.subnet}"]
  min_size = "0"
  max_size = "0"
  desired_capacity = "0"
  wait_for_capacity_timeout = "10m"
  launch_configuration = "${aws_launch_configuration.test.name}"

  lifecycle {
    create_before_destroy = true
  }

  tag {
    key = "Name"
    value = "Test"
    propagate_at_launch = true
  }

  tag {
    key = "Purpose"
    value = "Test"
    propagate_at_launch = true
  }

}

resource "aws_iam_policy_attachment" "test_lambda" {
  name = "test"
  roles = ["${aws_iam_role.test_lambda.name}"]
  policy_arn = "${aws_iam_policy.test_lambda.arn}"
}

resource "aws_iam_role" "test_lambda" {
  name = "test_lambda"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_policy" "test_lambda" {
  name = "test_lambda"
  path = "/"
  description = "test_lambda"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:DescribeInstances",
        "ec2:CreateNetworkInterface",
        "ec2:AttachNetworkInterface",
        "ec2:DescribeNetworkInterfaces"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "sns:*",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "sqs:*",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_lambda_permission" "sns" {
  statement_id = "AllowExecutionFromSNS"
  action = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.test_lambda.arn}"
  principal = "sns.amazonaws.com"
  source_arn = "${aws_sns_topic.test.arn}"
}

resource "aws_sns_topic_subscription" "test_lambda" {
  topic_arn = "${aws_sns_topic.test.arn}"
  protocol  = "lambda"
  endpoint  = "${aws_lambda_function.test_lambda.arn}"
}

resource "aws_lambda_function" "test_lambda" {
  filename = "test_lambda.zip"
  function_name = "test_lambda"
  role = "${aws_iam_role.test_lambda.arn}"
  handler = "index.handler"
  vpc_config = {
    subnet_ids = ["${var.subnets}"]
    security_group_ids = ["${var.security_groups}"]
  }
  source_code_hash = "${base64sha256(file("test_lambda.zip"))}"
}

output "topic_arn" {
  value = "${aws_sns_topic.test.arn}"
}
