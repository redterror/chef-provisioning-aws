require 'chef/provisioning/aws_driver'
with_driver 'aws'

aws_instance 'my-bucket' do
  action :terraform

  terraform_action :do_something

  enable_website_hosting true
  acl "public-read"
  policy "/path/to/policy.json"

  website index_document: "index.html", error_document: "error.html"
end
