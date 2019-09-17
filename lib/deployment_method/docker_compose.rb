
module DeploymentMethod

  class DockerCompose

    def initialize
    end

    def logs(options = {})
      container_id = options[:container_id]

      container_id = options[:website].container_id if options[:website]

      assert container_id
      assert options[:nb_lines]

      "docker exec #{container_id} docker-compose logs --tail=#{options[:nb_lines]}"
    end

    def self.default_docker_compose_file(opts = {})
      env_part =
        if opts[:with_env_file]
"    env_file:
      - /opt/app/.env"
        else
"    # env_file:
    # - /opt/app/.env"
        end

"version: '3'
services:
  www:
#{env_part}
    volumes:
      - .:/opt/app/
    ports:
      - '80:80'
    build:
      context: .
    restart: always
"
    end

  end

end
