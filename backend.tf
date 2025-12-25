terraform {
  backend "s3" {
    bucket  = "az-tf-bucket-task2"
    key     = "terraform-easy/dev/terraform.tfstate"
    region  = "ap-south-1"
    encrypt = true
  }
}
