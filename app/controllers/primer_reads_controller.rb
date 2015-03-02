class PrimerReadsController < ApplicationController
  before_filter :authenticate_user!, :except => [:edit, :index]

  before_action :set_primer_read, only: [:fasta, :reverse, :restore, :assign, :trim, :show, :update, :change_base, :destroy]

  def import
    PrimerRead.import(params[:file])
    redirect_to root_url, notice: 'Chromatogram imported.'
  end

  # GET /primer_reads
  # GET /primer_reads.json
  def index
    respond_to do |format|
      format.html
      format.json { render json: PrimerReadDatatable.new(view_context)}
    end
  end

  # GET /primer_reads/1
  # GET /primer_reads/1.json
  def show
  end

  # GET /primer_reads/new
  def new
    @primer_read = PrimerRead.new
  end

=begin
  def batch_create
    if params[:chromatograms]
      params[:chromatograms].each { |chromatogram|
        PrimerRead.create(chromatogram: chromatogram, name: chromatogram.original_filename)
      }
    end
    @primer_reads = PrimerRead.all
    #render :index
    redirect_to root_url, notice: 'Chromatograms imported.'
  end
=end

  def trim

    msg_hash = @primer_read.auto_trim(false)

    if msg_hash[:create_issue]
      redirect_to edit_primer_read_path, alert: msg_hash[:msg]
    else
      redirect_to edit_primer_read_path, notice: msg_hash[:msg]
    end

  end

  # tries to extract associated primer and isolate from primer read name (in turn based on uploaded scf file name:
  def assign

    msg_hash = @primer_read.auto_assign

    if msg_hash[:create_issue]
      redirect_to edit_primer_read_path, alert: msg_hash[:msg]
    else
      redirect_to edit_primer_read_path, notice: msg_hash[:msg]
    end

  end

  def reverse
    unless @primer_read.reverse
      begin
        @primer_read.update(:reverse => true)
        @primer_read.auto_trim(true)
        redirect_to edit_primer_read_path, notice: 'Reversed.'
      rescue
        redirect_to edit_primer_read_path, alert: 'Could not reverse'
      end
    else
      redirect_to edit_primer_read_path, alert: 'Already reversed.'
    end
  end

  def restore
    if @primer_read.reverse

      begin
        @primer_read.update(:reverse => false)
        @primer_read.auto_trim(true)

        redirect_to edit_primer_read_path, notice: 'Restored non-reversed state.'
      rescue
        redirect_to edit_primer_read_path, alert: 'Could not restore.'
      end
    else
      redirect_to edit_primer_read_path, alert: 'Read is not reversed.'
    end
  end

  # GET /primer_reads/1/edit
  def edit
    @primer_read = PrimerRead.includes(:primer, :contig).find(params[:id]) #TODO Add select statement here to initially NOT load chromatogram?
  end

  # POST /primer_reads
  # POST /primer_reads.json

  def create

    @primer_read = PrimerRead.new(primer_read_params)

    if @primer_read.save
      PherogramProcessing.perform_async(@primer_read.id)
    end

  end


  # PATCH/PUT /primer_reads/1
  # PATCH/PUT /primer_reads/1.json
  def update
    respond_to do |format|
      if @primer_read.update(primer_read_params)
        format.html { redirect_to edit_primer_read_path(@primer_read), notice: 'Primer read was successfully updated.' }
        format.json { render :show, status: :ok, location: @primer_read }
      else
        format.html { render :edit }
        format.json { render json: @primer_read.errors, status: :unprocessable_entity }
      end
    end
  end

  def change_base
    # respond_to :js
    #TODO how to get data sent by ajax call?
    sequence= @primer_read.sequence
    pos=params[:position].to_i
    base=params[:base]
    sequence[pos]=base
    @primer_read.update(:sequence => sequence)
    render :nothing => true
  end

  # DELETE /primer_reads/1
  # DELETE /primer_reads/1.json
  def destroy
    @primer_read.destroy
    respond_to do |format|
      format.html { redirect_to primer_reads_url }
      format.json { head :no_content }
    end
  end


  def fasta
    str=">#{@primer_read.name} \n#{@primer_read.trimmed_seq}"
    # send_data str
    send_data(str, :filename => "#{@primer_read.name}.fas", :type => "application/txt")
  end

  private
  # Use callbacks to share common setup or constraints between actions.
  def set_primer_read
    @primer_read = PrimerRead.find(params[:id])
  end

  # Never trust parameters from the scary internet, only allow the white list through.
  def primer_read_params
    params.require(:primer_read).permit(:assembled,
                                        :quality_string,
                                        :used_for_con, :file, :name, :sequence, :pherogram_url, :chromatogram, :primer_id, :contig_id,
                                        :contig_name, :isolate_id, :chromatograms, :trimmedReadEnd, :trimmedReadStart,
                                        :min_quality_score, :count_in_window, :window_size,
                                        :position, :base)
  end
end