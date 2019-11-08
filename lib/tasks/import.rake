require 'uri/http'

item_types_lookup = {
	"apps" => :app, 
	"articles" => :article, 
	"audio" => :audio, 
	"blogs" => :blog, 
	"books" => :book, 
	"certifications_amp_assessment" => :cert, 
	"cheatsheets" => :cheatsheet, 
	"code" => :code, 
	"conferences" => :conference, 
	"courses" => :course, 
	"flashcards" => :flashcard, 
	"forums" => :chat, 
	"games" => :game, 
	"images" => :image, 
	"interactives" => :interactive, 
	"journals" => :journal, 
	"learning_plans" => :learning_plan, 
	"livestreams" => :livestream, 
	"meetups" => :meetup, 
	"newsletters" => :newsletter, 
	"people" => :people, 
	"q_amp_a" => :qna, 
	"quotes" => nil, 
	"research_papers" => :research_paper, 
	"wiki" => :wiki, 
	"q_amp" => :qna, 
	"apps_amp_websites" => :website, 
	"apps_and_website" => :website, 
	"certifications_assessment" => :cert, 
	"q_a" => :qna, 
	"videos" => :video, 
	"apps_websites" => :website, 
	"documentaries" => :video, 
	"documenteries" => :video, 
	"q" => :qna, 
	"images_animations" => :image, 
	"meetups_and_events" => :meetup, 
	"related" => nil, 
	"programming_interviews" => nil, 
	"apps_and_websites" => :website
}

namespace :import do
  desc "Imports data from a JSON file generated by scraping the Githb repo"
  task :import, [:file_name] => :environment do |task, args|

	# creating a dummy user because Item needs some user
	user = User.find_or_create_by!(nickname: 'learnawesome', auth0_uid: 'learnawesome', authinfo: '{"info": {"image": "https://learnawesome.org/stream/assets/img/logo-mobile.png"}}')

	data = JSON.parse(File.read(args[:file_name]))
	data.each do |topic_name, topic_hash|
		topic_name = topic_name.sub('learn-awesome/', '').sub('.html', '')
		topic_name_array = topic_name.split('/')

		ns = topic_name_array.first(topic_name_array.count - 1).join('/')

		topic = Topic.where(
			name: topic_name_array.last.sub('-language', '').sub('india-', '')
		).first

		if topic.nil?
			puts "skipping topic = #{topic_name_array.inspect} #{ns}"
			next
		end

		topic_hash.each do |item_type_name, item_type_hash|
			# strings have diverged. Use the lookup table
			item_type_id = item_types_lookup[item_type_name.split(',').first.parameterize.underscore]
			if item_type_id.nil?
				puts "skipping item_type = #{item_type_name}"
				next
			end

			item_type = ItemType.find(item_type_id)

			next unless item_type_hash['links']

			item_type_hash['links'].each do |item_hash|
				next if item_hash['sourceText'].length < 3

				if item_hash['link'] =~ URI::regexp(%w[http https])
					begin
						idea_set = IdeaSet.create!(name: item_hash['sourceText'].sub('📕 ', '').sub('📖 ', ''))
						item = Item.create!(
							name: item_hash['sourceText'].sub('📕 ', '').sub('📖 ', ''),
							idea_set: idea_set,
							item_type: item_type,
							allow_without_links: true,
							user: user)

						TopicIdeaSet.find_or_create_by!(topic: topic, idea_set: idea_set)
						Link.find_or_create_by!(item: item, url: item_hash['link']) if item_hash['link'].length >= 8
						puts "created Item #{item.name}"
					rescue Exception => ex
						puts ex.message
					end
				else
					puts "invalid: #{item_hash['link']}"
				end
			end
		end
	end
  end
end
