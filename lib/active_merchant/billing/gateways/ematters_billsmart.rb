module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class EmattersBillsmartGateway < Gateway
      TEST_URL = 'https://merchant.ematters.com.au/cmaonline.nsf/XML'
      LIVE_URL = 'https://merchant.ematters.com.au/cmaonline.nsf/XML'
      COMPLETE_URL = "https://merchant.ematters.com.au/cmaonline.nsf/CompleteTransaction?OpenAgent"
      ADD_URL = 'https://merchant.ematters.com.au/billsmart.nsf/Add?OpenAgent'
      PROCESS_URL = 'https://merchant.ematters.com.au/cmaonline.nsf/BillSmart'
      DELETE_URL = 'https://merchant.ematters.com.au/billsmart.nsf/Delete?OpenAgent'
      # The countries the gateway supports merchants from as 2 digit ISO country codes
      self.supported_countries = ['AU']

      # The card types supported by the payment gateway
      self.supported_cardtypes = [:visa, :master] #, :american_express, :discover]

      # The homepage URL of the gateway
      self.homepage_url = 'http://ematters.com.au'

      # The name of the gateway
      self.display_name = 'eMatters BillSmart'

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
        requires!(options, :login, :pin)
        @options = options
        super
      end

      def store(creditcard, options = {})
        post = {}
        
        # Handle eWay specific required fields.
        add_creditcard(post, creditcard)
        add_customer_data(post, options)
             
        commit('add', nil, post)
      end

      def purchase(money, billing_id, options = {})
        post = {}

        add_invoice(post, options)
        add_customer_data(post, options.merge( billing_id: billing_id ))

        commit('process', money, post)
      end

      def delete( billing_id )
        post = {:CustomerUID => billing_id}
        commit('delete', nil, post)
      end

      private

      def add_customer_data(post, options)
        post[:Email]     = options[:email] unless options[:email].blank?
        post[:Name]      = options[:name] unless options[:name].blank?
        post[:IPAddress] = options[:ip] unless options[:ip].blank?
        post[:CustomerUID] = options[:billing_id] unless options[:billing_id].blank?
      end

      def add_address(post, creditcard, options)
      end

      def add_invoice(post, options)
        post[:InvoiceNumber] = options[:order_id]
      end

      def add_creditcard(post, creditcard)
        post[:CreditCardNumber] = creditcard.number
        post[:CreditCardExpiryMonth] = sprintf("%.2i", creditcard.month)
        post[:CreditCardExpiryYear] = sprintf("%.4i", creditcard.year)[-2..-1]
        post[:CreditCardHolderName] = creditcard.name
        post[:CVV] = creditcard.verification_value
      end

      def commit(action, money, parameters)
        message = build_message( action, money, parameters )
        #puts "REQUEST: #{message}\n\n"
        response = parse(action, ssl_post(url_for( action ), message))
        Response.new(successful?(response), message_from(response), response,
          :test           => test?,
          :authorization  => response[:emattersMainID]
        )
      end

      def url_for(action)
        case action
        when 'add'
          ADD_URL          
        when 'process'
          PROCESS_URL
        when 'delete'
          DELETE_URL
        else
          raise "Don\'t know URL for #{action}"
        end
      end

      def successful?( response )
        response[:result] == '01' ||
        response[:response] == '01' ||
        response[:emattersrcode] == '08'
      end

      def message_from(response)
        if response[:emattersrcode]
          MESSAGES[response[:emattersrcode]] || response[:emattersrcode]
        else
          response[:text]
        end
      end

      def build_message( action, money, parameters )
        xml = Builder::XmlMarkup.new
        xml.instruct!

        xml.tag! 'ematters' do |protocol|
          case action
          when 'add'
            build_add( xml, parameters)
          when 'process'
            build_process( xml, money, parameters)
          when 'delete'
            build_delete( xml, parameters )
          else
            raise "no action specified for build_request"
          end
        end

        xml.target!
      end

      def build_add( xml, parameters )
        xml.Readers @options[:login]
        xml.CustomerName( parameters[:Name] ) unless parameters[:Name].blank?
        xml.CustomerEmail( parameters[:Email] ) unless parameters[:Email].blank?
        build_credit_card( xml, parameters )
        xml.UID( parameters[:CustomerUID] ) unless parameters[:CustomerUID].blank?
        xml.Action "Add"        
      end

      def build_process( xml, money, parameters )
        xml.MerchantCode @options[:login]
        xml.CustomerNumber parameters[:CustomerUID]
        xml.InvoiceNumber parameters[:InvoiceNumber]
        xml.Amount amount(money)
        xml.Action "Process"
      end

      def build_delete( xml, parameters )
        xml.Readers @options[:login]
        xml.UID( parameters[:CustomerUID] ) unless parameters[:CustomerUID].blank?
        xml.PIN @options[:pin]
        xml.Action "Delete"
      end

      def build_credit_card( xml, parameters )
        xml.CreditCardNumber( parameters[:CreditCardNumber] ) unless parameters[:CreditCardNumber].blank?
        xml.CreditCardExpiryMonth( parameters[:CreditCardExpiryMonth] ) unless parameters[:CreditCardExpiryMonth].blank?
        xml.CreditCardExpiryYear( parameters[:CreditCardExpiryYear] ) unless parameters[:CreditCardExpiryYear].blank?
        xml.CVV( parameters[:CVV] ) unless parameters[:CVV].blank?
        xml.CreditCardHolderName( parameters[:CreditCardHolderName] ) unless parameters[:CreditCardHolderName].blank?
      end

      def parse(action, body)

        root_node = case action
        when 'process'
          'emattersResponse'
        else
          'ematters'
        end
        {}.tap do |hash|
          #puts "RESPONSE: #{body}\n\n\n\n"
          xml   = REXML::Document.new(body)
          root  = REXML::XPath.first(xml.root, "//#{root_node}")
          # we might have gotten an error
          root.to_a.select {|node| node.kind_of? REXML::Element}.each do |element|
            hash[element.name.downcase.to_sym] = element.text
          end

          #puts "REsponse HASH = #{hash}"
        end
      end
    end
  end
end