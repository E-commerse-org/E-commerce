environment = "prod"
cidr_block  = "10.0.0.0/16"

az = ["us-east-1a", "us-east-1b", "us-east-1c"]

associated_project = "e-commerce"

container_port     = 80
cpu                = 1024
memory             = 2048
db_master_password = "hello_pass"

image_name = "nginx"
repo_name  = "testing_repo"
