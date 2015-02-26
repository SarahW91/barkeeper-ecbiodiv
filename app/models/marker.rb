class Marker < ActiveRecord::Base
  has_many :marker_sequences
  has_many :contigs
  has_many :primers
  validates_presence_of :name

  scope :gbol_marker, -> { where(:is_gbol => true)}

  def spp_in_higher_order_taxon(higher_order_taxon_id)

    ms=MarkerSequence.select("species_id").includes(:isolate => :individual).joins(:isolate =>
                                                                                       {:individual =>
                                                                                            {:species =>
                                                                                                 {:family =>
                                                                                                      {:order => :higher_order_taxon}}}}).
        where(orders: {higher_order_taxon_id: higher_order_taxon_id}, marker_sequences: {marker_id: self.id})

    [ms.count, ms.uniq.count]
  end

end
