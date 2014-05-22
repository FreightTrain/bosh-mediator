require 'erubis'
require 'yaml'

require_relative 'release_manager'
require_relative 'stemcell_resource_manager'

module BoshMediator
  class BoshMediator

    extend Forwardable

    def_delegators :release_manager, :create_release, :upload_release, :upload_dev_release, :release_info, :set_dev_release_name, :find_dev_release

    attr_accessor :release_manager
    attr_accessor :stemcell_manager

    def initialize(options = {})
      @bosh_director = options[:director]
      @release_command = options[:release_command]
      @deployment_command = options[:deployment_command]
      @release_manager = options[:release_manager] || ReleaseManager.new(options)
      @stemcell_manager = options[:stemcell_manager] || StemcellResourceManager.new
      Bosh::Cli::Config.output = STDOUT
      Bosh::Cli::Config.interactive = false
      Bosh::Cli::Config.colorize = true
    end

    def deploy
      @deployment_command.perform
      BoshMediator.raise_on_error! @deployment_command
    end

    def delete_deployment(name)
      if bosh_contains_deployment?(name)
        @deployment_command.delete(name)
        BoshMediator.raise_on_error! @deployment_command
      end
    end

    def upload_stemcell_to_director(stemcell_uri)
      if downloadable_uri?(stemcell_uri)
        stemcell_path = stemcell_manager.download_stemcell(stemcell_uri)
        metadata = extract_stemcell_metadata_and_upload(stemcell_path)
        metadata
      elsif File.exists?(stemcell_uri)
        extract_stemcell_metadata_and_upload(stemcell_uri)
      else
        raise InvalidStemcellResourceError, stemcell_uri
      end
    end

    def extract_stemcell_metadata_and_upload(stemcell_path)
      metadata = stemcell_manager.get_stemcell_name_and_version(stemcell_path)
      stemcells = @bosh_director.list_stemcells
      if stemcells.none?{|s| s['name'] == metadata[:name] and s['version'] == metadata[:version]}
        @bosh_director.upload_stemcell(stemcell_path)
      end
      metadata
    end

    def set_manifest_file(manifest_file)
      @deployment_command.options.merge!(:config => manifest_file, :deployment => manifest_file)
    end

    def self.raise_on_error!(bosh_cmd)
      raise 'Error running command' unless bosh_cmd.exit_code == 0
    end

    private

    def downloadable_uri?(resource)
      uri = URI.parse(resource)
      uri.scheme == 'http' or uri.scheme == 'https'
    end

    def bosh_contains_deployment?(expected_deployment_name)
      deployments = @bosh_director.list_deployments
      deployments.any? do |deployment_json|
        deployment_json = JSON.parse(deployment_json.to_json)
        deployment_json['name'] == expected_deployment_name
      end
    end

    def verify_and_upload_stemcell_to_director(stemcell_uri)
      @bosh_director.upload_stemcell(stemcell_uri)
      stemcell_manager.get_stemcell_name_and_version(stemcell_uri)
    end

  end
end
