terraform {
  backend "s3" {
    bucket  = "my-tf-state-bucket"
    key     = "terraform-easy/dev/terraform.tfstate"
    region  = "ap-south-1"
    encrypt = true
  }
}
