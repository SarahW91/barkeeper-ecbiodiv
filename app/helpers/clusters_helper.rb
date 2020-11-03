# frozen_string_literal: true

module ClustersHelper
  def reverse_complement(reverse)
    if reverse
      content_tag(:span, '', class: %w(glyphicon glyphicon-ok-circle), style: 'color: green;')
    else
      content_tag(:span, '', class: %w(glyphicon glyphicon-remove-circle), style: 'color: red;')
    end
  end

  def blast_warning(blast_hit)
    if blast_hit && blast_hit.taxonomy.split(',')[0] != "Embryophyta"
      color = 'red'
    else
      color = 'grey'
    end

    "color: #{color}"
  end

  def taxonomic_lineage(taxonomy)
    lineage = taxonomy.split(',')

    lineage_str = +''.html_safe

    lineage.each_with_index do |taxon, i|
      tax_entity = PgSearch.multisearch(taxon)[0]

      if tax_entity&.content == taxon
        tax_object = tax_entity.searchable_type.constantize.find(tax_entity.searchable_id)
        taxon_display = link_to(tax_object.name, edit_polymorphic_path(tax_object))
      end

      taxon_display ||= taxon

      lineage_str << "- " * i
      lineage_str << taxon_display
      lineage_str << tag(:br)
    end

    lineage_str
  end
end