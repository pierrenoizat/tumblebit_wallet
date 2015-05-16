class NodesController < ApplicationController


  def index
    @nodes = Node.all
  end

  def edit
    @node = Node.find(params[:id])
  end

  def update
    @node = Node.find(params[:id])
    if @node.update_attributes(secure_params)
      redirect_to @node
    else
      render :edit
    end
  end

  def show
    @node = Node.find(params[:id])
  end
  
  def new
    @node = Node.new
  end
  
  def create
      @node = Product.new(secure_params)

      if @node.save
        redirect_to @node, notice: 'Node was successfully created.'
       else
         render action: 'new'
      end
  end
  
  def destroy
    @node = Node.find(params[:id])
    @node.destroy
    render :nothing
  end

  private

  def secure_params
    params.require(:node).permit(:left, :right,:height, :sum, :node_hash, :tree_id)
  end

end