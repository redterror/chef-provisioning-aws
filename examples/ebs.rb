require 'chef/provisioning/aws_driver'
with_driver 'aws'

aws_ebs_volume 'tf-managed-ebs-volume' do
  action :terraform

  # only uses :destroy, everything else is `terraform apply`.
  # terraform_action :create

  availability_zone "us-east-1a"
  size 1

  tags user: "cdoherty", purpose: "Terraform testing", comment: "Go ahead and delete it."
end
