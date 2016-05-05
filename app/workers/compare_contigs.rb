class CompareContigs

  include Sidekiq::Worker

  def perform(contig_names)

    no_match_list="No matches found for:\n\n"
    match_list="\n\nMatches found for:\n\n"

    # parse contig_names string into array
    contig_names_array=contig_names.split

    #loop over contig_names array
    contig_names_array.each do |c|

      contig_name=c[0...-4]

      #match found?
      contig = Contig.where("name ILIKE ?", contig_name).first
      if contig
        match_list+="#{c}"
        if contig.verified
          match_list+="\tverified"
        end
        match_list+="\n"
      else
        # retry by extracting one primer name and selecting the marker this primer is assigned to
        # extract primer_name

        regex= /^([A-Za-z0-9]+)_(.+)$/
        m=contig_name.match(regex)
        isolate_name=m[1]
        begin
          primer_names= m[2]
          primer_name=primer_names.split("_").last
          primer=Primer.where("name ILIKE ?", primer_name).first
          if primer
            marker=primer.marker
            if marker
              true_marker_name=marker.name
              true_contig_name=isolate_name+"_#{true_marker_name}"
              contig = Contig.where("name ILIKE ?", true_contig_name).first
              if contig
                match_list+="#{c} (found as #{true_contig_name})"
                if contig.verified
                  match_list+="\tverified"
                end
                match_list+="\n"
              else
                no_match_list+="#{c}\n"
              end
            else
              no_match_list+="#{c}\n"
            end
          else
            no_match_list+="#{c}\n"
          end
        rescue
          no_match_list+="#{c}\n"
        end
      end
    end

    no_match_list+=match_list

    # create & store file on S3 -> as for zfmk
    TxtUploader.new.create_uploaded_file(no_match_list)

  end
end