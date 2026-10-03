resource "aws_launch_template" "server" {
 name_prefix  = "${var.name}-"
 image_id  = var.ami_id
 instance_type  = var.instance_type

 
 vpc_security_group_ids = [var.security_group_id]


 tag_specifications { 
   resource_type = "instance"
   tags = {
     Name = var.name
    }
  }
}

resource "aws_autoscaling_group" "server" { 
 name_prefix = "${var.name}-asg-"
 min_size    = 1
 max_size    = 2
 desired_capacity = 1

 vpc_zone_identifier = var.subnet_ids 
 health_check_type   = "EC2"

 launch_template {
 id      = aws_launch_template.server.id
 version = "$Latest"
}

 tag { 
   key           = "Name"
   value         = var.name
   propagate_at_launch = true 
 } 
}
