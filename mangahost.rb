# encoding: utf-8

require 'fileutils'
require 'mechanize'

MAIN_PREFIX = 'http://centraldemangas.net.br'
MAIN_URL = 'http://centraldemangas.net.br/titulos/filtro/*/p/'
OUTDIR = 'data/'
PAGE = ARGV[0].to_i

agent = Mechanize.new
agent.user_agent_alias = 'Linux Firefox'
cookieagent = Mechanize.new
titulos_filter_pages = Array.new

titulo_page_index = PAGE

while titulo_page_index <= PAGE do
	titulo_current_page = agent.get("#{MAIN_URL}#{titulo_page_index}")
	puts "[INFO] Page ##{titulo_page_index} reached!"

	Nokogiri::HTML(titulo_current_page.body).xpath('//*[@id="main"]/div[2]/div/div[1]/div/div[3]/div/div/div/a').each do |item_from_titulos_page|
		name = item_from_titulos_page.children[0].to_s
		link = item_from_titulos_page.attributes['href'].value.to_s
		titulos_filter_pages.push [name, link]

		puts "[INFO] [P#{titulo_page_index}] Title '#{name}' accquired!"
	end

	titulo_page_index += 1
end

puts "\n[INFO] STARTING TO DO THE REAL JOB!\n"
titulo_page_index = 1

titulo_filter_page_index = 0
titulos_filter_pages.each do |a|
	name, link = a
	titulo_url = MAIN_PREFIX + link
	titulo_index = agent.get(titulo_url)
	puts "\n[INFO] Title #{name} reached!"

	chapters_from_titulo = Array.new
	
	Nokogiri::HTML(titulo_index.body).xpath('//*[@id="main"]/div[2]/div/div[1]/div/div[4]/div[9]/div/div[2]/div/div[2]/table/tbody/tr/td[1]/a').each do |chapter_from_titulo|
		chapter_name = chapter_from_titulo.children[0].to_s.delete(" \n")
		chapter_link = chapter_from_titulo.attributes['href'].value.to_s
		chapters_from_titulo.push [chapter_name, chapter_link]
	end

	puts "[INFO] Chapters founded for #{name}: #{chapters_from_titulo.size}"

	titulo_filter_page_index += 1

	chapter_index = 0
	chapters_from_titulo.each do |chapter|
		chapter_index += 1
		chapter_name, chapter_link = chapter
		chapter_outdir = OUTDIR + name.gsub(/[\x00\/\\:\*\?\"<>\|]/, '_').rstrip + '/' + chapter_name

		chapter_url = MAIN_PREFIX + chapter_link
		chapter_page = agent.get(chapter_url)

		images_list = Array.new

		Nokogiri::HTML(chapter_page.body).xpath('/html/body/script[9]').each do |script|
			list = script.to_s.split("\n")

			suffix = nil
			prefix = nil

			list.each do |it|
				prefix = it if it.include?('var urlSulfix = ')
				suffix = it if it.include?('var pages = ')
			end

			#prefix = list[4]
			#suffix = list[5]

			if prefix == nil || suffix == nil
				puts "[ERROR] INVALID JAVASCRIPT TRANSLATION FOR #{name}"
			end

			prefix.gsub!("var urlSulfix = '", '')
			prefix.gsub!("';", '')
			prefix.delete!(' ')
			
			suffix.gsub!('var pages = ', '')
			suffix.gsub!(',];', '')
			suffix.gsub!(';]', '')
			suffix.delete!(' ')
			suffix = suffix + ']'

			begin
				allsuffs = eval(suffix)
			rescue Exception => e 
				puts "[ERROR] INVALID JAVASCRIPT TRANSLATION FOR #{name}"
				next
			end
			
			allsuffs_index = 0
			allsuffs.each do |suf|
				allsuffs_index += 1
				img_url = prefix + suf + '.jpg'
				FileUtils::mkdir_p(chapter_outdir)
				img_dst = chapter_outdir + '/' + suf + '.jpg'

				if File.exists?(img_dst)
					print "\r[SKIP] Filter ##{PAGE} | Manga #{titulo_filter_page_index}/#{titulos_filter_pages.size} | Volume #{chapter_index}/#{chapters_from_titulo.size} | File #{allsuffs_index}/#{allsuffs.size}       "
					next
				end

				print "\r[GET] Filter ##{PAGE} | Manga #{titulo_filter_page_index}/#{titulos_filter_pages.size} | Volume #{chapter_index}/#{chapters_from_titulo.size} | File #{allsuffs_index}/#{allsuffs.size}            "

				begin
					agent.get(img_url, [], chapter_page).save!(img_dst)
				rescue Mechanize::ResponseCodeError, Net::HTTPNotFound
					#print "\r[404] #{img_url}                    "
					next
				end
			end
		end
	end

	
end

puts "\n ======= EOF ======= "
s = STDIN.gets.chomp
