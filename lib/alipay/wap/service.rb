module Alipay
  module Wap
    module Service
      GATEWAY_URL = 'https://wappaygw.alipay.com/service/rest.htm'

      TRADE_CREATE_DIRECT_TOKEN_REQUIRED_PARAMS = %w( req_data )
      REQ_DATA_REQUIRED_PARAMS = %w( seller_account_name subject out_trade_no total_fee call_back_url )
      def self.trade_create_direct_token(params, options = {})
        params = Utils.stringify_keys(params)
        Alipay::Service.check_required_params(params, TRADE_CREATE_DIRECT_TOKEN_REQUIRED_PARAMS)

        req_data = Utils.stringify_keys(params.delete('req_data'))
        Alipay::Service.check_required_params(req_data, REQ_DATA_REQUIRED_PARAMS)

        xml = req_data.map {|k, v| "<#{k}>#{v.encode(:xml => :text)}</#{k}>" }.join
        req_data_xml = "<direct_trade_create_req>#{xml}</direct_trade_create_req>"

        # About req_id: http://club.alipay.com/read-htm-tid-10078020-fpage-2.html
        params = {
          'service'  => 'alipay.wap.trade.create.direct',
          'req_data' => req_data_xml,
          'partner'  => options[:pid] || Alipay.pid,
          'req_id'   => Time.now.strftime('%Y%m%d%H%M%s'),
          'format'   => 'xml',
          'v'        => '2.0'
        }.merge(params)

        xml = Net::HTTP.get(request_uri(params, options))
        CGI.unescape(xml).scan(/\<request_token\>(.*)\<\/request_token\>/).flatten.first
      end

      AUTH_AND_EXECUTE_REQUIRED_PARAMS = %w( request_token )
      def self.auth_and_execute_url(params, options = {})
        params = Utils.stringify_keys(params)
        Alipay::Service.check_required_params(params, AUTH_AND_EXECUTE_REQUIRED_PARAMS)

        req_data_xml = "<auth_and_execute_req><request_token>#{params.delete('request_token')}</request_token></auth_and_execute_req>"

        params = {
          'service'  => 'alipay.wap.auth.authAndExecute',
          'req_data' => req_data_xml,
          'partner'  => options[:pid] || Alipay.pid,
          'format'   => 'xml',
          'v'        => '2.0'
        }.merge(params)

        request_uri(params, options).to_s
      end

      def self.security_risk_detect(params, options)
        params = Utils.stringify_keys(params)

        params = {
          'service' => 'alipay.security.risk.detect',
          '_input_charset' => 'utf-8',
          'partner' => options[:pid] || Alipay.pid,
          'timestamp' => Time.now.strftime('%Y-%m-%d %H:%M:%S'),
          'scene_code' => 'PAYMENT'
        }.merge(params)

        sign_params(params, options)

        Net::HTTP.post_form(URI(GATEWAY_URL), params)
      end

      def self.alipay_trade_wap_pay(params, options = {})
        params = Utils.stringify_keys(params)
        Alipay::Service.check_required_params(params, ::Alipay::Pc::Service::ALIPAY_TRADE_PAGE_PAY_REQUIRED_PARAMS)
        key = options[:key] || Alipay.key
        sign_type = (options[:sign_type] || :rsa2).to_s.upcase
        params = {
            'method'         => 'alipay.trade.wap.pay',
            'charset'        => 'utf-8',
            'version'        => '1.0',
            'timestamp'      => Time.now.utc.strftime('%Y-%m-%d %H:%M:%S').to_s,
            'sign_type'      => sign_type,
            'app_id'         => options[:app_id] || Alipay.pid
        }.merge(params)
        string = Alipay::App::Sign.params_to_sorted_string(params)
        sign = case sign_type
                 when 'RSA'
                   ::Alipay::Sign::RSA.sign(key, string)
                 when 'RSA2'
                   ::Alipay::Sign::RSA2.sign(key, string)
                 else
                   raise ArgumentError, "invalid sign_type #{sign_type}, allow value: 'RSA', 'RSA2'"
               end

        Alipay::Pc::Sign.params_to_encoded_string params.merge('sign' => sign)
      end

      def self.request_uri(params, options = {})
        uri = URI(GATEWAY_URL)
        uri.query = URI.encode_www_form(sign_params(params, options))
        uri
      end

      SIGN_TYPE_TO_SEC_ID = {
        'MD5' => 'MD5',
        'RSA' => '0001'
      }

      def self.sign_params(params, options = {})
        sign_type = (options[:sign_type] ||= Alipay.sign_type)
        params = params.merge('sec_id' => SIGN_TYPE_TO_SEC_ID[sign_type])
        params.merge('sign' => Alipay::Sign.generate(params, options))
      end
    end
  end
end
