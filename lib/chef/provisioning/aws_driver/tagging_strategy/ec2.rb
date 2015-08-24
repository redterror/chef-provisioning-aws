require 'chef/provisioning/aws_driver/aws_tagger'

module Chef::Provisioning::AWSDriver::TaggingStrategy
class EC2

  attr_reader :tagging_client, :aws_object_id, :desired_tags

  def initialize(tagging_client, aws_object_id, desired_tags)
    @tagging_client = tagging_client
    @aws_object_id = aws_object_id
    @desired_tags = desired_tags
  end

  def current_tags
    # http://docs.aws.amazon.com/sdkforruby/api/Aws/EC2/Client.html#describe_tags-instance_method
    resp = tagging_client.describe_tags({
      filters: [
        {
          name: "resource-id",
          values: [aws_object_id]
        }
      ]
    })
    Hash[resp.tag_set.map {|t| [t.key, t.value]}]
  end

  def set_tags(tags)
    tagging_client.create_tags({
      resources: [aws_object_id],
      tags: tags.map {|k,v| {key: k, value: v} }
    })
  end

  def delete_tags(tag_keys)
    tagging_client.delete_tags({
      resources: [aws_object_id],
      tags: tag_keys.map {|k| {key: k} }
    })
  end

end
end
