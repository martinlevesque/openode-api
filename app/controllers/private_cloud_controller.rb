class PrivateCloudController < InstancesController
  before_action only: [:allocate, :apply] do
    requires_private_cloud_plan
  end

  before_action only: [:apply] do
    requires_active_private_cloud_allocation
  end

  def allocate
    if @website.data && @website.data['privateCloudInfo']
      return json(success: 'Instance already allocated')
    end

    raise ApplicationRecord::ValidationError, 'No credit available' unless @website.user.credits?

    cloud_manager = CloudProvider::Manager.instance
    cloud_provider = cloud_manager.first_of_internal_type(CloudProvider::Vultr::TYPE)

    cloud_provider.allocate(
      website: @website,
      website_location: @website_location
    )

    @website_event_obj = { title: 'allocate' }

    json(
      status: 'Instance creating...'
    )
  end

  def apply
    server_planning_methods = [
      DeploymentMethod::ServerPlanning::Sync.new,
      DeploymentMethod::ServerPlanning::DockerCompose.new,
      DeploymentMethod::ServerPlanning::Nginx.new
    ]

    result = server_planning_methods.map do |planning_method|
      prepare_execution_method_runner(@website, @website_location, planning_method)

      planning_method.apply(
        website: @website,
        website_location: @website_location
      )
    end

    result_to_present = result.andand.last[0].andand[:result]

    json(
      status: 'success',
      result: result_to_present
    )
  end

  protected

  def prepare_execution_method_runner(website, website_location, server_planning_method)
    configs = website_location.prepare_runner_configs
    configs[:execution_method] = server_planning_method

    DeploymentMethod::Runner.new(website.type, website.cloud_type, configs)
  end

  def requires_active_private_cloud_allocation
    unless @website.private_cloud_allocated?
      validation_error!('The instance requires to be already allocated')
    end
  end
end
