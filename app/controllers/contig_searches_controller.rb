class ContigSearchesController < ApplicationController
  load_and_authorize_resource

  def index
    respond_to do |format|
      format.html
      format.json { render json: ContigSearchDatatable.new(view_context, current_user.id) }
    end
  end

  def new
    @contig_search = ContigSearch.new
  end

  def create
    @contig_search = ContigSearch.create!(contig_search_params)
    @contig_search.update(:user_id => current_user.id)
    redirect_to @contig_search
  end

  def show
    @contig_search = ContigSearch.find(params[:id])

    respond_to do |format|
      format.html
      format.json { render json: ContigSearchResultDatatable.new(view_context, params[:id]) }
    end
  end

  def destroy
    @contig_search.destroy
    respond_to do |format|
      format.html { redirect_to contig_searches_path, notice: 'Contig search was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private
  # Never trust parameters from the scary internet, only allow the white list through.
  def contig_search_params
    params.require(:contig_search).permit(:title, :assembled, :family, :marker, :max_age, :max_update, :min_age, :min_update, :name, :order, :species, :specimen, :verified)
  end
end
