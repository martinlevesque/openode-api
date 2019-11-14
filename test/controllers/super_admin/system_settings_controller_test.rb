require 'test_helper'

class SuperAdmin::SystemSettingsControllerTest < ActionDispatch::IntegrationTest
  test "saving a system setting" do
    post '/super_admin/system_settings/save',
         params: { name: 'what', content: { hello: 'world' } },
         as: :json,
         headers: super_admin_headers_auth

    assert_response :success

    sys_setting = SystemSetting.find_by! name: 'what'
    assert_equal sys_setting.name, 'what'
    assert_equal sys_setting.content['hello'], 'world'

    post '/super_admin/system_settings/save',
         params: { name: 'what', content: { hello: 'world2' } },
         as: :json,
         headers: super_admin_headers_auth

    assert_response :success

    assert_equal response.parsed_body['id'], sys_setting.id
    sys_setting.reload
    assert_equal sys_setting.content['hello'], 'world2'
  end

  test "saving a system setting - fail without superadmin" do
    post '/super_admin/system_settings/save',
         params: { name: 'what', content: { hello: 'world' } },
         as: :json,
         headers: default_headers_auth

    assert_response :unauthorized
  end
end
