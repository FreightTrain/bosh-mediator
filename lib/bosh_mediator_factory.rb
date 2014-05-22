require 'cli'
require_relative 'bosh_mediator'

module BoshMediator
  module BoshMediatorFactory

    def create_bosh_mediator(bosh_director_uri, username, password, release_dir)
      cd_to_release_dir!(release_dir)
      bosh_director = Bosh::Cli::Client::Director.new(bosh_director_uri, username, password)

      deployment_command = Bosh::Cli::Command::Deployment.new
      options = { :target => bosh_director_uri,
                  :username => username,
                  :password => password,
                  :non_interactive => true,
                  :force => true }

      deployment_command.options = options

      BoshMediator.new(:director => bosh_director,
                       :release_command => release_command(options),
                       :deployment_command => deployment_command)
    end

    def create_local_bosh_mediator(release_dir)
      cd_to_release_dir!(release_dir)
      BoshMediator.new(:release_command => release_command)
    end

    private

    def cd_to_release_dir!(release_dir)
      unless File.directory?(release_dir)
        raise ArgumentError, "Release directory does not exist: #{release_dir}"
      end
      Dir.chdir(release_dir)
    end

    def release_command(options = {})
      release_command = Bosh::Cli::Command::Release.new
      options.merge!(:force => true, :with_tarball => true)
      release_command.options = options
      release_command
    end

  end
end
