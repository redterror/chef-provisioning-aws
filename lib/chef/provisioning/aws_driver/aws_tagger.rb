require 'retryable'

module Chef::Provisioning::AWSDriver
# Include this module on a class or instance that is responsible for tagging
# itself.  Fill in the hook methods so it knows how to tag itself.
module AWSTagger

  def tagging_client
    raise NotImplementedError
  end

  # Always returns tags as a 1-layer Hash from tag key to value
  def desired_tags
    raise NotImplementedError
  end

  def current_tags
    raise NotImplementedError
  end

  def set_tags(tags)
    raise NotImplementedError
  end

  def delete_tags(tag_keys)
    raise NotImplementedError
  end

  def converge_tags
    require 'pry'; binding.pry
    if desired_tags.nil?
      Chef::Log.debug "aws_tags not provided, nothing to converge"
      return
    end

    # Duplication and normalization
    n_desired_tags = Hash[desired_tags.map {|k,v| [k.to_s, v.to_s]}]
    n_current_tags = Hash[current_tags.map {|k,v| [k.to_s, v.to_s]}]

    tags_to_set = n_desired_tags.reject {|k,v| n_current_tags[k] == v}
    tags_to_delete = n_current_tags.keys - n_desired_tags.keys
    # We don't want to delete `Name`, just all other tags
    # Tag keys and values are case sensitive - `Name` is special because it
    # shows as the name in the console
    tags_to_delete.delete('Name')

    # Tagging frequently fails so we retry with an exponential backoff, a maximum of 10 seconds
    Retryable.retryable(:tries => 5, :sleep => lambda { |n| [2**n, 10].min }) do |retries, exception|
      if retries > 0
        Chef::Log.debug "Retrying the tagging, previous try failed with #{exception.inspect}"
      end
      unless tags_to_set.empty?
        set_tags(tags_to_set)
        tags_to_set = []
      end
      unless tags_to_delete.empty?
        delete_tags(tags_to_delete)
        tags_to_delete = []
      end
    end
  end

end
end
