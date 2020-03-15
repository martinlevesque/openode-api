
require 'test_helper'

class GlobalControllerTest < ActionDispatch::IntegrationTest
  test '/global/test' do
    get '/global/test', as: :json

    assert_response :success
  end

  test '/documentation' do
    get '/documentation'

    assert_response :success

    assert_includes response.parsed_body, 'Official opeNode API documentation'
  end

  test '/global/available-configs' do
    get '/global/available-configs', as: :json

    assert_response :success

    expected_variables = %w[
      SSL_CERTIFICATE_PATH
      SSL_CERTIFICATE_KEY_PATH
      REDIR_HTTP_TO_HTTPS
      MAX_BUILD_DURATION
      SKIP_PORT_CHECK
    ]

    expected_variables.each do |var|
      assert_equal response.parsed_body.any? { |v| v['variable'] == var }, true
    end
  end

  test '/global/available-locations' do
    get '/global/available-locations', as: :json

    assert_response :success

    canada = response.parsed_body.find { |l| l['id'] == 'canada' }
    assert_equal canada['id'], 'canada'
    assert_equal canada['name'], 'Montreal (Canada)'
    assert_equal canada['country_fullname'], 'Canada'

    usa = response.parsed_body.find { |l| l['id'] == 'usa' }
    assert_equal usa['id'], 'usa'
    assert_equal usa['name'], 'New York (USA)'
    assert_equal usa['country_fullname'], 'United States'
  end

  test '/global/available-locations type internal' do
    get '/global/available-locations?type=internal', as: :json

    assert_response :success

    assert_equal response.parsed_body.length, 1
    assert_equal response.parsed_body[0]['str_id'], 'canada2'
  end

  # TODO: deprecate
  test '/global/available-locations type docker' do
    get '/global/available-locations?type=docker', as: :json

    assert_response :success

    assert_equal response.parsed_body.length, 1
    assert_equal response.parsed_body[0]['str_id'], 'canada2'
  end

  test '/global/available-plans' do
    get '/global/available-plans', as: :json

    assert_response :success

    assert_equal response.parsed_body.length, 9
    dummy = response.parsed_body.find { |l| l['id'] == 'DUMMY-PLAN' }
    assert_equal dummy['id'], 'DUMMY-PLAN'

    cloud = response.parsed_body.find { |l| l['id'] == '100-MB' }
    assert_equal cloud['id'], '100-MB'
  end

  test '/global/available-plans-at internal' do
    get '/global/available-plans-at/cloud/canada', as: :json

    assert_response :success

    assert_equal response.parsed_body.length, 8
    assert_equal response.parsed_body[0]['id'], 'sandbox'
  end

  test '/global/version' do
    get '/global/version', as: :json

    assert_response :success
    assert response.parsed_body['version'].count('.'), 2
  end

  test '/global/services' do
    get '/global/services', as: :json

    assert_response :success
    assert response.parsed_body.length, 2
    assert response.parsed_body[0]['name'], 'Mongodb'
    assert response.parsed_body[1]['name'], 'docker canada'
  end

  test '/global/services/down' do
    get '/global/services/down', as: :json

    assert_response :success
    assert response.parsed_body.length, 1
    assert response.parsed_body[0]['name'], 'docker canada'
  end

  # settings
  test '/global/settings if never set' do
    get '/global/settings', as: :json

    assert_response :success
    assert_equal response.parsed_body, {}
  end

  test '/global/settings if set' do
    GlobalNotification.create!(
      level: Notification::LEVEL_PRIORITY,
      content: 'issue happening'
    )

    get '/global/settings', as: :json

    assert_response :success
    assert_equal(response.parsed_body,
                 "global_msg" => "issue happening",
                 "global_msg_class" => "danger")
  end

  test '/global/stats' do
    get '/global/stats', as: :json

    assert_response :success
    assert_equal(response.parsed_body,
                 "nb_users" => User.count, "nb_deployments" => Deployment.total_nb)
  end
end
