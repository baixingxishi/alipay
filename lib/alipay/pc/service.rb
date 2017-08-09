module Alipay
  module Pc
    module Service
      ALIPAY_TRADE_PAGE_PAY_REQUIRED_PARAMS = %w(biz_content notify_url return_url)

      def self.alipay_trade_page_pay(params, options = {})
        params = Utils.stringify_keys(params)
        Alipay::Service.check_required_params(params, ALIPAY_TRADE_PAGE_PAY_REQUIRED_PARAMS)
        key = options[:key] || Alipay.key
        sign_type = (options[:sign_type] || :rsa2).to_s.upcase
        params = {
            'method'         => 'alipay.trade.page.pay',
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
    end
  end
end
