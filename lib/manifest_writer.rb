require 'fileutils'
require 'yaml'

module BoshMediator
  class ManifestWriter

    def initialize(manifest_file, stemcell_release_info, spiff_dir = nil)
      @manifest_file = manifest_file
      @stemcell_release_info = stemcell_release_info
      @spiff_dir = spiff_dir
    end

    def parse_and_merge_file
      output_manifest = File.join(Dir.pwd, 'output-manifest.yml')

      Dir.mktmpdir do |dir|
        parsed_erb = set_manifest_stemcell_release_info
        output_erb = File.join(dir, 'output-erb.yml')

        File.open(output_erb, 'w') do |f|
          f.write(parsed_erb)
        end

        if @spiff_dir
          spiff_merge(output_erb, output_manifest)
        else
          FileUtils.cp(output_erb, output_manifest)
        end
      end

      output_manifest
    end

    private

    def set_manifest_stemcell_release_info
      unless [:name, :version, :release_version].all?{|k| @stemcell_release_info[k]}
        raise 'The provided stemcell name and version was malformed'
      end
      unless File.exists? @manifest_file
        raise "The provided release manifest - #{@manifest_file} - does not exist"
      end
      sc_name = @stemcell_release_info[:name]
      sc_version = @stemcell_release_info[:version]
      cf_release = @stemcell_release_info[:release_version]

      puts "*** Updating stemcell name and version ***"
      puts "*** - on template manifest #{@manifest_file} ***"

      eruby = Erubis::Eruby.new(File.read(@manifest_file), :pattern=>'<!--% %-->')
      eruby.result(
        'stemcell_name' => sc_name,
        'stemcell_version' => sc_version,
        'cf_release' => cf_release
      )
    end

    def spiff_merge(erb_output_manifest, output_manifest)
      files = ['networks.yml', 'env.yml'].map do |f| 
        path = File.join(@spiff_dir, f)
        path if File.exists?(path)
      end.compact.join(' ')
      
      puts "*** Merging in Spiff templates ***"
      puts "*** - from #{@spiff_dir} ***"
      puts "*** - to #{output_manifest} ***"

      `spiff merge #{erb_output_manifest} #{files} > #{output_manifest}`
      raise "Spiff error" unless $?.success?
    end

  end
end