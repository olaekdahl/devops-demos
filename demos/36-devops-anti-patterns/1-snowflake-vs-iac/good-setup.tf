resource "aws_instance" "web" {
  ami                    = "ami-0abcd1234"
  instance_type          = "t3.small"
  user_data              = file("cloud-init.yaml")  # declarative bootstrap
  vpc_security_group_ids = [aws_security_group.web.id]
  tags = { Name = "web", env = "prod", managed_by = "terraform" }
}
