class LeafNode < ActiveRecord::Base
  belongs_to :tree
  belongs_to :node
  # after_initialize :set_nonce, :if => :new_record?
  
  include ActionView::Helpers::AssetTagHelper
  include ActionView::Helpers::NumberHelper
  include ActionView::Helpers::TextHelper
  include ActionView::Helpers::DateHelper
  
  require 'json'
  
  def leaf_hash
    leaf_hash = OpenSSL::Digest::SHA256.new.digest("#{self.name}|#{self.credit.to_s}|#{self.nonce}").unpack('H*').first # 256-bit hash,
  end
  
  def set_nonce
    self.nonce ||= OpenSSL::Random.random_bytes(16).unpack("H*").first
  end
  
  def as_json(*args)
        @tree = Tree.find_by_id(self.tree_id)
        height = @tree.height
        h = height-1
        # intialize @my_json, a json, serialized form of the tree.
        jvar = {}
        new_jvar = {}

        path = self.leaf_path

        a = path.split(//)  # converts node_path string into an array of characters
        for i in 0..a.count
          a[i] = a[i].to_i # convert a to an array of integers
        end

        nodes = Node.where('height' => 1).all

        if a[0] == 0  # leaf is a left or single child

          selected_nodes = nodes.select { |node| node.tree_id == @tree.id and node.left_id == self.id }
          parent = selected_nodes.first
          if parent.right_id.blank?
            brother = nil
          else
            brother = LeafNode.find(parent.right_id)
          end

          if brother

            new_jvar = {
                :name => "#{parent.truncated_node_hash}", :node_id => "#{parent.id}", :sum => "#{parent.sum}",
                :children => [
                  {:name => "#{self.truncated_leaf_hash}", :node_id => "#{self.id}", :sum => "#{self.credit}", :path => "#{self.leaf_path}"},
                  {:name => "#{brother.truncated_leaf_hash}", :node_id => "#{brother.id}", :sum => "#{brother.credit}", :path => "#{brother.leaf_path}"}
                  ]  
                }
          else
            new_jvar = {
                :name => "#{parent.truncated_node_hash}", :node_id => "#{parent.id}", :sum => "#{parent.sum}",
                :children => [
                    {:name => "#{self.truncated_leaf_hash}", :node_id => "#{self.id}", :sum => "#{self.credit}", :path => "#{self.leaf_path}"}
                    ]  
                  }
          end
      else # leaf is a right child

          selected_nodes = nodes.select { |node| node.tree_id == @tree.id and node.right_id == self.id }
          parent = selected_nodes.first
          brother = LeafNode.find(parent.left_id)
          new_jvar = {
              :name => "#{parent.truncated_node_hash}", :node_id => "#{parent.id}", :sum => "#{parent.sum}",
              :children => [
                {:name => "#{brother.truncated_leaf_hash}", :node_id => "#{brother.id}", :sum => "#{brother.credit}", :path => "#{brother.leaf_path}"},
                {:name => "#{self.truncated_leaf_hash}", :node_id => "#{self.id}", :sum => "#{self.credit}", :path => "#{self.leaf_path}"}
                ]  
              }
        end

        jvar = new_jvar
        node = parent

        while node.height < (@tree.height - 1)  # node is NOT the root

          path = node.node_path

          a = path.split(//)  # converts node_path string into an array of characters
          for i in 0..a.count
            a[i] = a[i].to_i # convert a to an array of integers
          end
          nodes = Node.where('height' => node.height + 1).all

          if a[0] == 0  # node is a left or single child

            selected_nodes = nodes.select { |value| value.tree_id == @tree.id and value.left_id == node.id }
            new_node = selected_nodes.first
            if new_node.right_id.blank?
              brother = nil
            else
              brother = Node.find(new_node.right_id)
            end

            if brother

              new_jvar = {
                      :name => "#{new_node.truncated_node_hash}", :node_id => "#{new_node.id}", :sum => "#{new_node.sum}",
                      :children => [{}, {}]
                    }

              new_jvar[:children][0] = jvar
              new_jvar[:children][1] = {:name => "#{brother.truncated_node_hash}", :node_id => "#{brother.id}", :sum => "#{brother.sum}", :path => "#{brother.node_path}"}

            else
              new_jvar = {
                      :name => "#{new_node.truncated_node_hash}", :node_id => "#{new_node.id}", :sum => "#{new_node.sum}",
                      :children => [{}]  
                        }
              new_jvar[:children][0] = jvar
            end
          else # node is a right child

            selected_nodes = nodes.select { |value| value.tree_id == @tree.id and value.right_id == node.id }
            new_node = selected_nodes.first
            brother = Node.find(new_node.left_id)
              new_jvar = {
                    :name => "#{new_node.truncated_node_hash}", :node_id => "#{new_node.id}", :sum => "#{new_node.sum}",
                    :children => [{}, {}]
                  }

              new_jvar[:children][1] = jvar
              new_jvar[:children][0] = {:name => "#{brother.truncated_node_hash}", :node_id => "#{brother.id}", :sum => "#{brother.sum}", :path => "#{brother.node_path}"}
            end

          jvar = new_jvar
          node = new_node

        end # while

        jvar

      end # of method as_json
    
    
    
    def truncated_leaf_hash
      string = self.leaf_hash
      if string and string.size >25
        end_string = string[-4,4] # keeps only last 4 caracters
        truncated_string = truncate(string, length: 8, omission: '...') + end_string # keeps only first 5 caracters, with 3 dots (total length 8)
      else
        if string 
          truncated_string = string
        else
          truncated_string = ''
        end
      end

    end # of helper method
  
end
