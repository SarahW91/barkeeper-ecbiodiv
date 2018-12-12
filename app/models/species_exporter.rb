# frozen_string_literal: true

# Write SPECIMENS & STATUS to Excel-XML (xls) for use by ZFMK for their "Portal / db : bolgermany.de "
class SpeciesExporter < ApplicationRecord
  has_attached_file :species_export,
                    path: '/species_export.xls'

  # Validate content type
  validates_attachment_content_type :species_export, content_type: %w[text/xml
                                                                      application/excel
                                                                      application/vnd.ms-excel
                                                                      application/xml]
  # Validate filename
  validates_attachment_file_name :species_export, matches: /xls\Z/

  def create_species_export(project_id)
    file_to_upload = File.open('species_export.xls', 'w')

    file_to_upload.write(xml_string(project_id))
    file_to_upload.close

    self.species_export = File.open('species_export.xls')
    save!
  end

  def xml_string(project_id)
    @species = Species.includes(family: { order: :higher_order_taxon }).in_project(project_id)

    @header_cells = ['UAbteilung/Klasse',
                     'Ordnung',
                     'Familie',
                     'GBoL5_TaxID',
                     'Gattung',
                     'Art',
                     'Autor',
                     'Subspecies/Varietät',
                     'Autor (ssp./var.)']

    builder = Nokogiri::XML::Builder.new do |xml|
      xml.comment("Generated by gbol5.de web app on #{Time.zone.now}")
      xml.Workbook('xmlns' => 'urn:schemas-microsoft-com:office:spreadsheet',
                   'xmlns:o' => 'urn:schemas-microsoft-com:office:office',
                   'xmlns:x' => 'urn:schemas-microsoft-com:office:excel',
                   'xmlns:ss' => 'urn:schemas-microsoft-com:office:spreadsheet',
                   'xmlns:html' => 'https://www.w3.org/TR/REC-html40') do
        xml.Worksheet('ss:Name' => 'Sheet1') do
          xml.Table do
            # Header
            xml.Row do
              @header_cells.each do |o|
                xml.Cell do
                  xml.Data('ss:Type' => 'String') do
                    xml.text(o)
                  end
                end
              end
            end

            @species.each do |species|
              xml.Row do
                # Subdivision/Class
                xml.Cell do
                  xml.Data('ss:Type' => 'String') do
                    xml.text(species.try(:family).try(:order).try(:higher_order_taxon).try(:name))
                  end
                end

                # Order
                xml.Cell do
                  xml.Data('ss:Type' => 'String') do
                    xml.text(species.try(:family).try(:order).try(:name))
                  end
                end

                # Family
                xml.Cell do
                  xml.Data('ss:Type' => 'String') do
                    xml.text(species.try(:family).try(:name))
                  end
                end

                # GBoL5_TaxID
                xml.Cell do
                  xml.Data('ss:Type' => 'String') do
                    xml.text(species.id)
                  end
                end

                # Genus
                xml.Cell do
                  xml.Data('ss:Type' => 'String') do
                    xml.text(species.genus_name)
                  end
                end

                # Species
                xml.Cell do
                  xml.Data('ss:Type' => 'String') do
                    xml.text(species.species_epithet)
                  end
                end

                # Author
                xml.Cell do
                  xml.Data('ss:Type' => 'String') do
                    xml.text(species.author)
                  end
                end

                # Subspecies/Variety
                xml.Cell do
                  xml.Data('ss:Type' => 'String') do
                    xml.text(species.infraspecific)
                  end
                end

                # Author (ssp./var.)
                xml.Cell do
                  xml.Data('ss:Type' => 'String') do
                    xml.text(species.author_infra)
                  end
                end
              end
            end
          end
        end
      end
    end

    builder.to_xml
  end
end
