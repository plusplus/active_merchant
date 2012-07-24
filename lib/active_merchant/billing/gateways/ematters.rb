module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class EmattersGateway < Gateway
      TEST_URL = 'https://merchant.ematters.com.au/cmaonline.nsf/XML'
      LIVE_URL = 'https://merchant.ematters.com.au/cmaonline.nsf/XML'

      # The countries the gateway supports merchants from as 2 digit ISO country codes
      self.supported_countries = ['AU']

      # The card types supported by the payment gateway
      self.supported_cardtypes = [:visa, :master] #, :american_express, :discover]

      # The homepage URL of the gateway
      self.homepage_url = 'http://ematters.com.au'

      # The name of the gateway
      self.display_name = 'eMatters'

      MESSAGES = {
        "01" => "See card issuer.",
        "04" => "Call authorisation centre.",
        "08" => "Transaction approved.",
        "12" => "Invalid transaction type.",
        "31" => "See card issuer.",
        "33" => "Card Expired",
        "51" => "Insufficient funds.",
        "61" => "Over card refund limit.",
        "91" => "Issuer not available.",
        "96" => "CVV invalid or missing",
        "702" => "Transaction still underway",
        "707" => "3SO Activated - too many failed attempts",
        "708" => "Non-Unique UID - Already accepted",
        "710" => "IGP Activated - transaction from high risk country",
        "711" => "IGP Activated - IP Address Not Valid",
        "712" => "Fraud Screen block - IP and Bank not matching.",
        "714" => "Card from outside acceptable country range",
        "810" => "Invalid Purchase Amount",
        "812" => "Unacceptable Card Number",
        "813" => "Invalid Expiry Date Format",
        "816" => "Card Expired",
        "817" => "Invalid Merchant Details",
        "871" => "Nothing Found",
        "872" => "Too Many Found",
        "873" => "Exceeds Original Amount",
        "874" => "Already Refunded",
        "875" => "Wrong Credentials",
        "878" => "Incorrect UID Format",
        "901" => "H-Check Failed - URLs do not match",
        "902" => "Readers set to an incorrect value in POSTed Transaction",
        "903" => "Readers missing in POSTed transaction",
        "904" => "MerchantID missing in POSTed transaction",
        "910" => "Transaction Aborted",
        "911" => "XML Error .",
        "919" => "Dodgy Details",
        "921" => "BlackList Invoked",
        "932" => "Bad Posting Password",
        "980" => "Host Not Found, Bank System out of action",
        "990" => "Carrier Lost, Bank line down 999 Bad Card Length - Too Short",
        "xx" => "Transaction in progress"
      }

      def initialize(options = {})
        requires!(options, :login, :password)
        @options = options
        super
      end

      def authorize(money, creditcard, options = {})
        post = {}
        add_invoice(post, options)
        add_creditcard(post, creditcard)
        add_address(post, creditcard, options)
        add_customer_data(post, options)

        commit('authonly', money, post)
      end

      def purchase(money, creditcard, options = {})
        post = {}
        add_invoice(post, options)
        add_creditcard(post, creditcard)
        # add_address(post, creditcard, options)
        add_customer_data(post, options)

        commit('sale', money, post)
      end

      def capture(money, authorization, options = {})
        commit('capture', money, post)
      end

      private

      def add_customer_data(post, options)
        post[:Email]     = options[:email] unless options[:email].blank?
        post[:Name]      = options[:name] unless options[:name].blank?
        post[:IPAddress] = options[:ip] unless options[:ip].blank?
      end

      def add_address(post, creditcard, options)
      end

      def add_invoice(post, options)
        post[:UID] = options[:order_id]
        post[:Category] = options[:category] unless options[:category].blank?
      end

      def add_creditcard(post, creditcard)
        post[:CreditCardNumber] = creditcard.number
        post[:CreditCardExpiryMonth] = sprintf("%.2i", creditcard.month)
        post[:CreditCardExpiryYear] = sprintf("%.4i", creditcard.year)[-2..-1]
        post[:CreditCardHolderName] = creditcard.name
      end

      def commit(action, money, parameters)
        message = build_message( action, money, parameters )
        #raise message
        response = parse(ssl_post(LIVE_URL, message))
        Response.new(successful?(response), message_from(response), response,
          :test           => test?,
          :authorization  => response[:emattersMainID]
        )
      end

      def successful?( response )
        response[:emattersRcode] == '08'
      end

      def message_from(response)
        MESSAGES[response[:emattersRcode]] || response[:emattersRcode]
      end

      def post_data(action, parameters = {})
      end

      def build_message( action, money, parameters )
        xml = Builder::XmlMarkup.new
        xml.instruct!

        xml.tag! 'ematters' do |protocol|
          xml.readers  @options[:login]
          xml.password @options[:password]

          case action
          when 'sale'
            build_payment( xml, money, parameters)
          else
            raise "no action specified for build_request"
          end
        end

        xml.target!
      end

      def build_payment( xml,  money, parameters)
        xml.Name( parameters[:Name] ) unless parameters[:Name].blank?
        xml.Email( parameters[:Email] ) unless parameters[:Email].blank?
        xml.CreditCardHolderName( parameters[:CreditCardHolderName] ) unless parameters[:CreditCardHolderName].blank?
        xml.CreditCardNumber( parameters[:CreditCardNumber] ) unless parameters[:CreditCardNumber].blank?
        xml.CreditCardExpiryMonth( parameters[:CreditCardExpiryMonth] ) unless parameters[:CreditCardExpiryMonth].blank?
        xml.CreditCardExpiryYear( parameters[:CreditCardExpiryYear] ) unless parameters[:CreditCardExpiryYear].blank?
        xml.UID( parameters[:UID] ) unless parameters[:UID].blank?
        xml.Category( parameters[:Category] ) unless parameters[:Category].blank?
        xml.IPAddress( parameters[:IPAddress] ) unless parameters[:IPAddress].blank?
        xml.FinalPrice amount(money)
        xml.Action "Process"
      end


      def parse(body)
        {}.tap do |hash|
          xml   = REXML::Document.new(body)
          root  = REXML::XPath.first(xml.root, '//emattersResponse')
          # we might have gotten an error
          root.to_a.select {|node| node.kind_of? REXML::Element}.each do |element|
            hash[element.name.to_sym] = element.text
          end
        end
      end
    end
  end
end