class NgsRun < ApplicationRecord
  include ProjectRecord

  validates_presence_of :name

  belongs_to :higher_order_taxon
  has_many :tag_primer_maps

  has_attached_file :fastq

  validates_attachment_content_type :fastq, content_type: 'text/plain' # Using 'chemical/seq-na-fastq' does not work reliably

  validates_attachment_file_name :fastq, :matches => [/fastq\Z/, /fq\Z/, /fastq.gz\Z/, /fq.gz\Z/]

  attr_accessor :delete_fastq
  before_validation { fastq.clear if delete_fastq == '1' }

  # Check if all samples exist in app database
  def samples_exist
    tp_map = CSV.read(tag_primer_map.path, { col_sep: "\t", headers: true }) if tag_primer_map
    tp_map['#SampleID'].select { |id| !Isolate.exists?(lab_nr: id) } # TODO: Maybe shorten list if necessary
  end

  def check_fastq
    valid = true if fastq.path

    line_count = `wc -l "#{fastq.path}"`.strip.split(' ')[0].to_i
    valid &&= (line_count % 4).zero? # Number of lines is a multiple of 4

    header = File.open(fastq.path, &:readline).strip

    valid &&= header[0] == '@' # Header beginnt mit @

    valid &&= header.include?('ccs') # Header enthält 'ccs' (file ist ccs file)

    valid
  end

  def run_pipe
    # Fill description column of tag primer map
    tp_map = CSV.read(tag_primer_map.path, { col_sep: "\t", headers: true })

    tp_map.each do |row|
      sample_id = row['#SampleID']
      species = Isolate.joins(individual: :species).find_by_lab_nr(sample_id).individual.species.composed_name.gsub(' ', '_')

      row['Description'] = [sample_id, species, row['TagID'], row['Region']].join('_')
    end
  end

  def import
    run_pipe

    # Import results
  end
end
