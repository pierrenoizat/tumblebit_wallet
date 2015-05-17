class Node < ActiveRecord::Base
  belongs_to :tree
  
  include ActionView::Helpers::AssetTagHelper
  include ActionView::Helpers::NumberHelper
  include ActionView::Helpers::TextHelper
  include ActionView::Helpers::DateHelper
  
  require 'json'
  
  def as_json(*args)  # call this method on root node to build the json representation of the tree for d3
    @tree = Tree.find_by_id(self.tree_id)
    height = @tree.height
    h = height-1

     @my_json = {
      :name => "#{truncate_node_hash(self.node_hash)}",
      :children => [
          {:name => "#{truncate_node_hash(self.left)}", :sum => "#{self.sum}"},
          {:name => "#{truncate_node_hash(self.right)}", :sum => "#{self.sum}"}
          ]  
      }
      
      h -= 2

      a = Array[ self.left_child.single_child?, self.right_child.single_child? ]
      case a
        
      when [ true, false ] # left node is connected to a single, replicate node and right node must have 2 children nodes
        @my_json = {
          :name => "#{truncate_node_hash(self.node_hash)}",
          :children => [
              {:name => "#{truncate_node_hash(self.left)}", :children => [{:name => "#{truncate_node_hash(self.left_child.node_hash)}", :sum => "#{self.left_child.sum}"}]},
              {:name => "#{truncate_node_hash(self.right)}", 
               :children => [
                 {:name => "#{truncate_node_hash(self.right_child.left)}", :sum => "#{self.right_child.sum}"},
                 {:name => "#{truncate_node_hash(self.right_child.right)}", :sum => "#{self.right_child.sum}"}
                ]
                }
              ]  
          }
          
      when [ false, true ] # right node is connected to a single, replicate node and left node must have 2 children nodes
        @my_json = {
          :name => "#{truncate_node_hash(self.node_hash)}",
          :children => [
              {:name => "#{truncate_node_hash(self.left)}", 
               :children => [
                 {:name => "#{truncate_node_hash(self.left_child.left)}", :sum => "#{self.left_child.sum}"},
                 {:name => "#{truncate_node_hash(self.left_child.right)}", :sum => "#{self.left_child.sum}"}
                ]
                },
              {:name => "#{truncate_node_hash(self.right)}", :children => [{:name => "#{truncate_node_hash(self.right_child.node_hash)}", :sum => "#{self.left_child.sum}"}]}
              ]  
            }
            
      when [ false, false ] # both nodes connected each to 2 children
        @my_json = {
          :name => "#{truncate_node_hash(self.node_hash)}",
          :children => [
            {:name => "#{truncate_node_hash(self.left)}", 
             :children => [
               {:name => "#{truncate_node_hash(self.left_child.left)}", :sum => "#{self.left_child.sum}"},
               {:name => "#{truncate_node_hash(self.left_child.right)}", :sum => "#{self.left_child.sum}"}
                ]
            },
            {:name => "#{truncate_node_hash(self.right)}", 
             :children => [
               {:name => "#{truncate_node_hash(self.right_child.left)}", :sum => "#{self.right_child.sum}"},
               {:name => "#{truncate_node_hash(self.right_child.right)}", :sum => "#{self.right_child.sum}"}
              ]
              }
            ]  
          }
      else
        puts "I have no idea what to do with that."
      end

      
      
    end
    
    
    def left_child
      @tree = Tree.find_by_id(self.tree_id)
      @nodes = @tree.nodes
      @nodes = @nodes.select { |node| (node.node_hash == self.left) && (node.height == self.height-1) }
      if @nodes
        @node = @nodes.first
      else
        @node = nil
      end
    end
    
    def right_child
      @tree = Tree.find_by_id(self.tree_id)
      @nodes = @tree.nodes
      @nodes = @nodes.select { |node| (node.node_hash == self.right) && (node.height == self.height-1) }
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
    
    
    def truncate_node_hash(string)

      if string and string.size >25
        end_string = string[-4,4]
        truncated_string = truncate(string, length: 8, omission: '...') + end_string
      else
        if string 
          truncated_string = string
        else
          truncated_string = ''
        end
      end

    end # of helper method
    
    
  
end
