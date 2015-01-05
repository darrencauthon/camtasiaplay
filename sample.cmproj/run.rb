require 'nokogiri'

class GapFiller

  def initialize file
    @file = file
  end

  def xml
    File.open('project.xml').read
  end

  def next_id
    @next_id ||= 0
    @next_id += 1
    the_last_id_in_the_xml + @next_id
  end

  def the_last_id_in_the_xml
    @the_last_id_in_the_xml ||= xml.scan(/id="(\d+)"/i).map { |x| x[0].to_i }.max
  end

  def find_items_in track
    items = track.xpath('./Medias/ScreenVMFile').map do |item|
              { 
                id:       item['id'],
                start:    item['start'].to_i,
                duration: item['duration'].to_i,
                end:      item['start'].to_i + item['duration'].to_i,
              }
            end

    items.each { |i| i[:next_item_start] = i[:start] + i[:duration] }

    items
  end

  def raw_doc
    Nokogiri::XML xml
  end

  def find_track track_id
    tracks = raw_doc.xpath("//GenericTrack")
    tracks.select { |t| t['id'] == track_id }.first
  end

  def find_the_gaps_in track
    items = find_items_in track

    items.each_with_index.select do |item, index|
      result = false
      if index > 0 && index < items.count
        last_item = items[index - 1]
        result = item[:start] != last_item[:next_item_start]
      end
      result
    end.map do |item, index|
      last_item = items[index - 1]
      {
        index:      index - 1,
        start:      last_item[:next_item_start],
        id:         last_item[:id],
        duration:   last_item[:duration],
        gap_length: item[:start] - last_item[:next_item_start],
      }
    end
  end

  def find_the_copies_to_make_in track

    gaps = find_the_gaps_in track

    copies_to_make = gaps.map do |gap|
                       total_indexes = gap[:gap_length]/gap[:duration]
                       (0..total_indexes).to_a.map do |index|
                         gap = gap.clone
                         if index > 0
                           gap[:start] += gap[:duration]
                         end
                         gap[:id_to_copy] = gap[:id]

                         original_duration = gap[:duration]
                         gap[:duration] = gap[:gap_length] - (gap[:duration] * (index))
                         gap[:duration] = original_duration if gap[:duration] > original_duration

                         if index == 0 || index == total_indexes
                           if gap[:gap_length] < gap[:duration]
                             gap[:duration] = gap[:gap_length]
                           end
                         end
                         gap
                       end
                     end
    copies_to_make = copies_to_make.flatten#.select { |x| x[:duration] > 0 }

    copies_to_make.each do |copy|
      #copy.delete :gap_length
      copy.delete :id
    end

    copies_to_make

  end

end

gap_filler = GapFiller.new 'project.xml'
track = gap_filler.find_track '10'

copies_to_make = gap_filler.find_the_copies_to_make_in(track)

doc = gap_filler.raw_doc


copies_to_make.each do |copy_to_make|
  parent = doc.xpath("//ScreenVMFile[@id=#{copy_to_make[:id_to_copy]}]").first
  xml = parent.to_xml
  xml.sub!(/start="(\d+)"/i, "start=\"#{copy_to_make[:start]}\"")
  xml.sub!(/duration="(\d+)"/i, "duration=\"#{copy_to_make[:duration]}\"")
  xml.sub!(/mediaDuration="(\d+)/i, "mediaDuration=\"#{copy_to_make[:duration]}")
  xml.scan(/id="(\d+)"/i).map { |x| x[0].to_i }.each do |id|
    xml.gsub!("id=\"#{id}\"", "id=\"#{gap_filler.next_id}\"")
  end
  #node = Nokogiri::XML::Node.new xml, doc
  #parent.add_next_sibling node
  #
  #h3.content = "1977 - 1984"
  #h1.add_next_sibling(h3)

  current = File.open('project.xml').read
  search_string = "<ScreenVMFile id=\"#{copy_to_make[:id_to_copy]}\""
  index = current.index(search_string) + search_string.length
  next_section = current[index..current.length].index('</ScreenVMFile>') + '</ScreenVMFile>'.length
  current.insert(next_section, xml)
  File.open('project.xml', 'w') { |f| f.write xml }
end

#puts new_xml

#new_xml = doc.to_xml
#File.open('project.xml', 'w').write new_xml



#module_to_replace = gap_filler.raw_doc.xpath('//ScreenVMFile[@id=119]').first.to_xml.inspect

 
#puts gap_filler.raw_doc.xpath('..').count.inspect
