resource "aws_instance" "vm" {
  ami           = "<AMI ID you looked up>"
  instance_type = "t3.medium"

  tags = {
    Name  = "${var.account}-vm"
    phase = "testing"
  }
}
