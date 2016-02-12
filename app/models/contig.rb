# noinspection RubyStringKeysInHashInspection
class Contig < ActiveRecord::Base
  belongs_to :marker_sequence
  belongs_to :marker
  belongs_to :isolate
  has_many :primer_reads
  validates_presence_of :name
  has_many :issues
  has_many :partial_cons
  has_and_belongs_to_many :projects

  scope :assembled, -> { where(:assembled => true)}
  scope :not_assembled, -> { where.not(:assembled => true)}
  scope :verified, -> { where.not(:verified_by => nil)}
  scope :need_verification, -> { where(:verified_by => nil)}
  scope :assembled_need_verification, -> { assembled.where(:verified_by => nil)}

  def self.spp_in_higher_order_taxon(higher_order_taxon_id)

    contigs=Contig.select("species_id").includes(:isolate => :individual).joins(:isolate => {:individual => {:species => {:family => {:order => :higher_order_taxon}}}}).where(orders: {higher_order_taxon_id: higher_order_taxon_id})
    contigs_s=Contig.select("species_component").includes(:isolate => :individual).joins(:isolate => {:individual => {:species => {:family => {:order => :higher_order_taxon}}}}).where(orders: {higher_order_taxon_id: higher_order_taxon_id})
    contigs_i=Contig.select("individual_id").includes(:isolate => :individual).joins(:isolate => {:individual => {:species => {:family => {:order => :higher_order_taxon}}}}).where(orders: {higher_order_taxon_id: higher_order_taxon_id})

    [contigs.count, contigs_s.uniq.count, contigs.uniq.count, contigs_i.uniq.count]
  end

  def isolate_name
    isolate.try(:lab_nr)
  end

  def isolate_name=(name)
    if name == ''
      self.isolate = nil
    else
      self.isolate = Isolate.find_or_create_by(:lab_nr => name) if name.present?
    end
  end

  def marker_sequence_name
    marker_sequence.try(:name)
  end

  def marker_sequence_name=(name)
    if name == ''
      self.marker_sequence = nil
    else
      self.marker_sequence = MarkerSequence.find_or_create_by(:name => name) if name.present?
    end
  end


  def generate_name
    if self.marker.present? and self.isolate.present?
      self.name = "#{self.isolate.lab_nr}_#{self.marker.name}"
    else
      self.name='<unnamed>'
    end
  end

  def mda(width,height)
    Array.new(width).map!{ Array.new(height) }
  end

  def degapped_consensus
    self.consensus.gsub('-', '')
  end

  def auto_overlap
    msg= nil

    remaining_reads = Array.new(self.primer_reads.use_for_assembly) #creates local Array to mess around without affecting db

    #test how many
    if remaining_reads.size > 10
      msg= 'Currently no more than 10 reads allowed for assembly.'
      return
    elsif remaining_reads.size < 2
      msg= 'Need >1 reads for overlap.'
      return
    end

    #test if trimmed_Seq

    starting_read = remaining_reads.delete_at(0) #Deletes the element at the specified index, returning that element, or nil if the index is out of range.

    assembled_reads =  [starting_read] # successfully overlapped reads
    growing_consensus = {:reads => [{:read => starting_read,
                                     :aligned_seq => starting_read.trimmed_seq,
                                     :aligned_qualities => starting_read.trimmed_quals}],
                         :consensus => starting_read.trimmed_seq,
                         :consensus_qualities => starting_read.trimmed_quals}

    partial_contigs = Array.new #contains singleton reads and successful overlaps (sub-contigs) that
    # themselves are isolated (including the single & final contig if everything could be overlapped)
    # format: partial_contigs.push({:reads => assembled_reads, :consensus => growing_consensus })


    assemble(growing_consensus, assembled_reads, partial_contigs, remaining_reads)

    current_largest_partial_contig=0
    current_largest_partial_contig_seq=nil

    # output pde & fasta & update records in db:
    fas_str=""

    app_url="gbol5.herokuapp.com/"

    pde_beginning="<?xml version=\"1.0\" standalone=\"no\"?><!-- Generated by GBOL5 web app
