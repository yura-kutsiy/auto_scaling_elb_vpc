provider "aws" {
  region = var.region
}

data "aws_availability_zones" "available" {}
data "aws_region" "current" {}

data "aws_ami" "latest_ubuntu" {
  owners      = ["099720109477"]
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
}

resource "aws_security_group" "server" {
  name        = "server_security_group"
  description = "open  ports for Nginx"
  vpc_id      = aws_vpc.main.id

  dynamic "ingress" {
    for_each = var.allow_ports
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = merge(var.all_tags, { Name = "${var.all_tags["Environment"]} Nginx Security_group" })
}

resource "aws_launch_configuration" "server" {
  name_prefix = "Nginx-instance-"

  image_id        = data.aws_ami.latest_ubuntu.id
  instance_type   = var.instance_type
  security_groups = [aws_security_group.server.id]
  user_data       = file("server.sh")
  key_name        = "aws-key-Frankfurt"

  associate_public_ip_address = true

  lifecycle {
    create_before_destroy = true
  }
  #tag = merge(var.all_tags, { Name = "${var.all_tags["Environment"]} Webserver" })
}

resource "aws_autoscaling_group" "server" {
  name = "Nginx-AutoScaling-${aws_launch_configuration.server.name}"

  desired_capacity = 2
  min_size         = 1
  max_size         = 5

  launch_configuration = aws_launch_configuration.server.id
  load_balancers       = [aws_elb.server.name]
  health_check_type    = "ELB"
  #health_check_grace_period = 300
  vpc_zone_identifier = [aws_subnet.subnet_a.id, aws_subnet.subnet_b.id]

  enabled_metrics = [
    "GroupMinSize",
    "GroupMaxSize",
    "GroupDesiredCapacity",
    "GroupInServiceInstances",
    "GroupTotalInstances"
  ]

  metrics_granularity = "1Minute"

  dynamic "tag" {
    for_each = {
      Name   = "Nginx-in-AutoScaling"
      Owner  = "Umbrella.Today"
      TAGKEY = "TAGVALUE"
    }
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
  lifecycle {
    create_before_destroy = true
  }
  #tags = merge(var.all_tags, { Name = "${var.all_tags["Environment"]} Nginx autoscaling" })
}

resource "aws_autoscaling_policy" "policy_up" {
  name                   = "policy_up"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.server.name
}

resource "aws_cloudwatch_metric_alarm" "cpu_alarm_up" {
  alarm_name          = "cpu_alarm_up"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "60"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.server.name
  }

  alarm_description = "This metric monitor EC2 instance CPU utilization"
  alarm_actions     = [aws_autoscaling_policy.policy_up.arn]
}

resource "aws_autoscaling_policy" "policy_down" {
  name                   = "policy_down"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.server.name
}

resource "aws_cloudwatch_metric_alarm" "cpu_down" {
  alarm_name          = "cpu_alarm_down"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "20"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.server.name
  }

  alarm_description = "This metric monitor EC2 instance CPU utilization"
  alarm_actions     = [aws_autoscaling_policy.policy_down.arn]
}

resource "aws_elb" "server" {
  name = "Nginx-elb"

  security_groups = [aws_security_group.server.id]
  subnets         = [aws_subnet.subnet_a.id, aws_subnet.subnet_b.id]

  cross_zone_load_balancing = true

  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }
  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "HTTP:80/"
    interval            = 30
  }

  tags = merge(var.all_tags, { Name = "${var.all_tags["Environment"]} ElasticLoadBalancer" })
}
