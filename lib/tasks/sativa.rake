# frozen_string_literal: true

namespace :data do
  require 'net/ssh'
  require 'net/scp'
  require 'net/sftp'

  desc 'Check how many sequences were created or updated since last analysis and redo analysis if necessary'
  task check_new_marker_sequences: :environment do
    # TODO: Do analyses for all existing projects (except all_records)
    Marker.gbol_marker.each do |marker|
      last_analysis = MislabelAnalysis.where(automatic: true, marker: marker).order(created_at: :desc).first
      count = -1

      if last_analysis
        count = MarkerSequence.where(marker_id: marker.id).where('marker_sequences.updated_at >= ?', last_analysis.created_at).size
      end

      if (count > 50) || (count == -1) # More than 50 new seqs OR no analysis was done before
        marker_name = marker.name
        search = MarkerSequenceSearch.create(has_species: true, has_warnings: 'both', marker: marker_name, project_id: 5)

        title = "all_taxa_#{marker_name}_#{search.created_at.to_date}"
        mislabel_analysis = MislabelAnalysis.create(title: title, marker_id: marker.id, automatic: true,
                                                    total_seq_number: search.marker_sequences.size)

        mislabel_analysis.analyse_on_server
      end
    end
  end
end
