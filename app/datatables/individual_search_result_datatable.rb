class IndividualSearchResultDatatable
  include Rails.application.routes.url_helpers

  delegate :url_helpers, to: 'Rails.application.routes'
  delegate :params, :link_to, :h, to: :@view

  def initialize(view, search_id)
    @view = view
    @search_id = search_id
  end

  def as_json(options = {})
    {
        :sEcho => params[:sEcho].to_i,
        :iTotalRecords => Individual.count,
        :iTotalDisplayRecords => individuals_data.total_entries,
        :aaData => data
    }
  end

  private

  def data
    individuals_data.map do |individual|
      species_name = ''
      species_id = 0

      if individual.try(:species)
        species_name = individual.species.name_for_display
        species_id = individual.species.id
      end

      [
          link_to(individual.specimen_id, edit_individual_path(individual)),
          link_to(species_name, edit_species_path(species_id)),
          individual.herbarium,
          individual.latitude_original,
          individual.longitude_original,
          individual.updated_at.in_time_zone("CET").strftime("%Y-%m-%d %H:%M:%S"),
          link_to('Delete', individual, method: :delete, data: { confirm: 'Are you sure?' })
      ]
    end
  end

  def individuals_data
    @search_result ||= IndividualSearch.find_by_id(@search_id).individuals.includes(:species).reorder("#{sort_column} #{sort_direction}")

    @search_result = @search_result.page(page).per_page(per_page)

    if params[:sSearch].present?
      @search_result = @search_result.where("individuals.specimen_id ILIKE :search", search: "%#{params[:sSearch]}%")
    end

    @search_result
  end

  def page
    params[:iDisplayStart].to_i/per_page + 1
  end

  def per_page
    params[:iDisplayLength].to_i > 0 ? params[:iDisplayLength].to_i : 10
  end

  def sort_column
    columns = %w[individuals.specimen_id species.composed_name herbarium latitude_original longitude_original individuals.updated_at]
    columns[params[:iSortCol_0].to_i]
  end

  def sort_direction
    params[:sSortDir_0] == "desc" ? "desc" : "asc"
  end
end