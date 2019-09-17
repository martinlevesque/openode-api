require 'test_helper'

class DockerComposeTest < ActiveSupport::TestCase

  def setup

  end

  # default_docker_compose_file

  test "default_docker_compose_file without env file" do
    result = DeploymentMethod::DockerCompose.default_docker_compose_file

    assert_equal result.include?("version: '3'"), true
    assert_equal result.include?("# env_file:"), true
  end

  test "default_docker_compose_file with env file" do
    result = DeploymentMethod::DockerCompose.default_docker_compose_file({
      with_env_file: true
    })

    assert_equal result.include?("version: '3'"), true
    assert_equal result.include?("    env_file:"), true
  end

  # logs
  test "logs should fail if missing container id" do
    docker_compose = DeploymentMethod::DockerCompose.new

    begin
      docker_compose.logs({ nb_lines: 2 })
      assert false
    rescue
    end
  end

  test "logs should fail if missing nb_lines id" do
    docker_compose = DeploymentMethod::DockerCompose.new

    begin
      docker_compose.logs({ container_id: "1234" })
      assert false
    rescue
    end
  end

  test "logs should provide command if proper params" do
    docker_compose = DeploymentMethod::DockerCompose.new

    cmd = docker_compose.logs({ container_id: "1234", nb_lines: 10 })

    assert_includes cmd, "docker exec 1234 docker-compose logs"
    assert_includes cmd, "=10"
  end

end
