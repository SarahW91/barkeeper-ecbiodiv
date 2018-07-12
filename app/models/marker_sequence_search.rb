class MarkerSequenceSearch < ApplicationRecord
  belongs_to :user
  belongs_to :project

  enum has_warnings: [:both, :yes, :no]

  def marker_sequences
    @marker_sequences ||= find_marker_sequences
  end

  def as_fasta
    fasta = ''

    marker_sequences.each do |marker_sequence|
      sequence = Bio::Sequence::NA.new(marker_sequence.sequence)

      name = marker_sequence.name.delete(' ')
      name << "_#{marker_sequence.isolate&.individual&.species&.composed_name&.gsub(' ', '_')}"

      fasta += sequence.to_fasta(name, 80)
    end

    fasta
  end

  def taxon_file
    taxa = ''

    marker_sequences.includes(isolate: [individual: [species: [family: [order: :higher_order_taxon]]]]).each do |marker_sequence|
      species = marker_sequence.isolate&.individual&.species&.composed_name
      family = marker_sequence.isolate&.individual&.species&.family&.name
      order = marker_sequence.isolate&.individual&.species&.family&.order&.name
      hot = marker_sequence.isolate&.individual&.species&.family&.order&.higher_order_taxon&.name

      taxa << marker_sequence.name.delete(' ')
      taxa << "_#{marker_sequence.isolate&.individual&.species&.composed_name&.gsub(' ', '_')}"
      taxa << "\t"
      taxa << "Eukaryota;Embryophyta;#{hot};#{order};#{family};#{species}\n"
    end

    taxa
  end

  private

  def find_marker_sequences
    marker_sequences = MarkerSequence.in_project(project_id).order(:name)
    marker_sequences = marker_sequences.where("marker_sequences.name ilike ?", "%#{name}%") if name.present?

    if verified != 'both'
      marker_sequences = marker_sequences.verified if (verified == 'verified')
      marker_sequences = marker_sequences.not_verified if (verified == 'unverified')
    end

    marker_sequences = marker_sequences.has_species if has_species.present?

    if has_warnings != 'both'
      marker_sequences = marker_sequences.with_warnings if (has_warnings == 'yes')
      marker_sequences = marker_sequences.where.not(id: MarkerSequence.with_warnings.pluck(:id)) if (has_warnings == 'no')
    end

    marker_sequences = marker_sequences.joins(:marker).where("markers.name ilike ?", "%#{marker}%") if marker.present?

    marker_sequences = marker_sequences.joins(isolate: {individual: {species: {family: {order: :higher_order_taxon}}}}).where("higher_order_taxa.name ilike ?", "%#{higher_order_taxon}%") if higher_order_taxon.present?

    marker_sequences = marker_sequences.joins(isolate: {individual: {species: {family: :order}}}).where("orders.name ilike ?", "%#{order}%") if order.present?

    marker_sequences = marker_sequences.joins(isolate: {individual: {species: :family}}).where("families.name ilike ?", "%#{family}%") if family.present?

    marker_sequences = marker_sequences.joins(isolate: {individual: :species }).where("species.composed_name ilike ?", "%#{species}%") if species.present?

    marker_sequences = marker_sequences.joins(isolate: :individual).where("individuals.specimen_id ilike ?", "%#{specimen}%") if specimen.present?

    marker_sequences = marker_sequences.where("length(marker_sequences.sequence) >= ?", min_length) if min_length.present?
    marker_sequences = marker_sequences.where("length(marker_sequences.sequence) <= ?", max_length) if max_length.present?

    marker_sequences
  end
end
