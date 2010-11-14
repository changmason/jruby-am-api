module AndroidMarket
  module Tools

    #module_function :urlsafe_encode64, :post_url
    
    def self.urlsafe_encode64(bin)
      [bin].pack("m0").tr("+/", "-_").gsub("\n","")
    end


    def self.post_url(url, params)
      data = params.map { |key, val|
        java.net::URLEncoder.encode(key, "UTF-8") + "=" +
        java.net::URLEncoder.encode(val, "UTF-8")
      }.join("&")
      connection = java.net::URL.new(url).open_connection
      connection.set_do_output(true)
      connection.set_do_input(true)
      connection.set_request_method("POST")

      stream_to_authorize = java.io::OutputStreamWriter.new(connection.get_output_stream)
      stream_to_authorize.write(data)
      stream_to_authorize.flush
      stream_to_authorize.close

      result_stream = connection.get_input_stream
      reader = java.io::BufferedReader.new(java.io::InputStreamReader.new(result_stream))
      response = java.lang::StringBuffer.new
      while line = reader.read_line do
        response.append(line)
      end
      result_stream.close
      response.to_string
    end

  end
end
