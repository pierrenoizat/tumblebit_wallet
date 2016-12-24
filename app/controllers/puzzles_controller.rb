class PuzzlesController < ApplicationController

  def index
    @puzzles = Puzzle.page(params[:page]).order(created_at: :asc) 
  end
  
  def show
    @puzzle = Puzzle.find(params[:id])
    @script =Script.find(@puzzle.script_id)
  end

  private
 
     def puzzle_params
       params.require(:puzzle).permit(:script_id, :y, :encrypted_signature)
     end

end