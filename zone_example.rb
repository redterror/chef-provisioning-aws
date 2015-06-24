with_driver 'aws'
require 'chef/provisioning/aws_driver'

# aws_route53_hosted_zone "fizzgig.net." do
#   action :create
# end

aws_route53_hosted_zone "fizzgig.net." do
  action :destroy
end
