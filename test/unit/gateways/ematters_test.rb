require 'test_helper'

class EmattersTest < Test::Unit::TestCase
  def setup
    @gateway = EmattersGateway.new(
                 :readers => 'login',
                 :password => 'password'
               )

    @credit_card = credit_card
    @amount = 100

    @options = {
      :order_id => '1',
      :description => 'Store Purchase'
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    # assert_instance_of
    assert_success response

    # Replace with authorization number from the successful response
    assert_equal '0099887766554433', response.authorization
    assert response.test?
  end

  def test_unsuccessful_request
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
  end

  def test_amount_style
   assert_equal '10.34', @gateway.send(:amount, 1034)

   assert_raise(ArgumentError) do
     @gateway.send(:amount, '10.34')
   end
  end

  private

  # Place raw successful response from gateway here
  def successful_purchase_response
    <<-XML
      <emattersResponse>
        <emattersRcode>08</emattersRcode>
        <emattersUID>001</emattersUID>
        <emattersAmount>10.99</emattersAmount>
        <emattersAuthCode>4847784</emattersAuthCode>
        <emattersCardType>VISA</emattersCardType>
        <emattersTrxnReference>00000011120</emattersTrxnReference>
        <emattersMainID>0099887766554433</emattersMainID>
      </emattersResponse>
    XML
  end

  # Place raw failed response from gateway here
  def failed_purchase_response
    <<-XML
      <emattersResponse>
        <emattersRcode>902</emattersRcode>
        <emattersUID>001</emattersUID>
        <emattersAmount>10.99</emattersAmount>
        <emattersAuthCode>4847784</emattersAuthCode>
        <emattersCardType>VISA</emattersCardType>
        <emattersTrxnReference>00000011120</emattersTrxnReference>
        <emattersMainID>0099887766554433</emattersMainID>
      </emattersResponse>
    XML
  end
end
