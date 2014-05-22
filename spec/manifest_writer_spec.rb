require 'cli'

require_relative "../lib/bosh_mediator"
require_relative "../lib/manifest_writer"

module BoshMediator
  describe 'BoshMediator handles writing a valid manifest' do

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

    context 'When specifying a stemcell name and version for the deployment manifest' do

      let(:manifest_file) do
        "#{assets_dir}/deploy_manifest_file.yml"
      end
      let(:broken_manifest_file) do
        "#{assets_dir}/broken_deploy_manifest_file.yml"
      end

      it 'updates the manifest with the correct name, version and release version' do
        test_manifest = "#{assets_dir}/update_stemcell_test.yml"

        begin
          s_version = 'new_version'
          s_name = 'new_name'
          release_version = YAML.load_file(File.join(assets_dir, 'existing_release_file.yml'))['version']

          FileUtils.copy_file(manifest_file, test_manifest)

          @manifest_writer = ManifestWriter.new(test_manifest, {name: s_name, version: s_version, release_version: release_version}, nil)
          new_manifest_path = @manifest_writer.parse_and_merge_file
          manifest_contents = File.read(new_manifest_path)
          stemcell_vars = Hash[manifest_contents.scan(/.*stemcells:\n\s+stemcell_name: (.*)\n\s+stemcell_version: (.*)\n/)]
          expect(stemcell_vars).to eq({s_name => s_version})

          release_vars = manifest_contents.scan(/releases:\n+-+\s+name:\s+cf\n\s+version:\s+(.*)/).flatten
          expect(release_vars.include?(release_version)).to eq(true)
        ensure
          File.delete(test_manifest) if File.exists? test_manifest
          File.delete(new_manifest_path) if File.exists? new_manifest_path
        end
      end

      it 'raises an exception when the provided release manifest is malformed' do
        test_manifest = "#{assets_dir}/update_stemcell_test2.yml"
        begin
          s_version = 'new_version'
          s_name = 'new_name'
          release_version = YAML.load_file(File.join(assets_dir, 'existing_release_file.yml'))['version']
          FileUtils.copy_file(broken_manifest_file, test_manifest)

          expect {
            @manifest_writer = ManifestWriter.new(test_manifest, {name: s_name, version: s_version, release_version: release_version}, nil)
            new_manifest_path = @manifest_writer.parse_and_merge_file
          }.to raise_error
        ensure
          File.delete(test_manifest) if File.exists? test_manifest
        end
      end

      it 'raises an exception when the provided release manifest does not exist' do
        expect {
          @manifest_writer = ManifestWriter.new("assets/non-existant-file.yml", {name: 'name', version: '0.7.0', release_version: '1.4-dev'}, nil)
          new_manifest_path = @manifest_writer.parse_and_merge_file
        }.to raise_error("The provided release manifest - assets/non-existant-file.yml - does not exist")
      end

      it 'raises an exception when the provided name and version are invalid' do
        expect {
          @manifest_writer = ManifestWriter.new("assets/non-existant-file.yml", {name: 'name'}, nil)
          new_manifest_path = @manifest_writer.parse_and_merge_file
        }.to raise_error("The provided stemcell name and version was malformed")
      end

    end
  end
end