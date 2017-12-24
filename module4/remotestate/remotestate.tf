##################################################################################
# VARIABLES
##################################################################################

variable "aws_access_key" {}
variable "aws_secret_key" {}

variable "aws_networking_bucket" {
  default = "ddt-networking"
}

variable "aws_application_bucket" {
  default = "ddt-application"
}

variable "aws_dynamodb_table" {
  default = "ddt-tfstatelock"
}

variable "user_home_path" {}

##################################################################################
# PROVIDERS
##################################################################################

provider "aws" {
  access_key = "${var.aws_access_key}"
  secret_key = "${var.aws_secret_key}"
  region     = "us-west-2"
}

data "aws_iam_group" "ec2admin" {
  group_name = "EC2Admin"
}

##################################################################################
# RESOURCES
##################################################################################
data "template_file" "application_bucket_policy" {
  template = "${file("templates/bucket_policy.tpl")}"

  vars {
    read_only_user_arn   = "${aws_iam_user.marymoe.arn}"
    full_access_user_arn = "${aws_iam_user.sallysue.arn}"
    s3_bucket            = "${var.aws_application_bucket}"
  }
}

data "template_file" "network_bucket_policy" {
  template = "${file("templates/bucket_policy.tpl")}"

  vars {
    read_only_user_arn   = "${aws_iam_user.sallysue.arn}"
    full_access_user_arn = "${aws_iam_user.marymoe.arn}"
    s3_bucket            = "${var.aws_networking_bucket}"
  }
}

data "template_file" "mary_moe_policy" {
  template = "${file("templates/user_policy.tpl")}"

  vars {
    s3_bucket          = "${var.aws_networking_bucket}"
    dynamodb_table_arn = "${aws_dynamodb_table.terraform_statelock.arn}"
  }
}

data "template_file" "sally_sue_policy" {
  template = "${file("templates/user_policy.tpl")}"

  vars {
    s3_bucket          = "${var.aws_application_bucket}"
    dynamodb_table_arn = "${aws_dynamodb_table.terraform_statelock.arn}"
  }
}

resource "aws_dynamodb_table" "terraform_statelock" {
  name           = "${var.aws_dynamodb_table}"
  read_capacity  = 20
  write_capacity = 20
  hash_key       = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}

resource "aws_s3_bucket" "ddtnet" {
  bucket        = "${var.aws_networking_bucket}"
  acl           = "private"
  force_destroy = true

  versioning {
    enabled = true
  }

  policy = "${data.template_file.network_bucket_policy.rendered}"
}

resource "aws_s3_bucket" "ddtapp" {
  bucket        = "${var.aws_application_bucket}"
  acl           = "private"
  force_destroy = true

  versioning {
    enabled = true
  }

  policy = "${data.template_file.application_bucket_policy.rendered}"
}

resource "aws_iam_user" "sallysue" {
  name = "sallysue"
}

resource "aws_iam_user_policy" "sallysue_rw" {
  name = "sallysue"
  user = "${aws_iam_user.sallysue.name}"

  policy = "${data.template_file.sally_sue_policy.rendered}"
}

resource "aws_iam_user" "marymoe" {
  name = "marymoe"
}

resource "aws_iam_access_key" "marymoe" {
  user = "${aws_iam_user.marymoe.name}"
}

resource "aws_iam_user_policy" "marymoe_rw" {
  name = "marymoe"
  user = "${aws_iam_user.marymoe.name}"

  policy = "${data.template_file.mary_moe_policy.rendered}"
}

resource "aws_iam_access_key" "sallysue" {
  user = "${aws_iam_user.sallysue.name}"
}

resource "aws_iam_group_membership" "addsally" {
  name = "add-sally"

  users = [
    "${aws_iam_user.sallysue.name}"
  ]

  group = "EC2Admin"
}

resource "local_file" "aws_keys" {
  content = <<EOF
[default]
aws_access_key_id = ${var.aws_access_key}
aws_secret_access_key = ${var.aws_secret_key}

[sallysue]
aws_access_key_id = ${aws_iam_access_key.sallysue.id}
aws_secret_access_key = ${aws_iam_access_key.sallysue.secret}

[marymoe]
aws_access_key_id = ${aws_iam_access_key.marymoe.id}
aws_secret_access_key = ${aws_iam_access_key.marymoe.secret}

EOF

  filename = "${var.user_home_path}/.aws/credentials"
}

##################################################################################
# OUTPUT
##################################################################################