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
    # intialize @my_json, a json, serialized form of the tree with the first two levels of nodes from the root down.
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
              {:name => "#{truncate_node_hash(self.left)}", :children => [{:name => "#{truncate_node_hash(self.left)}", :sum => "#{self.left_child.sum}", :node_id => "#{self.left_child.left_id}"}]},
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
              {:name => "#{truncate_node_hash(self.right)}", :children => [{:name => "#{truncate_node_hash(self.right)}", :sum => "#{self.right_child.sum}",:node_id => "#{self.right_child.left_id}"}]}
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
      
      @my_json =  append_nodes(@my_json, self.tree_id) # returns @my_json completed with internal nodes through the leaves
      h = json_height(@my_json)
      puts "hauteur ", h
      k = @tree.height - 4
      while k > 0
        @my_json = append_nodes(@my_json, self.tree_id)
        k -= 1
      end
      @my_json
      #while h < @tree.height
      #  @my_json = append_nodes(@my_json, self.tree_id)
      #  h += 1
      #end
      # @my_json = append_nodes(@my_json, self.tree_id)  # add another row when tree height = 6
      #@my_json = append_nodes(@my_json, self.tree_id)  # add leaf nodes when tree height = 6
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

      # get nodes where node.height = tree.height-h-2, first nodes to be appended
      @nodes = Node.where('height' => @tree.height - h - 2).all
      unless @nodes.blank?
      @nodes = @nodes.select { |node| node.tree_id == id }
      end

      
      if @nodes.count > 0
        # append nodes, if tree height > 4, i.e if there are nodes with height > 3
        
        @nodes.each do |node|  ########################################
          
          jsonvar = jvar
          puts h
          puts "node " + node.id.to_s
          puts node_path
          puts jsonvar
          @new_jsonvar = {}
          @node_json = {}
          @new_jsonvar = jvar
          @node_json = {:name => "#{truncate_node_hash(node.node_hash)}", :sum => "#{node.sum}",:node_id => "#{node.id}"}
          
          #######################
          
          case node.node_path.length

          when 3
            
            if node.node_path[0] == "0"
            
              if @new_jsonvar[:children][node.node_path[2].to_i][:children][node.node_path[1].to_i][:children].blank?
                @new_jsonvar[:children][node.node_path[2].to_i][:children][node.node_path[1].to_i][:children] = [@node_json]
              else
                @new_jsonvar[:children][node.node_path[2].to_i][:children][node.node_path[1].to_i][:children][0] = @node_json
              end
            else
              
              if @new_jsonvar[:children][node.node_path[2].to_i][:children][node.node_path[1].to_i][:children].blank?
                @new_jsonvar[:children][node.node_path[2].to_i][:children][node.node_path[1].to_i][:children] = [ {}, @node_json ]
              else
                @new_jsonvar[:children][node.node_path[2].to_i][:children][node.node_path[1].to_i][:children] << @node_json
              end
              
            end
            
          when 4

            if node.node_path[0] == "0"

              if @new_jsonvar[:children][node.node_path[3].to_i][:children][node.node_path[2].to_i][:children][node.node_path[1].to_i][:children].blank?
                @new_jsonvar[:children][node.node_path[3].to_i][:children][node.node_path[2].to_i][:children][node.node_path[1].to_i][:children] = [@node_json]
              else
                @new_jsonvar[:children][node.node_path[3].to_i][:children][node.node_path[2].to_i][:children][node.node_path[1].to_i][:children][0] = @node_json
              end
            else

              if @new_jsonvar[:children][node.node_path[3].to_i][:children][node.node_path[2].to_i][:children][node.node_path[1].to_i][:children].blank?
                @new_jsonvar[:children][node.node_path[3].to_i][:children][node.node_path[2].to_i][:children][node.node_path[1].to_i][:children] = [ {}, @node_json ]
              else
                @new_jsonvar[:children][node.node_path[3].to_i][:children][node.node_path[2].to_i][:children][node.node_path[1].to_i][:children] << @node_json
              end

            end
            
          when 5

            if node.node_path[0] == "0"

              if @new_jsonvar[:children][node.node_path[4].to_i][:children][node.node_path[3].to_i][:children][node.node_path[2].to_i][:children][node.node_path[1].to_i][:children].blank?
                @new_jsonvar[:children][node.node_path[4].to_i][:children][node.node_path[3].to_i][:children][node.node_path[2].to_i][:children][node.node_path[1].to_i][:children] = [@node_json]
              else
                @new_jsonvar[:children][node.node_path[4].to_i][:children][node.node_path[3].to_i][:children][node.node_path[2].to_i][:children][node.node_path[1].to_i][:children][0] = @node_json
              end
            else

              if @new_jsonvar[:children][node.node_path[4].to_i][:children][node.node_path[3].to_i][:children][node.node_path[2].to_i][:children][node.node_path[1].to_i][:children].blank?
                @new_jsonvar[:children][node.node_path[4].to_i][:children][node.node_path[3].to_i][:children][node.node_path[2].to_i][:children][node.node_path[1].to_i][:children] = [ {}, @node_json ]
              else
                @new_jsonvar[:children][node.node_path[4].to_i][:children][node.node_path[3].to_i][:children][node.node_path[2].to_i][:children][node.node_path[1].to_i][:children] << @node_json
              end

            end
            
          when 6

            if node.node_path[0] == "0"

              if @new_jsonvar[:children][node.node_path[5].to_i][:children][node.node_path[4].to_i][:children][node.node_path[3].to_i][:children][node.node_path[2].to_i][:children][node.node_path[1].to_i][:children].blank?
                @new_jsonvar[:children][node.node_path[5].to_i][:children][node.node_path[4].to_i][:children][node.node_path[3].to_i][:children][node.node_path[2].to_i][:children][node.node_path[1].to_i][:children] = [@node_json]
              else
                @new_jsonvar[:children][node.node_path[5].to_i][:children][node.node_path[4].to_i][:children][node.node_path[3].to_i][:children][node.node_path[2].to_i][:children][node.node_path[1].to_i][:children][0] = @node_json
              end
            else

              if @new_jsonvar[:children][node.node_path[5].to_i][:children][node.node_path[4].to_i][:children][node.node_path[3].to_i][:children][node.node_path[2].to_i][:children][node.node_path[1].to_i][:children].blank?
                @new_jsonvar[:children][node.node_path[5].to_i][:children][node.node_path[4].to_i][:children][node.node_path[3].to_i][:children][node.node_path[2].to_i][:children][node.node_path[1].to_i][:children] = [ {}, @node_json ]
              else
                @new_jsonvar[:children][node.node_path[5].to_i][:children][node.node_path[4].to_i][:children][node.node_path[3].to_i][:children][node.node_path[2].to_i][:children][node.node_path[1].to_i][:children] << @node_json
              end

            end
            
          else
            puts "I will deal with this node later."
          end
          
        end # of do |node| #########################################################
        
      else
        # append leaf nodes
        
        @leaf_nodes = LeafNode.where('tree_id' => id).all
        
        @leaf_nodes.each do |leaf| ######################################

          @new_jsonvar = {}
          @leaf_json = {}
          @new_jsonvar = jvar
          @leaf_json = {:name => "#{truncate_node_hash(leaf.leaf_hash)}", :sum => "#{leaf.credit}",:node_id => "#{leaf.id}"}
          
          #########################################################
          
          case leaf.leaf_path.length

          when 3
            
            if leaf.leaf_path[0] == "0"
            
              if @new_jsonvar[:children][leaf.leaf_path[2].to_i][:children][leaf.leaf_path[1].to_i][:children].blank?
                @new_jsonvar[:children][leaf.leaf_path[2].to_i][:children][leaf.leaf_path[1].to_i][:children] = [@leaf_json]
              else
                @new_jsonvar[:children][leaf.leaf_path[2].to_i][:children][leaf.leaf_path[1].to_i][:children][0] = @leaf_json
              end
            else
              
              if @new_jsonvar[:children][leaf.leaf_path[2].to_i][:children][leaf.leaf_path[1].to_i][:children].blank?
                @new_jsonvar[:children][leaf.leaf_path[2].to_i][:children][leaf.leaf_path[1].to_i][:children] = [ {}, @leaf_json ]
              else
                @new_jsonvar[:children][leaf.leaf_path[2].to_i][:children][leaf.leaf_path[1].to_i][:children] << @leaf_json
              end
              
            end
            
          when 4

            if leaf.leaf_path[0] == "0"

              if @new_jsonvar[:children][leaf.leaf_path[3].to_i][:children][leaf.leaf_path[2].to_i][:children][leaf.leaf_path[1].to_i][:children].blank?
                @new_jsonvar[:children][leaf.leaf_path[3].to_i][:children][leaf.leaf_path[2].to_i][:children][leaf.leaf_path[1].to_i][:children] = [@leaf_json]
              else
                @new_jsonvar[:children][leaf.leaf_path[3].to_i][:children][leaf.leaf_path[2].to_i][:children][leaf.leaf_path[1].to_i][:children][0] = @leaf_json
              end
            else

              if @new_jsonvar[:children][leaf.leaf_path[3].to_i][:children][leaf.leaf_path[2].to_i][:children][leaf.leaf_path[1].to_i][:children].blank?
                @new_jsonvar[:children][leaf.leaf_path[3].to_i][:children][leaf.leaf_path[2].to_i][:children][leaf.leaf_path[1].to_i][:children] = [ {}, @leaf_json ]
              else
                @new_jsonvar[:children][leaf.leaf_path[3].to_i][:children][leaf.leaf_path[2].to_i][:children][leaf.leaf_path[1].to_i][:children] << @leaf_json
              end

            end
            
          when 5

            if leaf.leaf_path[0] == "0"

              if @new_jsonvar[:children][leaf.leaf_path[4].to_i][:children][leaf.leaf_path[3].to_i][:children][leaf.leaf_path[2].to_i][:children][leaf.leaf_path[1].to_i][:children].blank?
                @new_jsonvar[:children][leaf.leaf_path[4].to_i][:children][leaf.leaf_path[3].to_i][:children][leaf.leaf_path[2].to_i][:children][leaf.leaf_path[1].to_i][:children] = [@leaf_json]
              else
                @new_jsonvar[:children][leaf.leaf_path[4].to_i][:children][leaf.leaf_path[3].to_i][:children][leaf.leaf_path[2].to_i][:children][leaf.leaf_path[1].to_i][:children][0] = @leaf_json
              end
            else

              if @new_jsonvar[:children][leaf.leaf_path[4].to_i][:children][leaf.leaf_path[3].to_i][:children][leaf.leaf_path[2].to_i][:children][leaf.leaf_path[1].to_i][:children].blank?
                @new_jsonvar[:children][leaf.leaf_path[4].to_i][:children][leaf.leaf_path[3].to_i][:children][leaf.leaf_path[2].to_i][:children][leaf.leaf_path[1].to_i][:children] = [ {}, @leaf_json ]
              else
                @new_jsonvar[:children][leaf.leaf_path[4].to_i][:children][leaf.leaf_path[3].to_i][:children][leaf.leaf_path[2].to_i][:children][leaf.leaf_path[1].to_i][:children] << @leaf_json
              end

            end
            
          when 6

            if leaf.leaf_path[0] == "0"

              if @new_jsonvar[:children][leaf.leaf_path[5].to_i][:children][leaf.leaf_path[4].to_i][:children][leaf.leaf_path[3].to_i][:children][leaf.leaf_path[2].to_i][:children][leaf.leaf_path[1].to_i][:children].blank?
                @new_jsonvar[:children][leaf.leaf_path[5].to_i][:children][leaf.leaf_path[4].to_i][:children][leaf.leaf_path[3].to_i][:children][leaf.leaf_path[2].to_i][:children][leaf.leaf_path[1].to_i][:children] = [@leaf_json]
              else
                @new_jsonvar[:children][leaf.leaf_path[5].to_i][:children][leaf.leaf_path[4].to_i][:children][leaf.leaf_path[3].to_i][:children][leaf.leaf_path[2].to_i][:children][leaf.leaf_path[1].to_i][:children][0] = @leaf_json
              end
            else

              if @new_jsonvar[:children][leaf.leaf_path[5].to_i][:children][leaf.leaf_path[4].to_i][:children][leaf.leaf_path[3].to_i][:children][leaf.leaf_path[2].to_i][:children][leaf.leaf_path[1].to_i][:children].blank?
                @new_jsonvar[:children][leaf.leaf_path[5].to_i][:children][leaf.leaf_path[4].to_i][:children][leaf.leaf_path[3].to_i][:children][leaf.leaf_path[2].to_i][:children][leaf.leaf_path[1].to_i][:children] = [ {}, @leaf_json ]
              else
                @new_jsonvar[:children][leaf.leaf_path[5].to_i][:children][leaf.leaf_path[4].to_i][:children][leaf.leaf_path[3].to_i][:children][leaf.leaf_path[2].to_i][:children][leaf.leaf_path[1].to_i][:children] << @leaf_json
              end

            end
            
          else
            puts "I will deal with this leaf later."
          end
          
        end # of do |leaf|  ########################################################
        
      end
      puts @new_jsonvar
      @new_jsonvar
      
      
    end  # of method append_nodes
    
    
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
