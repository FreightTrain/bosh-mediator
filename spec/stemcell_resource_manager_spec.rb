require_relative "../lib/stemcell_resource_manager"

module BoshMediator
  describe 'Given a Stemcell Resource Manager' do

    let(:expected_stemcell_metadata) do
      expected_stemcell_metadata = {:name => "bosh-stemcell", :version => "0.7.0"}
    end

    let(:valid_stemcell) do
      File.expand_path(File.dirname(__FILE__)) + "/assets/stemcells/bosh-stemcell-vsphere-0.7.0.tgz"
    end

    let(:broken_stemcell) do
      File.expand_path(File.dirname(__FILE__)) + "/assets/stemcells/broken.tgz"
    end

    let(:stemcell_manager){ StemcellResourceManager.new }

    context "When attempting to download a stemcell" do
      context "when the file exists locally already" do

        it 'downloads a stemcell successfully from a URL' do
          stemcell_file_name = "stemcell.tgz"
          local_downloaded_stemcell_resource = "#{Dir.tmpdir}/#{stemcell_file_name}"
          expect(File).to receive(:exists?).at_least(:once).and_return(true)
          expect(File).to receive(:mtime).and_return(Time.at(1383737141))

          stemcell_url = "http://www.example.com/#{stemcell_file_name}"
          expected_stemcell_file_contents = File.open(valid_stemcell, "rb") { |io| io.read }

          stubbed_response = double(::Net::HTTPResponse)
          stubbed_response.stub(:parsed_response) { expected_stemcell_file_contents }
          stubbed_response.stub(:code) { '304' }
          expect_any_instance_of(::Net::HTTP).to receive(:request_get).with("/#{stemcell_file_name}",
            {'If-Modified-Since' => 'Wed, 6 Nov 2013 11:25:41 +0000'} ).and_yield(stubbed_response)
          stemcell_manager.download_stemcell(stemcell_url)
        end
      end

      context "when the file does not exist locally" do
        it 'downloads a stemcell successfully from a URL' do
          stemcell_file_name = "stemcell.tgz"
          begin
            stemcell_url = "http://www.example.com/#{stemcell_file_name}"
            expected_stemcell_file_contents = File.open(valid_stemcell, "rb") { |io| io.read }

            stubbed_response = double(::Net::HTTPResponse)
            stubbed_response.stub(:resp) { expected_stemcell_file_contents }
            stubbed_response.stub(:code) { '200' }
            expect_any_instance_of(::Net::HTTP).to receive(:request_get).with("/#{stemcell_file_name}", {} ).and_yield(stubbed_response)
            expect(stubbed_response).to receive(:read_body).and_yield(expected_stemcell_file_contents)
            local_downloaded_stemcell_resource = stemcell_manager.download_stemcell(stemcell_url)
            downloaded_file_data = File.open(local_downloaded_stemcell_resource, "rb") { |io| io.read }
            expect(downloaded_file_data).to eq expected_stemcell_file_contents
          ensure
            File.delete(local_downloaded_stemcell_resource) if File.exists?(local_downloaded_stemcell_resource)
          end
        end
      end

      it 'raises an error on webserver error codes' do
        stemcell_file_name = "stemcell.tgz"
        local_downloaded_stemcell_resource = "#{Dir.tmpdir}/#{stemcell_file_name}"
        begin
          stemcell_url = "http://www.example.com/#{stemcell_file_name}"
          stubbed_response = double(::Net::HTTPResponse)
          stubbed_response.stub(:code) { '404' }
          expect_any_instance_of(::Net::HTTP).to receive(:request_get).with("/#{stemcell_file_name}", {} ).and_yield(stubbed_response)
          expect do
            stemcell_manager.download_stemcell(stemcell_url)
          end.to raise_error("Problem downloading resource: #{stemcell_url}")
        ensure
          File.delete(local_downloaded_stemcell_resource) if File.exists?(local_downloaded_stemcell_resource)
        end

      end
    end

    context 'When interrogating stemcell metadata' do
      it 'retrieves the stemcell name and version from a local stemcell' do
        metadata = stemcell_manager.get_stemcell_name_and_version(valid_stemcell)
        expect(metadata).to eq(expected_stemcell_metadata)
      end

      it 'raises an error when interrogating an invalid stemcell' do
        expect do
          stemcell_manager.get_stemcell_name_and_version(broken_stemcell)
        end.to raise_error(InvalidStemcellResourceError, "The provided uri #{broken_stemcell} does not point to a valid stemcell resource")
      end
    end

  end
end
