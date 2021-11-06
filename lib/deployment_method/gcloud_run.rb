require 'dotenv'
require 'base64'

module DeploymentMethod
  class GcloudRun < Base
    KUBECONFIGS_BASE_PATH = "config/kubernetes/"
    CERTS_BASE_PATH = "config/certs/"
    KUBE_TMP_PATH = "/home/tmp/"
    WWW_DEPLOYMENT_LABEL = "www"
    GCLOUD_PROJECT_ID = ENV["GOOGLE_CLOUD_PROJECT"]
    GCP_CERTS_BUCKET = ENV["GCP_CERTS_BUCKET"]

    # gcloud run deploy helloworld   --image gcr.io/$GOOGLE_CLOUD_PROJECT/helloworld   --platform managed   --region us-central1   --allow-unauthenticated
    # gcloud builds submit --tag gcr.io/$GOOGLE_CLOUD_PROJECT/helloworld

    def initialize; end

    # verify can deploy

    def verify_can_deploy(options = {})
      super(options)
    end

    def initialization(options = {})
      super(options)
    end

    def instance_up?(_options = {})
      true
    end

    def gcloud_cmd(options = {})
      website, website_location = get_website_fields(options)
      project_path = website.repo_dir
      "timeout 300 sh -c 'cd #{project_path} && gcloud --project #{GCLOUD_PROJECT_ID} #{options[:subcommand]}'"
    end

    def image_tag_url(options = {})
      website, website_location = get_website_fields(options)

      tag_name = DeploymentMethod::Util::InstanceImageManager.tag_name(
        website: website,
        execution_id: runner.execution.id
      )

      "gcr.io/#{GCLOUD_PROJECT_ID}/#{website.site_name}:#{tag_name}"
    end

    def build_image(options = {})
      website, website_location = get_website_fields(options)

      image_url = image_tag_url(options)

      # build

      notify("info", "Building instance image...")

      result_build = ex("gcloud_cmd", {
                          website: website,
                          website_location: website_location,
                          subcommand: "builds submit --tag #{image_url} --gcs-log-dir=gs://builds_logs/"
                        })

      # retrieve the build ID, it looks like:
      # Created
      # [https://.../71a90edd-6cbb-4898-9abf-1a58319df67e]
      line_with_build = result_build[:stderr]
                        .lines.find { |line| line.include?("Created [https://cloudbuild.googleapis.com/") }

      if line_with_build.blank?
        raise "No created build link available"
      end

      build_id = line_with_build[line_with_build.rindex("/") + 1..line_with_build.rindex("]") - 1]

      if build_id.blank? || build_id.size <= 10
        raise "Unable to retrieve the build ID"
      end

      # save the image name tag and build ID
      save_extra_execution_attrib('image_name_tag', image_url)
      save_extra_execution_attrib('build_id', build_id)

      # retrieve the logs build
      result = ex("gcloud_cmd", {
                    website: website,
                    website_location: website_location,
                    subcommand: "builds log #{build_id}",
                    ensure_exit_code: 0
                  })

      notify("info", result[:stdout])

      raise "Unable to complete successfully the image build" if result_build[:exit_code] != 0

      image_url
    end

    def service_id(website)
      "instance-#{website.id}"
    end

    def first_safe_json(str)
      result_json = JSON.parse(str)

      result_json.length.positive? ? result_json.first : nil
    end

    def region_of(_website_location)
      # website_location.location.str_id
      "us-central1"
    end

    def retrieve_logs_cmd(options = {})
      website, website_location = get_website_fields(options)
      options[:nb_lines] ||= 100

      subcommand = "logging read \"resource.labels.service_name=#{service_id(website)}\" " \
        "--format=\"value(textPayload)\" --limit #{options[:nb_lines]}"

      gcloud_cmd({
                   website: website,
                   website_location: website_location,
                   subcommand: subcommand
                 })
    end

    # returns the service if available, nil otherwise
    def retrieve_run_service(options = {})
      website, website_location = get_website_fields(options)

      result = ex("gcloud_cmd", options.merge(
                                  subcommand: "run services list --region=#{region_of(website_location)} " \
                                    "--filter=\"metadata.name=#{service_id(website)}\" --format=json"
                                ))

      first_safe_json(result[:stdout])
    end

    def server_file_exists_cmd(options = {})
      path = options[:path]
      "ls #{path}"
    end

    def gs_cp_cmd(options = {})
      server_path = options[:server_path]
      gs_url = options[:gs_url]

      "gsutil cp #{server_path} #{gs_url}"
    end

    def sync_file_to_gcp_storage(server_file_path, gstorage_url)
      return if ex("server_file_exists_cmd", path: server_file_path)[:exit_code] != 0

      ex("gs_cp_cmd",
         server_path: server_file_path,
         gs_url: gstorage_url)[:exit_code].zero?
    end

    def sync_certs(website, website_location)
      Rails.logger.info("Considering syncing certs for website id #{website.id}")

      if website.certs.blank?
        website_location.obj["gcloud_ssl_cert_url"] = nil
        website_location.obj["gcloud_ssl_key_url"] = nil
        website_location.save
        return
      end

      Rails.logger.info("Syncing certs for website id #{website.id}")

      # GCP_CERTS_BUCKET
      project_path = website.repo_dir

      # SSL cert
      cert_file_path = "#{project_path}#{website.certs[:cert_path]}"
      cert_gstorage_url = "#{GCP_CERTS_BUCKET}#{website.id}.cert"

      if sync_file_to_gcp_storage(cert_file_path, cert_gstorage_url)
        website_location.obj ||= {}
        website_location.obj["gcloud_ssl_cert_url"] = cert_gstorage_url
        website_location.save
      end

      # SSL key
      cert_file_path = "#{project_path}#{website.certs[:cert_key_path]}"
      cert_gstorage_url = "#{GCP_CERTS_BUCKET}#{website.id}.key"

      if sync_file_to_gcp_storage(cert_file_path, cert_gstorage_url)
        website_location.obj ||= {}
        website_location.obj["gcloud_ssl_key_url"] = cert_gstorage_url
        website_location.save
      end
    end

    def escape_quoted_command_line(value)
      value.to_s.gsub("\"", "\\\"").gsub("'", "''")
    end

    def env_variables(website)
      variables_strings = website.env.keys.map do |variable_name|
        value = escape_quoted_command_line(website.env[variable_name])
        variable = escape_quoted_command_line(variable_name)

        "#{variable}=#{value}"
      end

      variables_strings.join(",")
    end

    def deploy(options = {})
      website, website_location = get_website_fields(options)
      image_url = options[:image_url]

      notify("info", "Deploying instance...")

      result = ex("gcloud_cmd", {
                    website: website,
                    website_location: website_location,
                    subcommand: "run deploy #{service_id(website)} --port=80 --image #{image_url} " \
          "--platform managed --region #{region_of(website_location)} " \
          "--allow-unauthenticated --set-env-vars=\"#{env_variables(website)}\""
                  })

      notify("info", "--------------- Instance boot logs ---------------")
      logs_instance = ex_stdout(
        "retrieve_logs_cmd",
        { website: website, website_location: website_location, nb_lines: 20 }
      )
      notify("info", logs_instance)
      notify("info", "--------------------------------------------------")

      unless result[:exit_code].zero?

        result_stderr = (result[:stderr]).to_s
        url_log_index = result_stderr.downcase.index("logs url:")

        if url_log_index
          notify("error", result_stderr.slice(0..(url_log_index - 1)))
        else
          notify("error", result_stderr)
        end

        raise "Unable to deploy the instance with success"
      end

      sync_certs(website, website_location)

      notify("info", "Instance deployed successfully")
    end

    def launch(options = {})
      website, website_location = get_website_fields(options)
      simplified_options = { website: website, website_location: website_location }

      image_url = build_image(options)

      deploy(options.merge(image_url: image_url))

      service = retrieve_run_service(simplified_options)

      website_location.load_balancer_synced = false
      website_location.obj ||= {}
      website_location.obj["gcloud_url"] = service["status"]&.dig("url")
      website_location.save!
    end

    # stop
    def delete_service_cmd(options = {})
      website, website_location = get_website_fields(options)

      gcloud_cmd({
                   website: website,
                   website_location: website_location,
                   subcommand: "run services delete #{service_id(website)} " \
          "--region #{region_of(website_location)} --quiet"
                 })
    end

    def do_stop(options = {})
      website, website_location = get_website_fields(options)

      ex("delete_service_cmd",
         {
           website: website,
           website_location: website_location,
           ensure_exit_code: 0,
           default_retry_scheme: true
         })
    end

    def hooks
      [
        Kubernetes.hook_error,
        Kubernetes.hook_verify_can_deploy,
        Kubernetes.hook_logs,
        Kubernetes.hook_finalize,
        Kubernetes.hook_finalize_done,
        Kubernetes.hook_verify_instance_up,
        Kubernetes.hook_verify_instance_up_done
      ]
    end
  end
end
