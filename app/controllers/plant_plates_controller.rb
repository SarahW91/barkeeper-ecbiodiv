# frozen_string_literal: true

class PlantPlatesController < ApplicationController
  include ProjectConcern

  load_and_authorize_resource

  before_action :set_plant_plate, only: %i[show edit update destroy]

  # GET /plant_plates
  # GET /plant_plates.json
  def index
    respond_to do |format|
      format.html
      format.json { render json: PlantPlateDatatable.new(view_context, current_project_id) }
    end
  end

  # GET /plant_plates/1
  # GET /plant_plates/1.json
  def show; end

  # GET /plant_plates/new
  def new
    @plant_plate = PlantPlate.new
  end

  # GET /plant_plates/1/edit
  def edit; end

  # POST /plant_plates
  # POST /plant_plates.json
  def create
    @plant_plate = PlantPlate.new(plant_plate_params)
    @plant_plate.add_project(current_project_id)

    respond_to do |format|
      if @plant_plate.save
        format.html { redirect_to plant_plates_path, notice: 'Plant plate was successfully created.' }
        format.json { render :show, status: :created, location: @plant_plate }
      else
        format.html { render :new }
        format.json { render json: @plant_plate.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /plant_plates/1
  # PATCH/PUT /plant_plates/1.json
  def update
    respond_to do |format|
      if @plant_plate.update(plant_plate_params)
        format.html { redirect_to plant_plates_path, notice: 'Plant plate was successfully updated.' }
        format.json { render :show, status: :ok, location: @plant_plate }
      else
        format.html { render :edit }
        format.json { render json: @plant_plate.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /plant_plates/1
  # DELETE /plant_plates/1.json
  def destroy
    @plant_plate.destroy
    respond_to do |format|
      format.html { redirect_to plant_plates_url }
      format.json { head :no_content }
    end
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_plant_plate
    @plant_plate = PlantPlate.find(params[:id])
  end

  # Never trust parameters from the scary internet, only allow the white list through.
  def plant_plate_params
    params.require(:plant_plate).permit(:name, project_ids: [])
  end
end
