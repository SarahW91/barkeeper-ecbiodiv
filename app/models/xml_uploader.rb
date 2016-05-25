# write to Excel-XML (xls) for use by ZFMK for their "Portal / db "

class XmlUploader < ActiveRecord::Base

  #todo later rename  :uploaded_file to xml_File or s.th.

  has_attached_file :uploaded_file,
                    :storage => :s3,
                    :s3_credentials => Proc.new{ |a| a.instance.s3_credentials },
                    :path => "/specimens.xls"


  # Validate content type
  validates_attachment_content_type :uploaded_file, :content_type => /\Aapplication\/xml/

  # Validate filename
  validates_attachment_file_name :uploaded_file, :matches => [/xls\Z/]

  def create_uploaded_file

    file_to_upload = File.open("specimens.xls", "w")

    file_to_upload.write(xml_string)
    file_to_upload.close
    self.uploaded_file = File.open("specimens.xls")
    self.save!

    # puts xml_string
  end

  #todo remove s3 credentials from code everywhere

  def s3_credentials
    {:bucket => "gbol5", :access_key_id => "AKIAINH5TDSKSWQ6J62A", :secret_access_key => "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"}
  end

  def xml_string
    # get all indiv.
    @individuals=Individual.includes(:species => :family).all

    @states=["Baden-Württemberg","Bayern","Berlin","Brandenburg","Bremen","Hamburg","Hessen","Mecklenburg-Vorpommern","Niedersachsen","Nordrhein-Westfalen","Rheinland-Pfalz","Saarland","Sachsen","Sachsen-Anhalt","Schleswig-Holstein","Thüringen"]

    @header_cells = ["GBOL5 specimen ID",
                     "Feldnummer",
                     "Institut",
                     "Sammlungs-Nr.",
                     "Familie",
                     "Taxon-Name",
                     "Erstbeschreiber Jahr",
                     "evtl. Bemerkung Taxonomie",
                     "Name",
                     "Datum",
                     "Gewebetyp und Menge",
                     "Anzahl Individuen",
                     "Fixierungsmethode"   ,
                     "Entwicklungsstadium",
                     "Sex",
                     "evtl. Bemerkungen zur Probe",
                     "Fundortbeschreibung",
                     "Region",
                     "Bundesland",
                     "Land",
                     "Datum",
                     "Sammelmethode",
                     "Breitengrad",
                     "Längengrad",
                     "Benutzte Methode",
                     "Ungenauigkeitsangabe",
                     "Höhe/Tiefe [m]",
                     "Habitat",
                     "Sammler",
                     "Nummer",
                     "Behörde",
                     "Sequenz vorhanden?"
    ]

    builder = Nokogiri::XML::Builder.new do |xml|

      xml.comment("Generated by gbol5.de web app on #{Time.zone.now}")
      xml.Workbook('xmlns'=>"urn:schemas-microsoft-com:office:spreadsheet",
                   'xmlns:o'=>"urn:schemas-microsoft-com:office:office",
                   'xmlns:x'=>"urn:schemas-microsoft-com:office:excel",
                   'xmlns:ss'=>"urn:schemas-microsoft-com:office:spreadsheet",
                   'xmlns:html'=>"http://www.w3.org/TR/REC-html40") {
        xml.Worksheet('ss:Name'=>"Sheet1") {
          xml.Table {
            xml.Row{

              @header_cells.each do |o|
                xml.Cell {
                  xml.Data('ss:Type' => "String") {
                    xml.text(o)
                  }
                }
              end

            }
            @individuals.each do |individual|
              xml.Row{
                xml.Cell {
                  xml.Data('ss:Type' => "String") {
                    #previous version with "Gbol-Nr.":
                    # xml.text(individual.try(:isolates).first.try(:lab_nr))
                    xml.text(individual.id)
                  }
                }
                xml.Cell {
                  xml.Data('ss:Type' => "String") {
                    if individual.collection_nr
                      if individual.collection_nr.include? 's.n.' or individual.collection_nr.include? 's. n.'
                        xml.text('')
                      else
                        xml.text(individual.collection_nr)
                      end
                    end
                  }
                }
                xml.Cell {
                  xml.Data('ss:Type' => "String") {
                    xml.text(individual.herbarium)
                  }
                }
                xml.Cell {
                  xml.Data('ss:Type' => "String") {
                    if individual.specimen_id == "<no info available in DNA Bank>"
                      xml.text('')
                    else
                      xml.text(individual.specimen_id)
                    end
                  }
                }
                xml.Cell {
                  xml.Data('ss:Type' => "String") {
                    xml.text(individual.try(:species).try(:family).try(:name))
                  }
                }
                xml.Cell {
                  xml.Data('ss:Type' => "String") {
                    xml.text(individual.try(:species).try(:name_for_display))
                  }
                }
                xml.Cell {
                  xml.Data('ss:Type' => "String") {
                    xml.text(individual.try(:species).try(:author))
                  }
                }
                xml.Cell {
                  xml.Data('ss:Type' => "String") {
                    xml.text('')
                  }
                }
                xml.Cell {
                  xml.Data('ss:Type' => "String") {
                    xml.text(individual.determination)
                  }
                }
                xml.Cell {
                  xml.Data('ss:Type' => "String") {
                    xml.text('')
                  }
                }
                xml.Cell {
                  xml.Data('ss:Type' => "String") {
                    xml.text('Blattmaterial')
                  }
                }
                xml.Cell {
                  xml.Data('ss:Type' => "String") {
                    xml.text('')
                  }
                }
                xml.Cell {
                  xml.Data('ss:Type' => "String") {
                    xml.text('Silica gel')
                  }
                }
                xml.Cell {
                  xml.Data('ss:Type' => "String") {
                    xml.text('')
                  }
                }
                xml.Cell {
                  xml.Data('ss:Type' => "String") {
                    xml.text('')
                  }
                }
                xml.Cell {
                  xml.Data('ss:Type' => "String") {
                    xml.text("gbol5.de/individuals/#{individual.id}/edit")
                  }
                }
                xml.Cell {
                  xml.Data('ss:Type' => "String") {
                    xml.text(individual.locality)
                  }
                }
                xml.Cell {
                  xml.Data('ss:Type' => "String") {
                    xml.text('')
                  }
                }
                xml.Cell {
                  xml.Data('ss:Type' => "String") {

                    if individual.country == 'Germany'
                      # tests first if is a Bundesland; outputs nothing if other crap was entered in this field:

                      if @states.include? individual.state_province
                        xml.text(individual.state_province)
                      else
                        xml.text('')
                      end

                      # stuff from Schweiz etc
                    else
                      xml.text('Europa')
                    end
                  }
                }
                xml.Cell {
                  xml.Data('ss:Type' => "String") {
                    xml.text(individual.country)
                  }
                }

                xml.Cell {
                  xml.Data('ss:Type' => "String") {
                    xml.text(individual.collection_date)
                  }
                }
                xml.Cell {
                  xml.Data('ss:Type' => "String") {
                    xml.text('')
                  }
                }
                xml.Cell {
                  xml.Data('ss:Type' => "String") {
                    xml.text(individual.latitude)
                  }
                }
                xml.Cell {
                  xml.Data('ss:Type' => "String") {
                    xml.text(individual.longitude)
                  }
                }
                xml.Cell {
                  xml.Data('ss:Type' => "String") {
                    xml.text('')
                  }
                }
                xml.Cell {
                  xml.Data('ss:Type' => "String") {
                    xml.text("")
                  }
                }
                xml.Cell {
                  xml.Data('ss:Type' => "String") {
                    xml.text(individual.elevation)
                  }
                }
                xml.Cell {
                  xml.Data('ss:Type' => "String") {
                    xml.text(individual.habitat)
                  }
                }
                xml.Cell {
                  xml.Data('ss:Type' => "String") {
                    xml.text(individual.collector)
                  }
                }
                xml.Cell {
                  xml.Data('ss:Type' => "String") {
                    xml.text(individual.collection_nr)
                  }
                }

                xml.Cell {
                  xml.Data('ss:Type' => "String") {
                    xml.text('')
                  }
                }

                ms=individual.try(:isolates).first.try(:marker_sequences)

                if ms and ms.length > 0
                  xml.Cell {
                    xml.Data('ss:Type' => "String") {
                      xml.text('1')
                    }
                  }

                else
                  xml.Cell {
                    xml.Data('ss:Type' => "String") {
                      xml.text('0')
                    }
                  }

                end

              }
            end
          }
        }
      }

    end

    builder.to_xml

  end


end