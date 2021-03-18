provider "aws" {
  region = "ap-south-1"
  profile = "Harry"
}

resource "aws_vpc" "myvpc" {

   cidr_block = "10.0.0.0/16"

   enable_dns_hostnames = true

   enable_dns_support = true

  tags = {

     Name = "myvpc"

   }

}

resource "aws_subnet" "mysubnet" {
depends_on = [
    aws_vpc.myvpc,
]

   cidr_block = "${cidrsubnet(aws_vpc.myvpc.cidr_block, 8, 8)}"

   vpc_id = "${aws_vpc.myvpc.id}"

   availability_zone = "ap-south-1a"

}


resource "aws_security_group" "tfw" {
depends_on = [
    aws_subnet.mysubnet,
]
  name        = "tfw"
  description = "allow ssh and http traffic"
  vpc_id = "${aws_vpc.myvpc.id}"

  ingress {
     from_port   = 22
     to_port     = 22
     protocol    = "tcp"
     cidr_blocks = ["0.0.0.0/0"]

  }
  ingress {
     from_port   = 80
     to_port     = 80
     protocol   = "tcp"
     cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
     from_port = 2049
     to_port = 2049
     protocol = "tcp"
   }

  egress {
     from_port       = 0
     to_port         = 0
     protocol        = "-1"
     cidr_blocks     = ["0.0.0.0/0"]
    }

}


resource "aws_efs_file_system" "myefspd" {
depends_on = [
    aws_security_group.tfw,
]
   creation_token = "myefspd"

   performance_mode = "generalPurpose"

   throughput_mode = "bursting"

   encrypted = "true"

tags = {

     Name = "myefspd"

   }

}


resource "aws_efs_mount_target" "pd_att" {

depends_on = [
    aws_efs_file_system.myefspd,
  ]
   file_system_id = "${aws_efs_file_system.myefspd.id}"

   subnet_id = "${aws_subnet.mysubnet.id}"

 security_groups = ["${aws_security_group.tfw.id}"]

}



resource "aws_instance" "tfin" {
depends_on = [
    aws_efs_mount_target.pd_att,
]
  ami    = "ami-052c08d70def0ac62"
  instance_type = "t2.micro"
  key_name = "MyNewKey"
  security_groups = ["${aws_security_group.tfw.name}" ]

  connection {
    type   = "ssh"
    user   = "ec2-user"
    private_key = file("MyNewKey.pem")
    host      = aws_instance.tfin.public_ip
  }
 provisioner "remote-exec" {
    inline = [
      "sudo yum install httpd php git -y",
      "sudo systemctl restart httpd",
      "sudo systemctl enable httpd",
      "sudo yum install nfs-utils -y -q",
      "sudo mount -t nfs -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport ${aws_efs_file_system.myefspd.dns_name}:/  /var/www/html",
      "echo ${aws_efs_file_system.myefspd.dns_name}:/ /var/www/html nfs4 defaults,_netdev 0 0  | sudo cat >> /etc/fstab " ,
      "sudo chmod go+rw /var/www/html",
      "sudo git clone https://github.com/Harvinder-osahan/TestingTeraform.git /var/www/html",
  ]
     
  }

  tags = {
    Name = "AUTOMATED2"
  }
}






resource "null_resource" "NL"  {
        provisioner "local-exec" {
            command = "echo  ${aws_instance.tfin.public_ip} > publicip.txt"
        }
}




resource "null_resource" "baseosi"  {

depends_on = [
     aws_instance.tfin,    
]

        provisioner "local-exec" {
            command = "start chrome  192.168.117.25:777/"
        }
}


output "myos_ip" {
  value = aws_instance.tfin.public_ip
}
 
