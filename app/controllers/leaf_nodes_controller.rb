class LeafNodesController < ApplicationController


  def index
    @leaf_nodes = LeafNode.all
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
    @leaf_node = LeafNode.find(params[:id])
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
    params.require(:leaf_node).permit(:nonce, :credit, :name, :height, :tree_id)
  end

end