class Node < ActiveRecord::Base
  belongs_to :tree
  has_many :leaf_nodes
  
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
      :name => "#{truncate_node_hash(self.node_hash)}", :node_id => "#{self.id}", :sum => "#{self.sum}",
      :children => [
          {:name => "#{truncate_node_hash(self.left)}", :node_id => "#{self.left_id}"},
          {:name => "#{truncate_node_hash(self.right)}", :node_id => "#{self.right_id}"}
          ]  
      }
      
      h -= 2

      a = Array[ self.left_child.single_child?, self.right_child.single_child? ]
      case a
        
      when [ true, false ] # left node is connected to a single, replicate node and right node must have 2 children nodes
        @my_json = {
          :name => "#{truncate_node_hash(self.node_hash)}", :node_id => "#{self.id}", :sum => "#{self.sum}",
          :children => [
              {:name => "#{truncate_node_hash(self.left)}", :children => [{:name => "#{truncate_node_hash(self.left_child.left)}", :sum => "#{self.left_child.sum}", :node_id => "#{self.left_child.left_id}"}]},
              {:name => "#{truncate_node_hash(self.right)}", 
               :children => [
                 {:name => "#{truncate_node_hash(self.right_child.left)}", :sum => "#{self.right_child.left_child.sum}",:node_id => "#{self.right_child.left_id}",:left_id => "#{self.right_child.left_child.left_id}",:right_id => "#{self.right_child.left_child.right_id}"},
                 {:name => "#{truncate_node_hash(self.right_child.right)}", :sum => "#{self.right_child.right_child.sum}",:node_id => "#{self.right_child.right_id}",:left_id => "#{self.right_child.right_child.left_id}",:right_id => "#{self.right_child.right_child.right_id}"}
                ]
                }
              ]  
          }
          
      when [ false, true ] # right node is connected to a single, replicate node and left node must have 2 children nodes
        @my_json = {
          :name => "#{truncate_node_hash(self.node_hash)}", :node_id => "#{self.id}", :sum => "#{self.sum}",
          :children => [
              {:name => "#{truncate_node_hash(self.left)}", 
               :children => [
                 {:name => "#{truncate_node_hash(self.left_child.left)}", :sum => "#{self.left_child.left_child.sum}",:node_id => "#{self.left_child.left_id}",:left_id => "#{self.left_child.left_child.left_id}",:right_id => "#{self.left_child.left_child.right_id}"},
                 {:name => "#{truncate_node_hash(self.left_child.right)}", :sum => "#{self.left_child.right_child.sum}",:node_id => "#{self.left_child.right_id}",:left_id => "#{self.left_child.right_child.left_id}",:right_id => "#{self.left_child.right_child.right_id}"}
                ]
                },
              {:name => "#{truncate_node_hash(self.right)}", :children => [{:name => "#{truncate_node_hash(self.right_child.left)}", :sum => "#{self.right_child.sum}",:node_id => "#{self.right_child.left_id}"}]}
              ]  
            }
            
      when [ false, false ] # both nodes connected each to 2 children
        @my_json = {
          :name => "#{truncate_node_hash(self.node_hash)}",
          :children => [
            {:name => "#{truncate_node_hash(self.left)}", 
             :children => [
               {:name => "#{truncate_node_hash(self.left_child.left)}", :sum => "#{self.left_child.left_child.sum}",:node_id => "#{self.left_child.left_id}",:left_id => "#{self.left_child.left_child.left_id}",:right_id => "#{self.left_child.left_child.right_id}"},
               {:name => "#{truncate_node_hash(self.left_child.right)}", :sum => "#{self.left_child.right_child.sum}",:node_id => "#{self.left_child.right_id}",:left_id => "#{self.left_child.right_child.left_id}",:right_id => "#{self.left_child.right_child.right_id}"}
                ]
            },
            {:name => "#{truncate_node_hash(self.right)}", 
             :children => [
               {:name => "#{truncate_node_hash(self.right_child.left)}", :sum => "#{self.right_child.left_child.sum}",:node_id => "#{self.right_child.left_id}",:left_id => "#{self.right_child.left_child.left_id}",:right_id => "#{self.right_child.left_child.right_id}"},
               {:name => "#{truncate_node_hash(self.right_child.right)}", :sum => "#{self.right_child.right_child.sum}",:node_id => "#{self.right_child.right_id}",:left_id => "#{self.right_child.right_child.left_id}",:right_id => "#{self.right_child.right_child.right_id}"}
              ]
              }
            ]  
          }
      else
        puts "I have no idea what to do with that."
      end
      
      
      # json_height(@my_json)
      append_nodes(@my_json, self.tree_id)
      # @my_json
      
    end
    
    
    
    def json_height(var) # computes the min height of nodes from root per the json representation argument
      hi = 0
      jsonvar = var
      array_var = []
      
      while jsonvar
          array_var = jsonvar[:children]

          if array_var
            jsonvar=array_var[0]
            hi +=1
          else
            jsonvar=nil
          end
      
      end
      hi
      
    end
    
    
    def append_nodes(jvar, id) # var = current json representation of the tree with tree.id = id
      
      h = json_height(jvar)
      @tree = Tree.find_by_id(id)

      # get nodes where node.height = tree.height-h-2
      @nodes = Node.where('height' => @tree.height - h - 2).all
      unless @nodes.blank?
      @nodes = @nodes.select { |node| node.tree_id == id }
      end

      
      if @nodes.count > 0
        # append nodes
        
        @nodes.each do |node|  ########################################
          m = h
          
          @selection = @nodes.select { |node| node.left_id == node.id }
          @node = @selection.first
          if @node
            node_path = "0"
          else
            @selection = @nodes.select { |node| node.right_id == node.id }
            @node = @selection.first
            node_path = "1"
          end
          
          while @node
            m -= 1 # get nodes just above current node
            @selected_nodes = Node.select { |node| ((node.tree_id == id) and (node.height == @tree.height - m - 1)) }
            i = @node.id
          
            @selection = @selected_nodes.select { |node| node.left_id == i }
            @node = @selection.first
            
            if @node
              node_path += "0" # rightmost digit of leaf_path points to highest node
            else
              @selection = @selected_nodes.select { |node| node.right_id == i }
              @node = @selection.first
              
              if @node
                node_path += "1"
              end
            end
          end # while @node
          
          jsonvar = jvar
          node.node_path = node_path
          node.save
          puts h
          puts node.id
          puts node_path
          puts jsonvar
          @new_jsonvar = {}
          @node_json = {}
          @new_jsonvar = jvar
          @node_json = {:name => "#{truncate_node_hash(node.node_hash)}", :sum => "#{node.sum}",:node_id => "#{node.id}"}
          
          case node_path

          when "000" # good only for tree height = 4, 2**3 = 8 lines !
            @new_jsonvar[:children][0][:children][0][:children] = [@node_json]
            
          when "001"
            @new_jsonvar[:children][1][:children][0][:children] = [@node_json]
            
          when "010"
            @new_jsonvar[:children][0][:children][1][:children] = [@node_json]
            
          when "100"
              if @new_jsonvar[:children][0][:children][0][:children].blank?
                @new_jsonvar[:children][0][:children][0][:children] = [ {}, @node_json ]
              else
                @new_jsonvar[:children][0][:children][0][:children] << @node_json
              end
            
          when "110"
              if @new_jsonvar[:children][0][:children][1][:children].blank?
                @new_jsonvar[:children][0][:children][1][:children] = [ {}, @node_json ]
              else
                @new_jsonvar[:children][0][:children][1][:children] << @node_json
              end
            
          when "101"
              if @new_jsonvar[:children][1][:children][0][:children].blank?
                @new_jsonvar[:children][1][:children][0][:children] = [ {}, @node_json ]
              else
                @new_jsonvar[:children][1][:children][0][:children] << @node_json
              end
            
          when "011"
            @new_jsonvar[:children][1][:children][1][:children] = [@node_json]
            
          when "111"
            if @new_jsonvar[:children][1][:children][1][:children].blank?
              @new_jsonvar[:children][1][:children][1][:children] = [ {}, @node_json ]
            else
              @new_jsonvar[:children][1][:children][1][:children] << @node_json
            end
     
          end
          
          
        end ###########################################################
        
      else
        # append leaf nodes
        @nodes = Node.select { |node| ((node.tree_id == id) and (node.height == @tree.height - h - 1)) } # get nodes just above leaves
        
        @leaf_nodes = LeafNode.where('tree_id' => id).all
        
        @leaf_nodes.each do |leaf| ######################################
          n = h
          
          @selection = @nodes.select { |node| node.left_id == leaf.id }
          @node = @selection.first
          if @node
            leaf_path = "0"
          else
            @selection = @nodes.select { |node| node.right_id == leaf.id }
            @node = @selection.first
            leaf_path = "1"
          end
          
          while @node
            n -= 1 # get nodes just above current node
            @selected_nodes = Node.select { |node| ((node.tree_id == id) and (node.height == @tree.height - n - 1)) }
            i = @node.id
          
            @selection = @selected_nodes.select { |node| node.left_id == i }
            @node = @selection.first
            
            if @node
              leaf_path += "0" # rightmost digit of leaf_path points to highest node
            else
              @selection = @selected_nodes.select { |node| node.right_id == i }
              @node = @selection.first
              
              if @node
                leaf_path += "1"
              end
            end
          end # while @node
          
          jsonvar = jvar

          
          leaf.leaf_path = leaf_path
          leaf.save
          puts h
          puts leaf.id
          puts leaf_path
          puts jsonvar
          @new_jsonvar = {}
          @leaf_json = {}
          @new_jsonvar = jvar
          @leaf_json = {:name => "#{truncate_node_hash(leaf.leaf_hash)}", :sum => "#{leaf.credit}",:node_id => "#{leaf.id}"}
          
          case leaf_path

          when "000" # good only for tree height = 4, 2**3 = 8 lines !
            if @new_jsonvar[:children][0][:children][0][:children].blank?
              @new_jsonvar[:children][0][:children][0][:children] = [@leaf_json]
            else
              @new_jsonvar[:children][0][:children][0][:children][0] = @leaf_json
            end
            
          when "001"
            if @new_jsonvar[:children][1][:children][0][:children].blank?
              @new_jsonvar[:children][1][:children][0][:children] = [@leaf_json]
            else
              @new_jsonvar[:children][1][:children][0][:children][0] = @leaf_json
            end
            
          when "010"
            if @new_jsonvar[:children][0][:children][1][:children].blank?
              @new_jsonvar[:children][0][:children][1][:children] = [@leaf_json]
            else
              @new_jsonvar[:children][0][:children][1][:children][0] = @leaf_json
            end
            
          when "100"
              if @new_jsonvar[:children][0][:children][0][:children].blank?
                @new_jsonvar[:children][0][:children][0][:children] = [ {}, @leaf_json ]
              else
                @new_jsonvar[:children][0][:children][0][:children] << @leaf_json
              end
            
          when "110"
              if @new_jsonvar[:children][0][:children][1][:children].blank?
                @new_jsonvar[:children][0][:children][1][:children] = [ {}, @leaf_json ]
              else
                @new_jsonvar[:children][0][:children][1][:children] << @leaf_json
              end
            
          when "101"
              if @new_jsonvar[:children][1][:children][0][:children].blank?
                @new_jsonvar[:children][1][:children][0][:children] = [ {}, @leaf_json ]
              else
                @new_jsonvar[:children][1][:children][0][:children] << @leaf_json
              end
            
          when "011"
            if @new_jsonvar[:children][1][:children][1][:children].blank?
              @new_jsonvar[:children][1][:children][1][:children] = [@leaf_json]
            else
              @new_jsonvar[:children][1][:children][1][:children][0] = @leaf_json
            end
            
          when "111"
              if @new_jsonvar[:children][1][:children][1][:children].blank?
                @new_jsonvar[:children][1][:children][1][:children] = [ {}, @leaf_json ]
              else
                @new_jsonvar[:children][1][:children][1][:children] << @leaf_json
              end
     
          end
          
        end # of do |leaf|  ########################################################
        @new_jsonvar
      end
      
      
      
    end  # of method append_nodes
    
    
    def down_left(jsonvar) # append nodes of height = h-1 to nodes of height = h and up
      @var = jsonvar[:children]
      if @var
        jsonvar[:children][0]
      end
    end
    
    def down_right(jsonvar)
      @var = jsonvar[:children]
      if @var
        jsonvar[:children][1]
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
