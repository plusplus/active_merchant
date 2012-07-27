require 'test_helper'

class RemoteEmattersBillsmartTest < Test::Unit::TestCase

  def setup

    @gateway = EmattersBillsmartGateway.new(fixtures(:ematters_billsmart))

    @amount = 100
    @credit_card = credit_card('4557 0130 0031 4262',
      :month => 12,
      :year => 2020,
      :name => 'MR J Doe')
    @declined_card = credit_card('4000300011112220')

    @options = {
      :order_id => "#{rand(3400)}",
    }

    @add_options = {
      :email => "john@example.com",
      :name => "John Doe"
    }
  end

  def generate_unique_id
    SecureRandom.urlsafe_base64
  end

  def test_store_and_process_twice
    unique_customer_id = generate_unique_id
    assert add = @gateway.store( @credit_card, @add_options.merge( :billing_id => unique_customer_id ) )    
    assert_success add
    assert_equal 'OK', add.message
    assert purchase = @gateway.purchase( 1000, unique_customer_id, :order_id => generate_unique_id)
    assert_success purchase
    assert_equal 'Transaction approved.', purchase.message
    assert purchase2 = @gateway.purchase( 2000, unique_customer_id, :order_id => generate_unique_id)
    assert_success purchase2
    assert_equal 'Transaction approved.', purchase2.message
  end

  def test_store_and_delete
    unique_customer_id = "617ad93ef#{Time.now}#{rand(3400)}"
    assert add = @gateway.store( @credit_card, @add_options.merge( :billing_id => unique_customer_id ) )    
    assert_success add
    assert_equal 'OK', add.message

    assert delete = @gateway.delete( unique_customer_id )
    assert_success delete
    assert_equal 'TOKEN DELETED', delete.message
  end

end