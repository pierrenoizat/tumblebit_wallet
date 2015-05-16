class LeafNode < ActiveRecord::Base
  belongs_to :tree
  # after_initialize :set_nonce, :if => :new_record?
  
  def leaf_hash
    leaf_hash = OpenSSL::Digest::SHA256.new.digest("#{self.name}|#{self.credit.to_s}|#{self.nonce}").unpack('H*').first # 256-bit hash,
  end
  
  def set_nonce
    self.nonce ||= OpenSSL::Random.random_bytes(16).unpack("H*").first
  end
  
  def as_json(*args)
      {
        :hash => "#{self.leaf_hash}",
        :credit => "#{self.credit}"
      }
    end
  
end
