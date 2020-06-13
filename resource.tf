provider "aws" {
  region                  = "ap-south-1"
  shared_credentials_file = "C:/Users/KIIT/.aws/credentials"
  profile                 = "chirag"
}

resource "tls_private_key" "keypair" {
  algorithm   = "RSA"
}

resource "local_file" "privatekey" {
    content     = tls_private_key.keypair.private_key_pem
    filename = "key1.pem"
}

resource "aws_key_pair" "deployer" {
  key_name   = "key1.pem"
  public_key = tls_private_key.keypair.public_key_openssh
}

resource "aws_security_group" "secure" {
  name        = "secure"
  description = "Allow TLS inbound traffic"
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "httpos1"
  }
}

resource "aws_instance"  "instance" {
  ami           = "ami-0447a12f28fddb066"
  instance_type = "t2.micro"

  key_name	= aws_key_pair.deployer.key_name
  security_groups =  [ "secure" ] 

  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = tls_private_key.keypair.private_key_pem
    host     = aws_instance.instance.public_ip
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum install httpd  php git -y",
      "sudo systemctl restart httpd",
      "sudo systemctl enable httpd",
    ]
  }


  tags = {
    Name = "httpos1"
  }
}

resource "aws_ebs_volume" "vol1" {
  availability_zone = aws_instance.instance.availability_zone
  size              = 1

  tags = {
    Name = "volume"
  }
}



resource "aws_volume_attachment" "vol1att" {
  device_name = "/dev/sdd"
  volume_id   = aws_ebs_volume.vol1.id
  instance_id = aws_instance.instance.id
  force_detach = true
}

output "instanceid"{
  value=aws_ebs_volume.vol1.id
}

output "volid"{
  value=aws_ebs_volume.vol1.id
}


resource "null_resource" "nulllocal2"  {
	provisioner "local-exec" {
	    command = "echo  ${aws_instance.instance.public_ip} > publicip.txt"
  	}
}

resource "null_resource" "nullremote3"  {

depends_on = [
    aws_volume_attachment.vol1att,
  ]


  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = tls_private_key.keypair.private_key_pem
    host     = aws_instance.instance.public_ip
  }

provisioner "remote-exec" {
    inline = [
      "sudo mkfs.ext4  /dev/sdd",
      "sudo mount  /dev/sdd  /var/www/html",
      "sudo rm -rf /var/www/html/*",
      "sudo git clone https://github.com/chirag0202/cloudtask1-code-instance.git /var/www/html/"
    ]
  }
}



resource "null_resource" "nulllocal1"  {


depends_on = [
    null_resource.nullremote3,
  ]

	provisioner "local-exec" {
	    command = "start chrome  ${aws_instance.instance.public_ip}"
  	}
}



