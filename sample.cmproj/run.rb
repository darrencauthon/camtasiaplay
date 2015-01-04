require 'nokogiri'

class GapFiller

  def initialize file
    @file = file
  end

  def xml
    File.open('project.xml').read
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

  def find_track track_id
    doc = Nokogiri::XML xml
    tracks = doc.xpath("//GenericTrack")
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

  def find_the_copies_in track_id

    track = find_track track_id

    gaps = find_the_gaps_in track

    copies_to_make = gaps.map do |gap|
                       (0..(gap[:gap_length]/gap[:duration])).to_a.map do |index|
                         gap = gap.clone
                         gap[:start] += (index * gap[:duration])
                         gap[:id_to_copy] = gap[:id]
                         if index == 0
                           if gap[:gap_length] < gap[:duration]
                             gap[:duration] = gap[:gap_length]
                           end
                         else
                           gap[:duration] = gap[:gap_length] - (gap[:duration] * index)
                         end
                         gap
                       end
                     end.flatten
    copies_to_make = copies_to_make.select { |x| x[:duration] > 0 }

    copies_to_make.each do |copy|
      copy.delete :gap_length
      copy.delete :id
    end

    copies_to_make

  end

end

puts GapFiller.new('project.xml').find_the_copies_in('10')