#{Time.now}  -->
<phyde id=\"wL6obVNH1kuwviaB\" version=\"0.994\"><description></description>"

    pde_header="<header><entries>
32 \"GBOL5 URL\" STRING
</entries>"

    pde_matrix=""

    #clean previously stored partial_cons:
    self.partial_cons.destroy_all

    height=0 #count needed lines for pde dimensions
    max_width=0

    block_seqs=[] #collect sequences for block, later fill with '?' up to max_width

    partial_contigs.each do |partial_contig|

      #single partial_contig: ({:reads => assembled_reads, :consensus => growing_consensus})

      if partial_contig[:reads].size >1 # something where 2 or more primers overlapped:

        #growing_consensus = {:reads => [{:read => starting_read, :aligned_seq => starting_read.trimmed_seq}],
        # :consensus => starting_read.trimmed_seq }

        if partial_contig[:reads].size > current_largest_partial_contig
          current_largest_partial_contig = partial_contig[:reads].size
          current_largest_partial_contig_seq=partial_contig[:consensus][:consensus]
        end

        growing_consensus=partial_contig[:consensus]

        fas_str += ">#{self.name}\n"

        pc=PartialCon.create(:aligned_sequence => growing_consensus[:consensus], :aligned_qualities => growing_consensus[:consensus_qualities])


        pde_header+="<seq idx=\"#{height}\"><e id=\"1\">#{self.name}</e><e id=\"32\">#{app_url}partial_contigs/#{pc.id}</e></seq>\n"
        height+=1

        fas_str += "#{growing_consensus[:consensus]}\n"

        block_seqs << growing_consensus[:consensus]

        max_width = growing_consensus[:consensus].length if  growing_consensus[:consensus].length > max_width

        # write out aligned seqs:

        growing_consensus[:reads].each do |aligned_read|

          chromatogram_name=aligned_read[:read].name

          chromatogram_name=chromatogram_name.gsub("\.ab1", "\.scf")

          fas_str += ">#{chromatogram_name}\n"

          pde_header+="<seq idx=\"#{height}\"><e id=\"1\">#{chromatogram_name}</e><e id=\"2\">#{chromatogram_name}</e><e id=\"32\">#{app_url}primer_reads/#{aligned_read[:read].id}/edit</e></seq>\n"
          height+=1


          #get original primer_read from db:
          pr=PrimerRead.find(aligned_read[:read].id)
          pr.update(:aligned_seq=>aligned_read[:aligned_seq], :assembled => true, :aligned_qualities => aligned_read[:aligned_qualities])
          pc.primer_reads << pr

          fas_str += "#{aligned_read[:aligned_seq]}\n"

          block_seqs << aligned_read[:aligned_seq]

          max_width = aligned_read[:aligned_seq].length if  aligned_read[:aligned_seq].length > max_width
        end

        self.partial_cons << pc

      else # singleton

        chromatogram_name=partial_contig[:reads].first.name

        chromatogram_name=chromatogram_name.gsub("\.ab1", "\.scf")

        fas_str += ">#{chromatogram_name}\n"
        fas_str += "#{partial_contig[:reads].first.trimmed_seq}\n"

        pde_header+="<seq idx=\"#{height}\"><e id=\"1\">#{chromatogram_name}</e><e id=\"2\">#{chromatogram_name}</e><e id=\"32\">#{app_url}primer_reads/#{partial_contig[:reads].first.id}/edit</e></seq>\n"

        height+=1

        block_seqs << partial_contig[:reads].first.trimmed_seq

        max_width = partial_contig[:reads].first.trimmed_seq.length if  partial_contig[:reads].first.trimmed_seq.length > max_width
      end

    end

    # set to "assembled" & create MarkerSequence if applicable
    if current_largest_partial_contig >= self.marker.expected_reads
      self.update(:assembled => true)

      ms=MarkerSequence.find_or_create_by(:name => self.name, :sequence => current_largest_partial_contig_seq.gsub('-',''))
      ms.contigs << self
      ms.marker = self.marker
      ms.isolate = self.isolate
      ms.save

    end

    self.update(:fas => fas_str)
    # end  output fasta.

    pde_header+="</header>\n"

    pde_dimensions="<alignment datatype=\"dna\" width=\"#{max_width}\" height=\"#{height}\" gencode=\"0\" offset=\"-1\">"

    pde_matrix_dimensions="<block x=\"0\" y=\"0\" width=\"#{max_width}\" height=\"#{height}\">"


    block_seqs.each do |seq|

      nr_of_questionmarks_to_add = max_width - seq.length

      nr_of_questionmarks_to_add.times do
        seq+='?'
      end

      pde_matrix+="#{seq}\\FF\n"
    end


    pde_closure="</block></matrix></alignment></phyde>"

    final_pde_str=pde_beginning+pde_dimensions+pde_header+"<matrix>"+pde_matrix_dimensions+pde_matrix+pde_closure

    self.update(:pde => final_pde_str)

    if msg
      Issue.create(:title => msg, :contig_id => self.id)
      self.assembled=false
    end

  end


  # recursive assembly function

  def assemble(growing_consensus, assembled_reads, partial_contigs, remaining_reads)

    # Try overlap all remaining_reads with growing_consensus

    none_overlapped=true

    remaining_reads.each do |read|

      aligned_seqs = overlap(growing_consensus, read.trimmed_seq, read.trimmed_quals)

      # if one overlaps,

      if aligned_seqs

        none_overlapped=false

        # only in case overlap worked copy the adjusted_aligned sequences that are returned from "overlap" over to growing_consensus:
        (0...aligned_seqs[:adjusted_prev_aligned_reads].size).each { |i|
          growing_consensus[:reads][i][:aligned_seq] = aligned_seqs[:adjusted_prev_aligned_reads][i]
          growing_consensus[:reads][i][:aligned_qualities] = aligned_seqs[:adjusted_prev_aligned_qualities][i]
        }

        growing_consensus[:reads].push({:read => read,
                                        :aligned_seq => aligned_seqs[:read_seq],
                                        :aligned_qualities => aligned_seqs[:read_qal]})


        # move it into assembled_reads
        overlapped_read = remaining_reads.delete(read)
        assembled_reads.push(overlapped_read)

        r=compute_consensus(aligned_seqs[:growing_cons_seq],
                            aligned_seqs[:growing_consensus_qualities],
                            aligned_seqs[:read_seq],
                            aligned_seqs[:read_qal])

        growing_consensus[:consensus]=r.first
        growing_consensus[:consensus_qualities]=r.last

        # break loop through remaining_reads
        break

      end

    end

    # if none overlaps,
    if none_overlapped

      # move assembled_reads into partial_contigs_and_singleton_reads
      partial_contigs.push({:reads => assembled_reads, :consensus => growing_consensus})

      # move first of remaining_reads into growing_consensus & assembled_reads
      # ( just as during initializing prior to first function call)

      new_starting_read = remaining_reads.delete_at(0)

      if new_starting_read #catch case when new aligned_read could not be pruned

        growing_assembled_reads_reset = [new_starting_read]

        growing_consensus_reset = {:reads => [{:read => new_starting_read,
                                               :aligned_seq => new_starting_read.trimmed_seq,
                                               :aligned_qualities => new_starting_read.trimmed_quals}],
                                   :consensus => new_starting_read.trimmed_seq, :consensus_qualities => new_starting_read.trimmed_quals}

        assemble(growing_consensus_reset, growing_assembled_reads_reset, partial_contigs, remaining_reads)
      end

    else

      assemble(growing_consensus, assembled_reads, partial_contigs, remaining_reads)

    end

  end

  #perform Needleman-Wunsch-based overlapping:

  def overlap(growing_cons_hash, read, qualities)

    growing_consensus = growing_cons_hash[:consensus]
    growing_consensus_qualities = growing_cons_hash[:consensus_qualities]

    previously_aligned_reads = Array.new
    previously_aligned_qualities = Array.new

    growing_cons_hash[:reads].each do |curr_read|
      previously_aligned_reads.push(curr_read[:aligned_seq])
      previously_aligned_qualities.push(curr_read[:aligned_qualities])
    end


    gap = -5

    # similarity matrix

    s = { 'AA' =>  1,
          'AG' => -1,
          'AC' => -1,
          'AT' => -1,
          'AN' => -1,
          'A-' => -1,
          'GA' => -1,
          'GG' =>  1,
          'GC' => -1,
          'GT' => -1,
          'GN' => -1,
          'G-' => -1,
          'CA' => -1,
          'CG' => -1,
          'CC' =>  1,
          'CT' => -1,
          'CN' => -1,
          'C-' => -1,
          'TA' => -1,
          'TG' => -1,
          'TC' => -1,
          'TT' =>  1,
          'TN' => -1,
          'T-' => -1,
          'NA' => -1,
          'NG' => -1,
          'NC' => -1,
          'NT' => -1,
          'NN' => 1,
          'N-' => 1,
          '-A' => -1,
          '-G' => -1,
          '-C' => -1,
          '-T' => -1,
          '--' => 1,
    }

    rows = read.length + 1
    cols = growing_consensus.length + 1

    a = mda(rows,cols)

    # Since we would like not to penalize start gaps, this can be accounted for by initializing the first row and first column of
    # the dynamic programming table to zeros. This is to say that the part of the alignment that starts with gaps in x or gaps in y is given
    # a score of zero.

    for i in 0...rows do a[i][0] = 0 end
    for j in 0...cols do a[0][j] = 0 end


    (1...rows).each { |i|
      (1...cols).each { |j|
        choice1 = a[i-1][j-1] + s[(read[i-1] + growing_consensus[j-1]).upcase] #match
        choice2 = a[i-1][j] + gap #insert
        choice3 = a[i][j-1] + gap #delete
        a[i][j] = [choice1, choice2, choice3].max
      }
    }

    aligned_read_seq = '' # -> aligned_read
    aligned_read_qual = []

    aligned_cons_seq = '' # -> growing_consensus
    aligned_cons_qual = []

    adjusted_prev_aligned_reads = Array.new
    adjusted_prev_aligned_qualities = Array.new

    (0...previously_aligned_reads.size).each { |_|
      new_seq=''
      adjusted_prev_aligned_reads.push(new_seq)
      adjusted_prev_aligned_qualities.push([])
    }


    # for classic Needleman-Wunsch:

    #start from lowermost rightmost cell

    #for overlap:

    # the best score is now in A(m, j) such that A(m, j) = max_k,l(A(k,n),A(m,l)) and the alignment itself can be
    # obtained by tracing back from A(m, j) to A(0, 0) as before.

    i = read.length
    j = growing_consensus.length

    bestscore = a[i][j]
    bestscore_i = i
    bestscore_j = j

    while i > 0
      if a[i][j] > bestscore
        bestscore = a[i][j]
        bestscore_i = i
        bestscore_j = j
      end
      i -= 1
    end

    i = read.length
    j = growing_consensus.length

    while j > 0
      if a[i][j] > bestscore
        bestscore = a[i][j]
        bestscore_i = i
        bestscore_j = j
      end
      j -= 1
    end

    # add extending overlapping aligned_cons_seq

    i = read.length
    j = growing_consensus.length

    #add 5' extending gaps...
    while i > bestscore_i
      aligned_read_seq = read[i-1].chr + aligned_read_seq
      aligned_read_qual.unshift(qualities[i-1])

      aligned_cons_seq = aligned_cons_seq + '-'
      aligned_cons_qual.push(-1) # -1 ~ '-'

      # mirror everything that's done to aligned_cons_seq in all previously aligned_seqs:
      for k in 0...adjusted_prev_aligned_reads.size do
        adjusted_prev_aligned_reads[k] = adjusted_prev_aligned_reads[k] + '-'
        adjusted_prev_aligned_qualities[k].push(-1)
      end

      i -= 1
    end


    while j > bestscore_j
      aligned_read_seq = aligned_read_seq + '-'
      aligned_read_qual.push(-1)
      aligned_cons_seq = growing_consensus[j-1].chr + aligned_cons_seq
      aligned_cons_qual.unshift(growing_consensus_qualities[j-1])

      for k in 0...adjusted_prev_aligned_reads.size do
        adjusted_prev_aligned_reads[k] = previously_aligned_reads[k][j-1].chr + adjusted_prev_aligned_reads[k]
        adjusted_prev_aligned_qualities[k].unshift(previously_aligned_qualities[k][j-1])
      end

      j -= 1
    end

    #tracing back...

    i = bestscore_i
    j = bestscore_j

    while i > 0 and j > 0
      score = a[i][j]
      score_diag = a[i-1][j-1]
      score_up = a[i][j-1]
      score_left = a[i-1][j]
      if score == score_diag + s[read[i-1].chr + growing_consensus[j-1].chr] #match
        aligned_read_seq = read[i-1].chr + aligned_read_seq
        aligned_read_qual.unshift(qualities[i-1])
        aligned_cons_seq = growing_consensus[j-1].chr + aligned_cons_seq
        aligned_cons_qual.unshift(growing_consensus_qualities[j-1])

        for k in 0...adjusted_prev_aligned_reads.size do
          adjusted_prev_aligned_reads[k] = previously_aligned_reads[k][j-1].chr + adjusted_prev_aligned_reads[k]
          adjusted_prev_aligned_qualities[k].unshift(previously_aligned_qualities[k][j-1])
        end

        i -= 1
        j -= 1
      elsif score == score_left + gap #insert
        aligned_read_seq = read[i-1].chr + aligned_read_seq
        aligned_read_qual.unshift(qualities[i-1])
        aligned_cons_seq = '-' + aligned_cons_seq
        aligned_cons_qual.unshift(-1)

        for k in 0...adjusted_prev_aligned_reads.size do
          adjusted_prev_aligned_reads[k] = '-' + adjusted_prev_aligned_reads[k]
          adjusted_prev_aligned_qualities[k].unshift(-1)
        end

        i -= 1
      elsif score == score_up + gap #delete
        aligned_read_seq = '-' + aligned_read_seq
        aligned_read_qual.unshift(-1)
        aligned_cons_seq = growing_consensus[j-1].chr + aligned_cons_seq
        aligned_cons_qual.unshift(growing_consensus_qualities[j-1])

        for k in 0...adjusted_prev_aligned_reads.size do
          adjusted_prev_aligned_reads[k] = previously_aligned_reads[k][j-1].chr + adjusted_prev_aligned_reads[k]
          adjusted_prev_aligned_qualities[k].unshift(previously_aligned_qualities[k][j-1])
        end

        j -= 1
      end
    end

    #add 3' extending gaps...
    while i > 0
      aligned_read_seq = read[i-1].chr + aligned_read_seq
      aligned_read_qual.unshift(qualities[i-1])
      aligned_cons_seq = '-' + aligned_cons_seq
      aligned_cons_qual.unshift(-1)

      # mirror everything that's done to aligned_cons_seq in all previously aligned_seqs:
      for k in 0...adjusted_prev_aligned_reads.size do
        adjusted_prev_aligned_reads[k] = '-' + adjusted_prev_aligned_reads[k]
        adjusted_prev_aligned_qualities[k].unshift(-1)
      end

      i -= 1
    end

    while j > 0
      aligned_read_seq = '-' + aligned_read_seq
      aligned_read_qual.unshift(-1)
      aligned_cons_seq = growing_consensus[j-1].chr + aligned_cons_seq
      aligned_cons_qual.unshift(growing_consensus_qualities[j-1])

      # mirror everything that's done to aligned_cons_seq in all previously aligned_seqs:
      for k in 0...adjusted_prev_aligned_reads.size do
        adjusted_prev_aligned_reads[k] = previously_aligned_reads[k][j-1].chr + adjusted_prev_aligned_reads[k]
        adjusted_prev_aligned_qualities[k].unshift(previously_aligned_qualities[k][j-1])
      end

      j -= 1
    end

    msg=''
    msg_type=1

    aligned_seqs= {:growing_cons_seq => aligned_cons_seq,
                   :growing_consensus_qualities => aligned_cons_qual,

                   :read_seq => aligned_read_seq,
                   :read_qal => aligned_read_qual,

                   :adjusted_prev_aligned_reads => adjusted_prev_aligned_reads,
                   :adjusted_prev_aligned_qualities => adjusted_prev_aligned_qualities,

                   :message => msg,
                   :message_type => msg_type
    }

    # puts "growing_cons_seq:"
    # puts aligned_seqs[:growing_cons_seq]
    # puts "read_seq:"
    # puts aligned_seqs[:read_seq]

    # check if overlap worked or crappy alignment resulted:

    diffs=0
    valids=0

    conflicting_positions= Array.new

    (0...aligned_seqs[:growing_cons_seq].length).each { |m|

      if aligned_seqs[:growing_cons_seq][m]=='-' or aligned_seqs[:read_seq][m]=='-'
        next
      else
        valids+=1
      end

      if aligned_seqs[:growing_cons_seq][m] != aligned_seqs[:read_seq][m]
        diffs+=1
        conflicting_positions << m
      end
    }

    perc = (diffs.to_f/valids)
    if perc <= 0.05

      # wenn zu wenig overlap:
      if valids < 15
        #return nil
        nil
      else
        #return alignment:
        aligned_seqs[:message]=perc
        aligned_seqs
      end

    else
      #return nil
      nil

    end
  end


  def not_assembled
    self.primer_reads.not_assembled.as_json
  end


  def compute_consensus(seq1, qual1, seq2, qual2)
    consensus_seq=''
    consensus_qal=[]

    for i in 0...seq1.length

      unless qual1[i]==-1 or qual2[i]==-1

        if qual1[i] > qual2[i]
          consensus_qal.push(qual1[i])
          consensus_seq += seq1[i]
        else
          consensus_qal.push(qual2[i])
          consensus_seq += seq2[i]
        end

      else

        if qual1[i]==-1 and qual2[i]==-1
          consensus_qal.push(-1)
          consensus_seq += '-'
        else
          if qual1[i]==-1

            #if further gap adjacent, it's most likely end of trimmed_seq --> qual2/seq2 win
            trimmed_end = false
            if i>0
              if qual1[i-1] == -1 or qual1[i+1] == -1
                trimmed_end=true
              end
            else
              if qual1[i+1] == -1
                trimmed_end=true
              end
            end

            if trimmed_end

              consensus_seq += seq2[i]
              consensus_qal.push(qual2[i])

            else

              #get surrounding base qualities
              
              if i>0
                neighboring_qual1=qual1[i-1]
              else
                neighboring_qual1=qual1[i+1]
              end

              if neighboring_qual1 > qual2[i]
                consensus_seq += '-'
                consensus_qal.push(neighboring_qual1)
              else
                consensus_seq += seq2[i]
                consensus_qal.push(qual2[i])
              end
            end

          elsif qual2[i]==-1

            #if further gap adjacent, it's most likely end of trimmed_seq --> qual1/seq1 win
            trimmed_end = false
            if i>0
              if qual2[i-1] == -1 or qual2[i+1] == -1
                trimmed_end=true
              end
            else
              if qual2[i+1] == -1
                trimmed_end=true
              end
            end

            if trimmed_end

              consensus_seq += seq1[i]
              consensus_qal.push(qual1[i])

            else

              #get surrounding base qualities
              if i>0
                neighboring_qual2 = qual2[i-1]
              else
                neighboring_qual2 = qual2[i+1]
              end

              if neighboring_qual2 > qual1[i]
                consensus_seq += '-'
                consensus_qal.push(neighboring_qual2)
              else
                consensus_seq += seq1[i]
                consensus_qal.push(qual1[i])
              end

            end
          end

        end

      end


    end

    [consensus_seq, consensus_qal]


  end

end



