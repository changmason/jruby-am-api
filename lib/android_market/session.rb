require File.dirname(__FILE__) + "/tools"

module AndroidMarket
  class Session
    
    java_import com.gc.android.market.api.model.Market
    java_import com.gc.android.market.api.model.Market::Request
    java_import com.gc.android.market.api.model.Market::Response
    java_import com.gc.android.market.api.model.Market::RequestContext
    java_import com.gc.android.market.api.model.Market::Request::RequestGroup

    SERVICE   = "android"
    URL_LOGIN = "https://www.google.com/accounts/ClientLogin"
    PROTOCOL_VERSION = 2
    ACCOUNT_TYPE = { :google => 'GOOGLE',
                     :hosted => 'HOSTED',
                     :both   => 'HOSTED_OR_GOOGLE' }

    attr_accessor :context_builder, :auth_sub_token

    def initialize
      @callbacks = []
      @request_builder = Request.new_builder()
      @context_builder = RequestContext.new_builder()

      @context_builder.set_unknown1(0)
      @context_builder.set_version(1002)
      @context_builder.set_android_id("0000000000000000")
      @context_builder.set_device_and_sdk_version("sapphire:7")
      set_locale(JavaUtil::Locale.get_default)
      set_operator_tmobile
    end

    def set_locale(locale)
      @context_builder.set_user_language(locale.language.downcase)
      @context_builder.set_user_country(locale.country.downcase)
    end

    def set_operator(alpha, sim_alpha, numeric, sim_numeric)
      @context_builder.set_operator_alpha(alpha)
      @context_builder.set_sim_operator_alpha(sim_alpha)
      @context_builder.set_operator_numeric(numeric)
      @context_builder.set_sim_operator_numeric(sim_numeric)
    end

    def set_operator_tmobile
      set_operator("T-Mobile", "T-Mobile", "310260", "310260")
    end

    def set_operator_sfr
      set_operator("F SFR", "F SFR", "20810", "20810")
    end

    def set_operator_o2
      set_operator("o2 - de","o2 - de", "26207", "26207")
    end

    def set_operator_simyo
      set_operator("E-Plus", "simyo", "26203", "26203")
    end

    def set_operator_sunrise
      set_operator("sunrise", "sunrise", "22802", "22802")
    end

    def set_auth_sub_token(auth_sub_token)
      @context_builder.set_auth_sub_token(auth_sub_token)
      self.auth_sub_token = auth_sub_token
    end

    def login(email, password, account_type = ACCOUNT_TYPE[:both])
      params = { 'Email'   => email,
                 'Passwd'  => password,
                 'service' => SERVICE,
                 'accountType' => account_type }
      Tools.post_url(URL_LOGIN, params)[/Auth=(.{200,204})$/i]
      if auth_key = $1
        set_auth_sub_token(auth_key)
      else
        raise RuntimeError, "auth_key not found"
      end
    end


    def append(request_group, &block)
      case request_group
      when Market::AppsRequest
        @request_builder.add_request_group(RequestGroup.new_builder.set_apps_request(request_group))
      when Market::GetImageRequest
        @request_builder.add_request_group(RequestGroup.new_builder.set_image_request(request_group))
      when Market::CommentsRequest
        @request_builder.add_request_group(RequestGroup.new_builder.set_comments_request(request_group))
      when Market::CategoriesRequest
        @request_builder.add_request_group(RequestGroup.new_builder.set_categories_request(request_group))
      end
      @callbacks << block if block_given?
    end


    def flush
      context = @context_builder.build
      @context_builder = RequestContext.new_builder(context)
      @request_builder.set_context(context)

      response = execute_protobuf(@request_builder.build)
      response.get_response_group_list.to_a.each do |res|
        value = res.get_apps_response if res.has_apps_response
        value = res.get_categories_response if res.has_categories_response
        value = res.get_comments_response if res.has_comments_response
        value = res.get_image_response if res.has_image_response
        @callbacks.first.call(context, value)
      end

      @request_builder = Request.new_builder
      @callbacks.clear
    end


#    def execute(request_group, &block)
#      case request_group
#      when Market::AppsRequest
#        @request_builder.add_request_group(RequestGroup.new_builder.set_apps_request(request_group))
#      when Market::GetImageRequest
#        @request_builder.add_request_group(RequestGroup.new_builder.set_image_request(request_group))
#      when Market::CommentsRequest
#        @request_builder.add_request_group(RequestGroup.new_builder.set_comments_request(request_group))
#      when Market::CategoriesRequest
#        @request_builder.add_request_group(RequestGroup.new_builder.set_categories_request(request_group))
#      end
#      context = @context_builder.build
#      @context_builder = RequestContext.new_builder(context)
#      @request_builder.set_context(context)
#      response = execute_protobuf(@request_builder.build)
#
#
#      block.call(ctxt, resp) if block_given?
#
#      @request_builder = Request.new_builder
#
#      return resp
#    end


    def execute_protobuf(request)
      request_string = String.from_java_bytes(request.to_byte_array)
      response_bytes = execute_raw_http_query(request_string)
      begin
        return Response.parse_from(response_bytes)
      rescue => ex
        raise RuntimeError, ex.message
      end
    end


    def execute_raw_http_query(request)
      url = JavaNet::URL.new("http://android.clients.google.com/market/api/ApiRequest")
      connection = url.open_connection
      connection.set_do_output(true)
      connection.set_request_method('POST')
      connection.set_request_property('Cookie','ANDROID=' + @auth_sub_token)
      connection.set_request_property('User-Agent', 'Android-Market/2 (sapphire PLAT-RC33); gzip')
      connection.set_request_property('Content-Type', 'application/x-www-form-urlencoded')
      connection.set_request_property('Accept-Charset','ISO-8859-1,utf-8;q=0.7,*;q=0.7')

      request64 = Tools.urlsafe_encode64(request)
      request_data = "version=#{PROTOCOL_VERSION}&request=#{request64}".to_java

      connection.set_fixed_length_streaming_mode(request_data.get_bytes("UTF-8").length)
      os = connection.get_output_stream
      os.write(request_data.get_bytes)
      os.close

      if connection.get_response_code >= 400
        raise RuntimeError, "Response Code = #{connection.get_response_code}, " +
                            "Message = #{connection.get_response_message}"
      end

      is = connection.get_input_stream
      gz_is = java.util.zip::GZIPInputStream.new(is)
      ba_os = java.io::ByteArrayOutputStream.new
      buff = Java::byte[1024].new #"a buffer string".to_java_bytes
      while(true) do
        nb = gz_is.read(buff)
        nb < 0 ? break : ba_os.write(buff, 0, nb)
      end
      is.close
      connection.disconnect

      return ba_os.to_byte_array
    end
    
  end # end of class
end # end of module
