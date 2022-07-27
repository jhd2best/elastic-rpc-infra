data "aws_iam_role" "smm-role" {
  name = "SSM-instance-role"
}

resource "aws_iam_instance_profile" "smm-role" {
  name = "${var.cluster_name}-smm-role"
  role = data.aws_iam_role.smm-role.name
}