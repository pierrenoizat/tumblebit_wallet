class PublicKey < ActiveRecord::Base
  
  validates_presence_of :name, :compressed
  belongs_to :script
  
end
