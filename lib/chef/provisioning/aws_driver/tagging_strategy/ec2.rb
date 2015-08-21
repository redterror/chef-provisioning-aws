require 'chef/provisioning/aws_driver/aws_tagger'

module Chef::Provisioning::AWSDriver::TaggingStrategy
module EC2
  include Chef::Provisioning::AWSDriver::AWSTagger

  def tagging_client
    @tagging_client ||= new_resource.driver.ec2.client
  end

  def desired_tags
    # TODO bad coupling - requires being added on the provider
    # TODO bad coupling, requires resource to have `aws_tags`
    new_resource.aws_tags
  end

  def current_tags
    # http://docs.aws.amazon.com/sdkforruby/api/Aws/EC2/Client.html#describe_tags-instance_method
    resp = tagging_client.describe_tags({
      filters: [
        {
          name: "resource-id",
          values: [new_resource.aws_object_id]
        }
      ]
    })
    Hash[resp.tag_set.map {|t| [t.key, t.value]}]
  end

  def set_tags(tags)
    converge_by "applying tags #{tags}" do
      tagging_client.create_tags({
        resources: [new_resource.aws_object_id],
        tags: tags.map {|k,v| {key: k, value: v} }
      })
    end
  end

  def delete_tags(tag_keys)
    converge_by "deleting tags #{tag_keys.inspect}" do
      tagging_client.delete_tags({
        resources: [new_resource.aws_object_id],
        tags: tag_keys.map {|k| {key: k} }
      })
    end
  end

end
end
