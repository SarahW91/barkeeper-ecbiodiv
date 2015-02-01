class IndividualsController < ApplicationController

  before_filter :authenticate_user!

  before_action :set_individual, only: [:show, :edit, :update, :destroy]

  # GET /individuals
  # GET /individuals.json
  def index
    @individuals = Individual.includes(:species).all
    respond_to do |format|
      format.html
      format.csv { render text: @individuals.to_csv }
      format.xls
    end
  end

  def filter
    @individuals = Individual.where("individuals.specimen_id like ?", "%#{params[:term]}%")
    render json: @individuals.map(&:specimen_id)
  end

  # GET /individuals/1
  # GET /individuals/1.json
  def show
  end

  # GET /individuals/new
  def new
    @individual = Individual.new
  end

  # GET /individuals/1/edit
  def edit
  end

  # POST /individuals
  # POST /individuals.json
  def create
    @individual = Individual.new(individual_params)

    respond_to do |format|
      if @individual.save
        format.html { redirect_to @individual, notice: 'Individual was successfully created.' }
        format.json { render :show, status: :created, location: @individual }
      else
        format.html { render :new }
        format.json { render json: @individual.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /individuals/1
  # PATCH/PUT /individuals/1.json
  def update
    respond_to do |format|
      if @individual.update(individual_params)
        format.html { redirect_to @individual, notice: 'Individual was successfully updated.' }
        format.json { render :show, status: :ok, location: @individual }
      else
        format.html { render :edit }
        format.json { render json: @individual.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /individuals/1
  # DELETE /individuals/1.json
  def destroy
    @individual.destroy
    respond_to do |format|
      format.html { redirect_to individuals_url }
      format.json { head :no_content }
    end
  end

  private
  # Use callbacks to share common setup or constraints between actions.
  def set_individual
    @individual = Individual.find(params[:id])
  end

  # Never trust parameters from the scary internet, only allow the white list through.
  def individual_params
    params.require(:individual).permit(:specimen_id, :DNA_bank_id, :collector,
                                       :specimen_id,
                                       :herbarium,
                                       :voucher,
                                       :country,
                                       :state_province,
                                       :locality,
                                       :latitude,
                                       :longitude,
                                       :elevation,
                                       :exposition,
                                       :habitat,
                                       :substrate,
                                       :life_form,
                                       :collection_nr,
                                       :collection_date,
                                       :determination,
                                       :revision,
                                       :confirmation,
                                       :comments,
                                       :species_id,
                                       :species_name)
  end
end