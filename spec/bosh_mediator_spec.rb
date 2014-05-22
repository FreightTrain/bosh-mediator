require 'rspec'
require 'cli'
require 'json'

require_relative "../lib/bosh_mediator"
require_relative "../lib/stemcell_resource_manager"

module BoshMediator
  describe 'BoshMediator handles communication Bosh without using the CLI interface' do

    let(:assets_dir) do
      File.expand_path(File.dirname(__FILE__)) + "/assets"
    end

    before :each do
      @bosh_director = double(Bosh::Cli::Client::Director)
      @release_command = double(Bosh::Cli::Command::Release)
      @deployment_command = double(Bosh::Cli::Command::Deployment.new)
      @mediator = BoshMediator.new(:director => @bosh_director,
                                   :release_command => @release_command,
                                   :deployment_command => @deployment_command)
      Dir.chdir(assets_dir)
    end

    let(:stemcell_test_asset) do
      stemcell_test_asset = File.expand_path(File.dirname(__FILE__)) + "/assets/stemcells/bosh-stemcell-vsphere-0.7.0.tgz"
    end

    let(:cd_to_assets_dir) do
      Dir.chdir(assets_dir)
    end

    context 'when initializing an instance of Bosh Mediator' do

      it 'configures bosh cli options' do
        Bosh::Cli::Config.output.should eq STDOUT
        Bosh::Cli::Config.interactive.should eq false
        Bosh::Cli::Config.colorize.should eq true
      end

    end

    context 'when attempting to upload a Bosh release' do

      let(:expected_release_array) do
        [{'name'=>'bosh-release',
          'release_versions'=>
           [{'version'=>'0.13-dev',
             'commit_hash'=>'b6729f79',
             'uncommitted_changes'=>true,
             'currently_deployed'=>true,
             'job_names'=>
              ['rabbitmq-server', 'phantom', 'rabbitmq_gateway', 'haproxy']}]},
         {'name'=>'cf',
          'release_versions'=>
           [{'version'=>'142',
             'commit_hash'=>'cdcd5c37',
             'uncommitted_changes'=>true,
             'currently_deployed'=>true,
             'job_names'=>
              ['saml_login', 'gorouter', 'syslog_aggregator', 'narc', 'postgres',
               'cloud_controller_ng', 'uaa', 'dea_next', 'debian_nfs_server',
               'loggregator', 'loggregatorrouter', 'collector', 'nats',
               'dea_logging_agent', 'login', 'health_manager_next', 'dashboard']
            }]},
         {'name'=>'jenkins',
          'release_versions'=>
           [{'version'=>'1.1-dev',
             'commit_hash'=>'6a1818aa',
             'uncommitted_changes'=>true,
             'currently_deployed'=>false,
             'job_names'=>['jenkins_master']},
            {'version'=>'1.2-dev',
             'commit_hash'=>'7c800642',
             'uncommitted_changes'=>true,
             'currently_deployed'=>false,
             'job_names'=>['jenkins_master']},
            {'version'=>'1.3-dev',
             'commit_hash'=>'6cf0bd94',
             'uncommitted_changes'=>true,
             'currently_deployed'=>false,
             'job_names'=>['jenkins_master']},
            {'version'=>'1.4-dev',
             'commit_hash'=>'44ebeac0',
             'uncommitted_changes'=>true,
             'currently_deployed'=>true,
             'job_names'=>['jenkins_master']}]}]
      end

      it 'does not attempt to upload a release that already exists in the bosh director by name and version' do
        test_release_file_name = "#{assets_dir}/existing_release_file.yml"
        @bosh_director.should_receive(:list_releases).and_return(expected_release_array)
        @mediator.upload_release(test_release_file_name)
      end

      context 'release does not exist' do

        let(:test_release_file_name) { "#{assets_dir}/unexisting_release_file.yml" }

        before do
          @bosh_director.should_receive(:list_releases).and_return(expected_release_array)
          @release_command.should_receive(:upload).with(test_release_file_name)
        end

        it 'attempts to upload the release' do
          @release_command.should_receive(:exit_code).and_return(0)
          @mediator.upload_release(test_release_file_name)
        end

        it 'raises when the upload fails' do
          @release_command.should_receive(:exit_code).and_return(1)
          expect{ @mediator.upload_release(test_release_file_name) }.to raise_error
        end

      end
    end

    context 'when attempting to deploy a release to Bosh' do

      it 'deploys a provided deployment manifest file' do
        @deployment_command.should_receive(:perform)
        @deployment_command.should_receive(:exit_code).and_return(0)
        @mediator.deploy
      end

      it 'raises when the deployment is unsuccessful' do
        @deployment_command.should_receive(:perform)
        @deployment_command.should_receive(:exit_code).and_return(1)
        expect{ @mediator.deploy }.to raise_error
      end

    end

    context 'when attempting to delete a deployment from Bosh' do

      let(:expected_deployments) do
        [
            {'name' => 'deployment_a'},
            {'name' => 'deployment_b'},
            {'name' => 'deployment_c'}
        ]
      end

      it 'deletes any existing deployment' do
        deployment_name = 'deployment_c'
        @bosh_director.should_receive(:list_deployments).and_return(expected_deployments)
        @deployment_command.should_receive(:delete).with(deployment_name)
        @deployment_command.should_receive(:exit_code).and_return(0)
        @mediator.delete_deployment(deployment_name)
      end

      it 'raises if the deletion fails' do
        deployment_name = 'deployment_c'
        @bosh_director.should_receive(:list_deployments).and_return(expected_deployments)
        @deployment_command.should_receive(:delete).with(deployment_name)
        @deployment_command.should_receive(:exit_code).and_return(1)
        expect { @mediator.delete_deployment(deployment_name) }.to raise_error
      end

      it 'attempts to delete a deployment that does not exist' do
        @bosh_director.should_receive(:list_deployments).and_return(expected_deployments)
        @mediator.delete_deployment("some random deployment name")
      end

      it 'does not attempt to delete a deployment if there are no deployments' do
        @bosh_director.should_receive(:list_deployments).and_return([])
        @mediator.delete_deployment("some random deployment name")
      end

    end

    context 'when attempting to create a Bosh release' do

      it 'raises an exception if not in a releases directory when creating a release' do
        Dir.chdir(Dir.tmpdir)
        expect { @mediator.set_dev_release_name("release_name") }.to raise_error("This directory is not a release directory - #{Dir.pwd}")
      end

      it 'creates a release' do
        @release_command.should_receive(:create)
        @mediator.create_release("release_name")
      end

      it 'sets a dev release name correctly when creating a release' do
        dev_release_config = "config/dev.yml"

        begin
          test_dev_release_name = "foo"
          @mediator.set_dev_release_name(test_dev_release_name)
          actual_yaml = YAML.load_file(dev_release_config)
          actual_yaml['dev_name'].should eq test_dev_release_name
        ensure
          File.delete dev_release_config if File.exists? dev_release_config
        end
      end

      it 'finds the build info for a given dev build' do
        filename = '/release/dir/foo-1.yml'
        tarball = '/release/dir/foo-1.tgz'
        md5sum = '4cf7054d7cae596de6039aaf4cc92e10'
        release_yaml = {"name"=>"bosh-release", "version"=>"0.4-dev", "foo"=>"bar"}
        expect(YAML).to receive(:load_file).with(filename).and_return(release_yaml)
        expect(File).to receive(:read).with(tarball)
        expect(Digest::MD5).to receive(:hexdigest).and_return(md5sum)
        expect(@mediator.release_info(filename)).to eq({:name=>"bosh-release", :version=>"0.4-dev", :tarball=>tarball, :md5sum=>md5sum})

      end

    end

    context 'when attempting to specify a stemcell' do

      let(:stemcell_file_name) do
        "bosh-stemcell-vsphere-0.7.0.tgz"
      end

      let(:stemcell_name_and_version) do
        {:name => 'bosh-stemcell', :version => '0.7.0'}
      end

      let(:stemcell_info) do
        stemcell_name_and_version.merge({:md5sum => '0f71933e54d2cc7589723861054fcce9', :tarball => "#{assets_dir}/stemcells/#{stemcell_file_name}" })
      end

      context :stemcell_present do

        let(:stemcell_list) do
          [
            {"name" => "bosh-stemcell", "version" => "0.7.0", "cid" => "sc-24dcd303-3fb6-4002-8eb3-914b7eca0208" },
            {"name" => "bosh-stemcell", "version" => "992", "cid" => "sc-14dcd303-3fb6-4002-8eb3-914b7eca0208" },
            {"name" => "bosh-vsphere-esxi-centos", "version" => "1087", "cid" => "sc-16081d73-3a9e-4cac-85a7-8267de7128ea" },
            {"name" => "bosh-vsphere-esxi-ubuntu", "version" => "1100", "cid" => "sc-dc88ce6d-9f8e-4b1a-92b6-239b0f1d83e4" }
          ]
        end

        it 'does not attempt to upload a stemcell that already exists in the bosh director' do
          @bosh_director.should_receive(:list_stemcells).and_return(stemcell_list)
          @bosh_director.should_not_receive(:upload_stemcell)
          @mediator.upload_stemcell_to_director(stemcell_test_asset)
        end

      end

      context :stemcell_not_present do

        let(:stemcell_list) do
          [
            {"name" => "bosh-stemcell", "version" => "992", "cid" => "sc-14dcd303-3fb6-4002-8eb3-914b7eca0208" },
            {"name" => "bosh-vsphere-esxi-centos", "version" => "1087", "cid" => "sc-16081d73-3a9e-4cac-85a7-8267de7128ea" },
            {"name" => "bosh-vsphere-esxi-ubuntu", "version" => "1100", "cid" => "sc-dc88ce6d-9f8e-4b1a-92b6-239b0f1d83e4" }
          ]
        end

        it 'successfully uploads a stemcell if a valid remote url is provided' do

          stemcell_url = "http://www.example.com/#{stemcell_file_name}"
          downloaded_stemcell_file_path = "#{Dir.tmpdir}/#{stemcell_file_name}"

          @mediator.stemcell_manager = double(StemcellResourceManager)
          @mediator.stemcell_manager.should_receive(:download_stemcell).with(stemcell_url).and_return(downloaded_stemcell_file_path)
          @bosh_director.should_receive(:list_stemcells).and_return(stemcell_list)
          @bosh_director.should_receive(:upload_stemcell).with(downloaded_stemcell_file_path)
          @mediator.stemcell_manager.should_receive(:get_stemcell_name_and_version).with(downloaded_stemcell_file_path).and_return(stemcell_name_and_version)

          actual = @mediator.upload_stemcell_to_director(stemcell_url)
          expect(actual).to eq(stemcell_name_and_version)

        end

        it 'successfully uploads a stemcell if a valid local file path is provided' do
          @mediator.stemcell_manager = double(StemcellResourceManager)
          @mediator.stemcell_manager.should_receive(:get_stemcell_name_and_version).with(stemcell_test_asset).and_return(stemcell_name_and_version)
          @bosh_director.should_receive(:list_stemcells).and_return(stemcell_list)
          @bosh_director.should_receive(:upload_stemcell).with(stemcell_test_asset)
          actual = @mediator.upload_stemcell_to_director(stemcell_test_asset)
          expect(actual).to eq(stemcell_name_and_version)
        end

        it 'raises if a stemcell file cannot be found' do
          expect {
            @mediator.upload_stemcell_to_director("file/does/not/exist")
          }.to raise_error InvalidStemcellResourceError,
            "The provided uri file/does/not/exist does not point to a valid stemcell resource"
        end

        it 'returns the stemcell info from a stemcell' do
          @mediator.stemcell_manager = StemcellResourceManager.new
          @mediator.stemcell_manager.should_receive(:get_stemcell_name_and_version).with(stemcell_test_asset).and_return(stemcell_name_and_version)
          stemcell_info_result = @mediator.stemcell_manager.get_stemcell_info(stemcell_test_asset)
          expect(stemcell_info_result).to eq(stemcell_info)
        end

      end

    end
  end
end
