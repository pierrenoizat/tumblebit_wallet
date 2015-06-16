class Tree < ActiveRecord::Base
  has_many :nodes
  has_many :leaf_nodes
  
  # include TreeWorker
  
  has_attached_file :avatar, styles: {
    thumb: '100x100>',
    square: '200x200#',
    medium: '300x300>'
  },:storage => :s3,
  :s3_permissions => :public_read,
  :s3_credentials => "#{Rails.root}/config/aws.yml",
  :bucket => 'hashtree-assets',
  :s3_options => { :server => "s3-eu-west-1.amazonaws.com" }
  
  validates_attachment :avatar,
    :size => { :in => 0..499.kilobytes }
    
  validates_attachment_content_type :avatar, :content_type => /\Aimage\/.*\Z/
  
  has_attached_file :roll,
  :storage => :s3,
  :s3_permissions => :public_read,
  :s3_credentials => "#{Rails.root}/config/aws.yml",
  :bucket => 'hashtree-assets',
  :s3_options => { :server => "s3-eu-west-1.amazonaws.com" }
  
  validates_attachment :roll, # :presence => true,
    :content_type => { :content_type => "text/csv" },
    :size => { :in => 0..1499.kilobytes }
    
  has_attached_file :json_file,
    :storage => :s3,
    :s3_permissions => :public_read,
    :s3_credentials => "#{Rails.root}/config/aws.yml",
    :bucket => 'hashtree-assets',
#    :bucket => 'hashtree-test',
#    :bucket => Figaro.env.s3_bucket,
    :s3_options => { :server => "s3-eu-west-1.amazonaws.com" }

    validates_attachment :json_file, # :presence => true,
      :content_type => { :content_type => "application/json" },
      :size => { :in => 0..1499.kilobytes }
    
    def total
      Node.where('height' => self.height-1).find_by_tree_id(self.id).sum 
    end
    
    def root_hash
      Node.where('height' => self.height-1).find_by_tree_id(self.id).node_hash 
    end
    
    
  
end
