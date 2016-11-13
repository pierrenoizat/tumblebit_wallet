class PublicKeyValidator < ActiveModel::Validator
  def validate(record)
    require 'btcruby/extensions'
    @alert = ""
    begin  
      @key = BTC::Key.new(public_key:BTC.from_hex(record.compressed))
      @compressed_public_key = @key.compressed_public_key
    rescue Exception => e  
      @alert = "Invalid compressed public key"
    end
    unless @alert.blank?
      record.errors[:compressed] << @alert
    end
  end
end


class PublicKey < ActiveRecord::Base
  include ActiveModel::Validations
  validates_with PublicKeyValidator
  
  validates_presence_of :name, :compressed
  validates :compressed, length: { is: 66 }

  belongs_to :script
  
end
