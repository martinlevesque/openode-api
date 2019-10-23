# frozen_string_literal: true

class LocationsController < InstancesController
  def index
    result = @website.locations
                     .map do |location|
      {
        id: location.str_id,
        name: location.full_name
      }
    end

    json(result)
  end

  def add_location
    str_id = params['location_str_id']

    validation_error!('Location already added') if @website.location_exists?(str_id)

    if @website.website_locations.length >= 1
      msg = 'Multi location is not currently supported. ' \
            'Make sure to delete your existing location before adding a new one.'

      validation_error!(msg)
    end

    @website.add_location(Location.find_by!(str_id: str_id))

    @website_event_obj = { title: 'add-location', location_id: str_id }

    json(result: 'success')
  end

  def remove_location
    str_id = params['location_str_id']

    unless @website.location_exists?(str_id)
      validation_error!('This instance does not have that location.')
    end

    @website.remove_location(Location.find_by!(str_id: str_id))

    @website_event_obj = { title: 'remove-location', location_id: str_id }

    json(result: 'success')
  end

  protected
end
