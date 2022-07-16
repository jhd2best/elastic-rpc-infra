# setup the IAM role for the EC2 instances

resource "aws_iam_role" "nomad" {
  name               = "${var.cluster_id}-${var.region}-role"
  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [{
        "Action": "sts:AssumeRole",
        "Principal": {
            "Service": "ec2.amazonaws.com"
        },
        "Effect": "Allow",
        "Sid": ""
    }]
}
EOF
}

resource "aws_iam_policy" "nomad" {
  name   = "${var.cluster_id}-nomad-policy"
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [{
        "Effect": "Allow",
        "Action": [
            "ec2:AttachVolume",
            "ec2:DetachVolume",
            "ec2:Describe*",
            "elasticloadbalancing:Describe*",
            "cloudwatch:ListMetrics",
            "cloudwatch:GetMetricStatistics",
            "cloudwatch:Describe*",
            "autoscaling:Describe*",
            "elasticfilesystem:ClientMount",
            "elasticfilesystem:ClientRootAccess",
            "elasticfilesystem:ClientWrite",
            "elasticfilesystem:DescribeMountTargets",
            "autoscaling:UpdateAutoScalingGroup",
            "autoscaling:DescribeScalingActivities",
            "autoscaling:DescribeAutoScalingGroups",
            "autoscaling:CreateOrUpdateTags",
            "autoscaling:TerminateInstanceInAutoScalingGroup"
        ],
        "Resource": "*"
    }]
}
EOF
}

resource "aws_iam_role_policy_attachment" "nomad" {
  role       = aws_iam_role.nomad.name
  policy_arn = aws_iam_policy.nomad.arn
}

resource "aws_iam_instance_profile" "nomad" {
  name = "${var.cluster_id}-nomad-ip"
  role = aws_iam_role.nomad.name
}
