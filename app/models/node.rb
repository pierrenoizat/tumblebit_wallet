class Node < ActiveRecord::Base
  belongs_to :tree
  has_many :leaf_nodes
  
  include ActionView::Helpers::NumberHelper
  include ActionView::Helpers::TextHelper
    
    def left_child
      # @tree = Tree.find_by_id(self.tree_id)
      # @nodes = @tree.nodes
      @nodes = Node.select { |node| ((node.id == self.left_id) and (node.tree_id == self.tree_id) )}
      if @nodes
        @node = @nodes.first
      else
        @node = nil
      end
    end
    
    def right_child
      @tree = Tree.find_by_id(self.tree_id)
      @nodes = @tree.nodes
      # @nodes = @nodes.select { |node| (node.node_hash == self.right) && (node.height == self.height-1) }
      @nodes = @nodes.select { |node| (node.id == self.right_id) }
      if @nodes
        @node = @nodes.first
      else
        @node = nil
      end
    end
    
    
    def single_child?
      @tree = Tree.find_by_id(self.tree_id)
      @nodes = @tree.nodes
      @nodes = @nodes.select { |node| ((node.height == (self.height - 1)) and (node.node_hash == self.node_hash)) }
      boole = !@nodes.blank?
    end
    
    
    def truncated_node_hash
      
      string = self.node_hash
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

    end
    
    
end
