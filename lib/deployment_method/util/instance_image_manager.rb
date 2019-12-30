module DeploymentMethod
  module Util
    class InstanceImageManager
      attr_accessor :runner
      attr_accessor :docker_images_location
      attr_accessor :website
      attr_accessor :deployment

      LIMIT_REPOSITORY_BYTES = 1024 * 1024 * 1024 # MB * KB * B -> 1 GB

      def initialize(args)
        assert args[:runner]
        assert args[:docker_images_location]
        assert args[:website]
        assert args[:deployment]

        @runner = args[:runner]

        @deployment = args[:deployment]
        @website = args[:website]
        @docker_images_location = args[:docker_images_location]
      end

      def hooks
        []
      end

      def self.tag_name(options = {})
        "#{options[:website].site_name}--#{options[:website].id}--#{options[:execution_id]}"
      end

      def image_name_tag
        t_name = InstanceImageManager.tag_name(website: @website, execution_id: @deployment.id)
        "#{full_repository_name}:#{t_name}"
      end

      def full_repository_name
        "#{docker_images_location['docker_username']}/" \
        "#{docker_images_location['repository_name']}"
      end

      def build_cmd(options = {})
        project_path = options[:project_path]

        "cd #{project_path} && " \
        "docker build -t #{image_name_tag} ."
      end

      def push_cmd(_options = {})
        "echo #{docker_images_location['docker_password']} | " \
          "docker login -u #{docker_images_location['docker_username']} " \
          "--password-stdin && " \
          "docker push #{image_name_tag}"
      end

      def verify_size_repo_cmd(options = {})
        project_path = options[:project_path]

        "du -bs #{project_path}"
      end

      def verify_size_repo
        opts = {
          project_path: @website.repo_dir
        }

        result = @runner.execute([{ cmd_name: 'verify_size_repo_cmd', options: opts }])

        output = result[0][:result][:stdout] rescue ''
        nb_bytes = output.to_i

        err_msg_too_large = "Repository image size is too large " \
          "(limit = #{LIMIT_REPOSITORY_BYTES} bytes)"
        raise err_msg_too_large if nb_bytes > LIMIT_REPOSITORY_BYTES
      end

      def build
        opts = {
          project_path: @website.repo_dir
        }

        @runner.execute([{ cmd_name: 'build_cmd', options: opts }])
      end

      def push
        opts = {
          repository_name:
            "#{docker_images_location['docker_username']}/" \
            "#{docker_images_location['repository_name']}"
        }

        @runner.execute([{ cmd_name: 'push_cmd', options: opts }])
      end
    end
  end
end
