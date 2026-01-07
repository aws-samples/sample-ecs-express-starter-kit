resource "random_password" "db_password" {
  length  = var.password_length
  special = true
  override_special = "!#$%&*()-_=+[]{}<>:?"

}

resource "aws_secretsmanager_secret" "db_password" {
  name = "ecs-express-db-credentials"
  # this is to makes ure that tf destroy doesnt keep the secret in deleted state for 7 days. use with caution in prod though
  recovery_window_in_days = 0
  tags = local.common_tags
}

resource "aws_secretsmanager_secret_version" "db_password_version" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = random_password.db_password.result
  # secret_string = jsonencode({
  #   username = var.db_username
  #   password = random_password.db_password.result
  # })
}

resource "aws_db_subnet_group" "aurora" {
  name       = "ecs-express-aurora-subnet-group"
  subnet_ids = aws_subnet.private[*].id
  tags       = local.common_tags
}

resource "aws_rds_cluster" "aurora_serverless" {
  cluster_identifier      = "ecs-express-aurora-serverless"
  engine                 = "aurora-postgresql"
  engine_mode            = "provisioned"
  master_username        = var.db_username
  master_password        = random_password.db_password.result
  database_name          = var.db_name
  skip_final_snapshot     = true
  db_subnet_group_name    = aws_db_subnet_group.aurora.name
  vpc_security_group_ids  = [aws_security_group.db.id]

  serverlessv2_scaling_configuration {
    min_capacity           = 0
    max_capacity           = 2
    seconds_until_auto_pause = 300
  }

  tags = local.common_tags

}

resource "aws_rds_cluster_instance" "aurora_serverless" {
  count                = 1
  identifier           = "${aws_rds_cluster.aurora_serverless.cluster_identifier}-${count.index}"
  cluster_identifier   = aws_rds_cluster.aurora_serverless.id
  engine               = aws_rds_cluster.aurora_serverless.engine
  engine_version       = aws_rds_cluster.aurora_serverless.engine_version
  
  instance_class       = "db.serverless"
  
  # disable ehanced monitoring
  monitoring_interval  = 0

  tags = local.common_tags
}