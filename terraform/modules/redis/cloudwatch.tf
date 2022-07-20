resource "aws_cloudwatch_log_group" "elastic_cloud_watch" {
  name = "${var.region}-${var.env}-redis-elastic-rpc-cloudwatch"

  retention_in_days = 14
}