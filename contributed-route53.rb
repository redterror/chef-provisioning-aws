# from https://gist.github.com/lynchc/1a68c0e2b7bd2434eb58
# via https://github.com/chef/chef-provisioning-aws/issues/226#issuecomment-124244297

require 'chef/resource/aws_resource'
require 'chef/provider/aws_provider'
require 'chef/provisioning/aws_driver'
require 'chef/provisioning/machine_spec'

class Chef::Resource::AwsRoute53Rs < Chef::Resource::AwsResource

    self.resource_name = 'aws_route53_rs'
    #self.databag_name = 'r53_recordsets'

    actions :create, :delete, :modify
    default_action :modify

    #stored_attribute :id, :kind_of => String, :name_attribute => true

    attribute :name, :kind_of => String, :name_attribute => true

    attribute :hosted_zone, :kind_of => String
    attribute :type, :kind_of => String
    attribute :raw_options, :kind_of => Hash
    attribute :alias_target, :kind_of => Hash
    attribute :ttl, :kind_of => Integer
    attribute :weight, :kind_of => Integer
    attribute :use_public_ip, :kind_of =>[TrueClass, FalseClass], :default => true
    attribute :machines
    attribute :addresses

    def initialize(*args)
        super
    end

    def after_created
        super
    end
end


# *****************************************************************************************************


require 'chef/provider/aws_provider'
require 'chef/provisioning/machine_spec'
require 'cheffish'

class Chef::Provider::AwsRoute53Rs < Chef::Provider::AwsProvider

    action :create do
        if existing_rs == nil
            converge_by "Creating new Route 53 RecordSet:#{new_resource.name}" do
                begin
                    consolidate_resource_records
                    rrsets = r53.hosted_zones[new_resource.hosted_zone].rrsets
                    rset = rrsets.create(new_resource.name, new_resource.type)
                    if new_resource.raw_options
                        rset.update(new_resource.raw_options)
                    elsif changes_found
                        rset.update
                    else
                        Chef::Log.warn("Created DNS entry '#{new_resource.name}, #{new_resource.type}' with default config")
                    end
                rescue => e
                    Chef::Application.fatal!("Error Creating RecordSet: #{e}")
                end
            end
        else
            Chef::Log.warn("Route 53 Recordset '#{new_resource.name}, #{new_resource.type}' already exists. Call modify action to update")
        end
    end

    action :modify do
        if existing_rs == nil
            action_create
        else
            begin
                consolidate_resource_records
                #if they gave raw_options, don't pick through them, just blindly write them
                #TODO: not convergent.
                if new_resource.raw_options
                    converge_by "Updating Route 53 Record Set #{new_resource.name} with raw options" do
                        existing_rs.update(new_resource.raw_options)
                    end
                elsif changes_found
                    converge_by "Updating Route 53 Record Set #{new_resource.name}" do
                        existing_rs.update
                    end
                else
                    Chef::Log.warn("No changes needed for DNS entry '#{new_resource.name}, #{new_resource.type}'")
                end
            rescue => e
                Chef::Application.fatal!("Error Modifying RecordSet: #{e}")
            end
        end
    end

    action :delete do
        if existing_rs
            converge_by "Deleting Route 53 Record Set #{new_resource.name}" do
                existing_rs.delete
            end
        end
    end

    def existing_rs
        #if user didn't add suffix, add it
        if not new_resource.name.end_with? "."
            new_resource.name = new_resource.name + "."
        end
        @existing_rs ||= not(r53.hosted_zones[new_resource.hosted_zone].rrsets["#{new_resource.name}", "#{new_resource.type}"].exists?) ? nil : begin
        #if we find the id stored, we assume we know about this entry. Still, pull data only from aws and compare against what's being passed
        #@existing_rs ||= new_resource.id == nil ? nil : begin
            rs = r53.hosted_zones[new_resource.hosted_zone].rrsets["#{new_resource.name}", "#{new_resource.type}"]
            Chef::Log.warn(rs.ttl)
            rs
        rescue => e
            Chef::Application.fatal!("Error looking for EIP Address: #{e}")
            nil
        end
    end

    def get_ip(machine, public=true)
        begin
            Chef::Log.warn("getting IP for machine: #{machine}")
            spec = Chef::Provisioning::ChefMachineSpec.get(machine)
            if spec == nil
                Chef::Application.fatal!("Could not find machine #{machine}")
            else
                instance = ec2.instances[spec.location["instance_id"]]
                if instance.exists? #just making sure
                    ip = public ? instance.ip_address : instance.private_ip_address
                    ip
                else
                    Chef::Application.fatal!("Error. Machine #{machine} with instance_id #{spec.location["instance_id"]} cannot be found in EC2")
                end
            end
        rescue => e
            Chef::Application.fatal!("Error Finding Public IP for machine #{machine}: #{e}")
        end
    end

    def consolidate_resource_records
        @addresses ||= []
        if new_resource.machines
            @addresses = new_resource.machines.map { |machine| { value: get_ip(machine)} }
        end
        if new_resource.addresses
            @addresses << new_resource.addresses.map { |address|  { value: address} }
        end
    end

    def changes_found
        change = false
        tmp = new_resource.ttl and ((change, existing_rs.ttl = true, tmp) if tmp != existing_rs.ttl)
        tmp = new_resource.weight and ((change, existing_rs.weight = true, tmp) if tmp != existing_rs.weight)
        tmp = @addresses and ((change, existing_rs.resource_records = true, tmp) if tmp != existing_rs.resource_records)
        change
    end
end