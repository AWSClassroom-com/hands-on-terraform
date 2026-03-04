resource "aws_launch_template" "web_template" {
  name_prefix   = "${var.account}-lt-"
  image_id      = var.image_id
  instance_type = var.instance_type

  user_data = var.user_data_base64

  network_interfaces {
    associate_public_ip_address = false
    delete_on_termination       = true
    security_groups = [
      var.app_sg_id
    ]
  }

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "${var.account}-webserver"
    }
  }
}

resource "aws_autoscaling_group" "web_asg" {
  name                      = "${var.account}-asg"
  max_size                  = var.instance_count_max
  min_size                  = var.instance_count_min
  desired_capacity          = var.instance_count_min
  vpc_zone_identifier       = var.private_subnet_ids
  health_check_type         = "ELB"
  health_check_grace_period = 300

  launch_template {
    id      = aws_launch_template.web_template.id
    version = "$Latest"
  }

  target_group_arns = [var.target_group_arn]

  tag {
    key                 = "Name"
    value               = "${var.account}-webserver"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}