# frozen_string_literal: true

require 'test_helper'

class LocationsTest < ActionDispatch::IntegrationTest
  setup do
  end

  test '/instances/:instance_id/stats without stats' do
    get '/instances/testsite/stats',
        as: :json,
        headers: default_headers_auth

    assert_response :success
    assert_equal response.parsed_body['bandwidth_inbound'], []
    assert_equal response.parsed_body['bandwidth_outbound'], []
  end

  test '/instances/:instance_id/stats with stats' do
    w = default_website

    WebsiteBandwidthDailyStat.log(w, 'inbound' => 850, 'outbound' => 100)
    WebsiteBandwidthDailyStat.log(w, 'inbound' => 101, 'outbound' => 50)

    get '/instances/testsite/stats',
        as: :json,
        headers: default_headers_auth

    assert_response :success
    assert_equal response.parsed_body['bandwidth_inbound'].length, 1
    assert_equal response.parsed_body['bandwidth_inbound'][0]['value'], 951
    assert_not_nil response.parsed_body['bandwidth_inbound'][0]['date']

    assert_equal response.parsed_body['bandwidth_outbound'].length, 1
    assert_equal response.parsed_body['bandwidth_outbound'][0]['value'], 150
    assert_not_nil response.parsed_body['bandwidth_outbound'][0]['date']
  end

  test '/instances/:instance_id/stats/spendings with stats' do
    CreditAction.all.each(&:destroy)

    w_custom = default_custom_domain_website
    u = w_custom.user
    u.credits = 1000
    u.save!
    CreditAction.consume!(w_custom, CreditAction::TYPE_CONSUME_PLAN, 1.25)

    w = default_website
    CreditAction.consume!(w, CreditAction::TYPE_CONSUME_PLAN, 1.25)
    CreditAction.consume!(w, CreditAction::TYPE_CONSUME_PLAN, 1.25)

    c = CreditAction.consume!(w, CreditAction::TYPE_CONSUME_PLAN, 5)
    c.created_at = Time.zone.now - 1.day
    c.save!

    c = CreditAction.consume!(w, CreditAction::TYPE_CONSUME_PLAN, 5.5)
    c.created_at = Time.zone.now - 1.day
    c.save!

    c = CreditAction.consume!(w, CreditAction::TYPE_CONSUME_PLAN, 5.5)
    c.created_at = Time.zone.now - 2.days
    c.save!

    get "/instances/#{w.site_name}/stats/spendings",
        as: :json,
        headers: default_headers_auth

    assert_response :success

    assert_equal response.parsed_body.length, 3

    assert_equal response.parsed_body[0]['date'], (Time.zone.now - 2.days).strftime("%Y-%m-%d")
    assert_equal response.parsed_body[0]['value'], 5.5

    assert_equal response.parsed_body[1]['date'], (Time.zone.now - 1.day).strftime("%Y-%m-%d")
    assert_equal response.parsed_body[1]['value'], 10.5

    assert_equal response.parsed_body[2]['date'], Time.zone.now.strftime("%Y-%m-%d")
    assert_equal response.parsed_body[2]['value'], 2.5
  end

  test '/instances/:instance_id/stats/spendings without stats' do
    CreditAction.all.each(&:destroy)

    w = default_website

    get "/instances/#{w.site_name}/stats/spendings",
        as: :json,
        headers: default_headers_auth

    assert_response :success

    assert_equal response.parsed_body.length, 0
  end
end
