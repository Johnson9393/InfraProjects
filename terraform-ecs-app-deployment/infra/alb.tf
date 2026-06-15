# Create ALB for the application that distributes incoming application traffic across multiple targets, such as ECS tasks, in multiple Availability Zones. It operates at the application layer (Layer 7) and can route traffic based on content, such as URL path or host-based routing.

resource "aws_alb" "sp_alb" {
  name               = var.alb_name
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.sp_alb_sg.id]
  subnets            = [aws_subnet.sp_public_subnet_1.id, aws_subnet.sp_public_subnet_2.id]

  tags = {
    Name = var.alb_name
  }
}

# Create target group for the application which forwards the traffic to the ECS service. A target group is used to route requests to one or more registered targets, such as ECS tasks, using the protocol and port number specified in the target group. It also performs health checks on the registered targets to ensure that they are healthy and can receive traffic.
resource "aws_alb_target_group" "sp_target_group" {
  name        = "sp-target-group"
  port        = var.sp_app_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.sp_vpc.id
  target_type = "ip"

  health_check {
    path                = "/login"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name = "sp-target-group"
  }
}

# Create listener for port 80 which listens for incoming traffic on the specified port and protocol, and forwards the traffic to the target group based on the rules defined in the listener.
resource "aws_alb_listener" "sp_http_listener" {
  load_balancer_arn = aws_alb.sp_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.sp_target_group.arn
  }
}

#  # HTTP Listener (Port 80)
# # Redirect all HTTP requests to HTTPS

# resource "aws_alb_listener" "sp_http_listener" {
#   load_balancer_arn = aws_alb.sp_alb.arn
#   port              = 80
#   protocol          = "HTTP"

#   default_action {
#     type = "redirect"

#     redirect {
#       protocol    = "HTTPS"
#       port        = "443"
#       status_code = "HTTP_301"
#     }
#   }
# }


# Create listener for port 443
resource "aws_alb_listener" "sp_https_listener" {
  load_balancer_arn = aws_alb.sp_alb.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate.sp_cert.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.sp_target_group.arn
  }
}

