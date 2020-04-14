require 'test_helper'
require 'test_kubernetes_helper'

class LibMonitorDeploymentsTest < ActiveSupport::TestCase
  def prepare_get_pods_happy(kubernetes_method, website_location)
    cmd = kubernetes_method.kubectl(
      website_location: website_location,
      with_namespace: true,
      s_arguments: "get pods -o json"
    )

    prepare_ssh_session(cmd, IO.read('test/fixtures/kubernetes/1_pod_alive.json'))
  end

  test "monitor deployments - with one online" do
    Website.all.each do |w|
      w.status = Website::STATUS_OFFLINE
      w.save!
    end

    WebsiteStatus.all.each(&:destroy)

    website = default_website
    website.status = Website::STATUS_ONLINE
    website.type = Website::TYPE_KUBERNETES
    website.save!

    cmd = get_kubernetes_method(website).kubectl(
      website_location: website.website_locations.first,
      with_namespace: true,
      s_arguments: "get pods -o json"
    )

    prepare_ssh_session(cmd, IO.read('test/fixtures/kubernetes/1_pod_alive.json'))

    assert_scripted do
      begin_ssh
      invoke_task "monitor_deployments:pod_status"

      status = website.statuses.last
      statuses = status.simplified_container_statuses

      assert_equal status.ref_id, website.id
      assert_equal statuses.length, 1
      assert_equal statuses.first['name'], "www"
    end
  end

  test "monitor deployments - with one online without status" do
    Website.all.each do |w|
      w.status = Website::STATUS_OFFLINE
      w.save!
    end

    WebsiteStatus.all.each(&:destroy)

    website = default_website
    website.status = Website::STATUS_ONLINE
    website.type = Website::TYPE_KUBERNETES
    website.save!

    cmd = get_kubernetes_method(website).kubectl(
      website_location: website.website_locations.first,
      with_namespace: true,
      s_arguments: "get pods -o json"
    )

    prepare_ssh_session(cmd, IO.read('test/fixtures/kubernetes/empty_pod.json'))

    assert_scripted do
      begin_ssh
      invoke_task "monitor_deployments:pod_status"

      assert_equal website.statuses.length, 1
      assert_equal website.statuses.first.obj, nil
    end
  end

  test "monitor deployments - without any online" do
    Website.all.each do |w|
      w.status = Website::STATUS_OFFLINE
      w.save!
    end

    WebsiteStatus.all.each(&:destroy)

    invoke_task "monitor_deployments:pod_status"

    assert_equal WebsiteStatus.count, 0
  end

  test "monitor deployments bandwidth - happy path" do
    Website.all.each do |w|
      w.status = Website::STATUS_OFFLINE
      w.save!
    end

    w = default_website
    w.change_status!(Website::STATUS_ONLINE)
    w.type = Website::TYPE_KUBERNETES
    w.save!

    WebsiteBandwidthDailyStat.all.each(&:destroy)

    kubernetes_method = get_kubernetes_method(w)

    prepare_get_pods_happy(kubernetes_method, w.website_locations.first)

    cmd = kubernetes_method.kubectl(
      website_location: w.website_locations.first,
      with_namespace: true,
      s_arguments: "exec www-deployment-5889df69dc-xg9xl -- cat /proc/net/dev"
    )

    prepare_ssh_session(cmd, IO.read('test/fixtures/net/proc_net_dev/1'))

    assert_scripted do
      begin_ssh

      invoke_task "monitor_deployments:bandwidth"

      stat = WebsiteBandwidthDailyStat.last

      assert_equal stat.ref_id, w.id
      assert_equal stat.obj['previous_network_metrics'].length, 1
      assert_equal stat.obj['previous_network_metrics'].first['interface'], 'eth0'
      assert_equal stat.obj['previous_network_metrics'].first['rcv_bytes'], 84_363_193.0
      assert_equal stat.obj['previous_network_metrics'].first['tx_bytes'], 9_758_564
      assert_equal stat.obj['rcv_bytes'], 84_363_193
      assert_equal stat.obj['tx_bytes'], 9_758_564
    end
  end
end
