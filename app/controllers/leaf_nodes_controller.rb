class LeafNodesController < ApplicationController

  def search
    @leaf_node = LeafNode.find_by_nonce(params[:id])
  end

  def display
    @leaf_node = LeafNode.find_by_nonce(params[:id])
    @tree = Tree.find(@leaf_node.tree_id)
  end



  def index
      if params[:search]
        @leaf_nodes = LeafNode.search(params[:search]).order("created_at DESC")
        @leaf_node = @leaf_nodes.first
        @nodes = @leaf_node.related_nodes
        @tree = Tree.find(@leaf_node.tree_id)
        if @leaf_nodes.count == 1
          render :show
        else
          render :index, notice: 'Duplicate leaf node.'
        end
      else
        @leaf_nodes = LeafNode.all.order('created_at DESC')
      end
  end
  
  

  def edit
    @leaf_node = LeafNode.find(params[:id])
  end

  def update
    @leaf_node = LeafNode.find(params[:id])
    if @leaf_node.update_attributes(secure_params)
      redirect_to @leaf_node
    else
      render :edit
    end
  end

  def show
    # @leaf_node = LeafNode.find(params[:id])
    @leaf_node = LeafNode.find_by_nonce(params[:id])
    
    @nodes = @leaf_node.related_nodes
    @tree = Tree.find(@leaf_node.tree_id)
  end
  
  def new
    @leaf_node = LeafNode.new
  end
  
  def create
      @leaf_node = Product.new(secure_params)

      if @leaf_node.save
        redirect_to @leaf_node, notice: 'Leaf node was successfully created.'
       else
         render action: 'new'
      end
  end
  
  def destroy
    @leaf_node = LeafNode.find(params[:id])
    @leaf_node.destroy
    render :nothing
  end

  private

  def secure_params
    params.require(:leaf_node).permit(:nonce, :credit, :name, :height, :tree_id, :node_id, :leaf_path)
  end

end