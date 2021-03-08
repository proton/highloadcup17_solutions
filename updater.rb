require 'mechanize'

README_FILE = './README.md'
NO_TIME = Float::INFINITY

repos = {}
agent = Mechanize.new

file_content = File.open(README_FILE).read
file_table_content = file_content.match(/\|.*\|/m)[0]
file_table_lines = file_table_content.split("\n")
file_table_header = file_table_lines[0..1]
file_table_lines[2..-1].each do |line|
  _, positions, url, lang, time, name, _ = line.split('|').map(&:strip)
  positions = positions.split(',').map(&:to_i)
  name = url if name.empty?
  time = time.to_f
  time = Float::INFINITY if time.zero?
  repos[name] = { positions: positions, url: url, lang: lang, time: time.to_f, name: name }
end

urls = %w(https://highloadcup.ru/rating/round/1/ https://highloadcup.ru/rating/round/2/)
urls.each_with_index do |url, i|
	page  = agent.get(url)
	tr_tags = page.search('.rating.table-responsive.bg-blue-light2 > table > tbody > tr, .rating > table.bg-blue-light2 > tbody > tr')
	tr_tags.each do |tr|
		cells = tr.search('td').map(&:inner_text)
		name = cells[3].split("\n").first
		repo = repos[name]
		next unless repo
		repo[:positions][i] = cells[0].to_i
		time = cells.last.to_f
		repo[:time] = [time, repo[:time]].reject(&:zero?).min
	end
end

fields = %i(position url lang time name)
new_table_rating = repos.values.sort_by { |repo| repo[:time] }.map do |repo|
  repo[:name] = nil if repo[:name].start_with? 'http'
  repo[:time] = nil if repo[:time].infinite?
  time = repo[:time].to_f
  repo[:time] = time.round(2) if time.to_i.to_s.size > 4
  repo[:position] = repo[:positions].join(', ')
  ([nil] + fields.map { |f| repo[f] } + [nil]).join(' | ').strip
end
new_file_table_content = (file_table_header+new_table_rating).join("\n")

file_content.gsub!(file_table_content, new_file_table_content)
File.open(README_FILE, 'w') { |f| f.write file_content }
