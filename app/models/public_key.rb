class PublicKey < ActiveRecord::Base
  
  validates_presence_of :name, :compressed
  validates :compressed, length: { is: 66 }
  
  belongs_to :script
  
end
