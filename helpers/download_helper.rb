module BoshMediator
  module DownloadHelper

    def download_url(download_url, download_path, headers = {})
      uri = URI.parse(download_url)
      http = Net::HTTP.new(uri.host, uri.port)
      
      if uri.scheme.downcase == 'https'
        http.use_ssl = true 
        http.ca_file = File.join(Dir.pwd, 'bosh-mediator', 'certs', 'cacert.pem')
        http.verify_mode = OpenSSL::SSL::VERIFY_PEER
        http.verify_depth = 5
      end

      http.request_get(uri.path, headers) do |resp|
        case resp.code
        when '304' then break # Do nothing, we already have the resource
        when '200'
          begin
            f = File.open(download_path, 'wb')
            resp.read_body do |segment|
              f.write(segment)
            end
          ensure
            f.close if f
          end
        else
          raise "Problem downloading resource: #{download_url}"
        end
      end
      puts download_path
      download_path
    end

  end
end